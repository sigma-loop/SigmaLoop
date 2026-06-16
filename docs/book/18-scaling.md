# Chapter 18 — Scaling Strategy ★

> *A focus chapter. Where the load actually goes, and how each tier grows to meet it.*

A tutoring platform has an unusual load profile: the *API* is light (mostly reads), but
two backends are heavy and bursty in different ways — the **code judge** (CPU-bound,
spiky when a class submits at once) and the **generation pipeline** (latency-tolerant but
expensive per item). This chapter covers how each tier scales, and the deliberate choices
about what *not* to build.

## 18.1 The four things that scale independently

> 🎨 **FIGURE 18.1 — Independent scaling dimensions**
> *Diagram — generate with Claude image generation.* **Prompt:**
> "A diagram on dark navy with four independent scaling 'columns'. Column 1 'API
> (Fargate)': scales on ALBRequestCountPerTarget, small box growing 2→N. Column 2 'Judge0
> (ECS-on-EC2 ASG)': scales on CPU + custom metric PendingSubmissions, boxes growing 2→6
> t3.medium, a sidecar Lambda polling /system_info feeding a CloudWatch metric. Column 3
> 'Generation (Step Functions + Lambda)': scales by Map-state concurrency + Lambda
> concurrency, many small Lambda icons fanning out per lesson. Column 4 'Data
> (DocumentDB)': scales by instance size + read replicas, a green cylinder. Below, a
> banner: 'No app-level queue — classroom load, not contest load'. Brand palette, hairline
> arrows, each column labeled with its scaling signal."

| Tier | Scaling signal | Range |
|------|----------------|-------|
| API (Fargate) | `ALBRequestCountPerTarget` | a few tasks |
| Judge0 (ECS-on-EC2) | CPU (primary) + `PendingSubmissions` (custom) | 2 → 6 t3.medium |
| Generation (Step Functions + Lambda) | Map-state + Lambda concurrency | elastic, per-item |
| DocumentDB | instance size + read replicas | right-sized |

The key property is that these are **decoupled**. A burst of submissions scales Judge0
without touching the API; a wave of new-course requests fans out Lambdas without touching
the judge. Nothing shares a bottleneck.

## 18.2 Scaling the API

The API is the easy one. It is stateless (JWT auth, no server-side sessions), so it scales
horizontally on request rate behind the ALB. The only per-request cost worth noting is the
`User.findById` lookup that `authenticate` performs on every call (Chapter 6) — at very
high scale that becomes a caching candidate, but at classroom scale it's a cheap indexed
read.

## 18.3 Scaling Judge0 — the interesting one

Judge0 is CPU-bound and bursty: a class of thirty submitting at the same moment is a
sudden spike of compile-and-run work. CPU-based autoscaling alone reacts *after* the CPU
is already saturated. So the design adds a **leading indicator**: the depth of Judge0's own
submission queue.

> 💡 **Design Note — autoscale on the queue, not just on CPU.** A sidecar Lambda runs every
> minute, calls Judge0's `/system_info` endpoint, and publishes the pending-submission
> count as a custom CloudWatch metric, `SigmaLoop/judge0/PendingSubmissions`. The Auto
> Scaling Group target-tracks that metric (~8 pending per task) **alongside** a CPU policy.
> The queue grows *before* CPU saturates, so the fleet scales out ahead of the spike
> rather than during it. CPU is the backstop; the queue is the early warning. Baseline is
> 2× t3.medium, ceiling 6, On-Demand (no Spot — see below).

This is the production answer to a problem first seen locally: the Compose stack runs a
fixed `COUNT=4` workers. In the cloud, that worker count becomes elastic, driven by real
demand.

> ⚠️ **Implementation Note — contrast with the Repovive reference.** The `Hosting Judge/`
> reference design (a *contest* judge) scales differently and more aggressively: it has an
> app-level **BullMQ** queue and scales Judge0 on *that* queue's depth (~50/task), adds
> **Spot** instances for surge with **scheduled** scaling 15 minutes before known contest
> rounds, and tolerates Spot interruptions because a killed worker's batch is re-queued.
> SigmaLoop deliberately uses none of that — see §18.5. Don't copy the contest knobs into
> the classroom plan.

## 18.4 Scaling generation

The generation pipeline scales by **fan-out**, not by a bigger worker. In the AWS design
(Chapter 17), Step Functions' **Map state** processes lessons in parallel, each lesson's
body and challenges being separate Lambda invocations. Concurrency is bounded by the Map
state's max-concurrency and Lambda's account concurrency limit, not by a single process.

Locally, the same logical fan-out exists but is gentler: `materializeLesson` generates a
lesson's challenges concurrently (`Promise.all`), and the lazy-stub model means most
lessons are never generated at all unless a learner reaches them. The worker also paces
itself (`config.generation.pacingMs`, default 6 s between calls) specifically to stay under
free-tier provider rate limits — a *throttle*, the opposite of scaling, but the right move
when the bottleneck is the AI provider's RPM, not your own compute.

> 💡 **Design Note — laziness is a scaling strategy.** The cheapest way to scale
> generation is to not generate. The lazy-stub pipeline (Chapter 12) means a class of
> students each requesting a 12-lesson course costs ~2–3 model calls each up front, not
> ~25 — and the long tail of un-opened lessons is never paid for at all. At scale, the
> difference between eager and lazy generation is the difference between an AI bill that
> tracks *enrolled* lessons and one that tracks *completed* ones.

## 18.5 The things deliberately not built

Good scaling design is as much about restraint as mechanism.

> 💡 **Design Note — no app-level queue, on purpose.** SigmaLoop's load is *classroom*,
> not *contest*: steady, per-user, without the synchronized thundering herd of a timed
> round. So there is no BullMQ, no submission batching, no `judge1`-style throttling layer
> in front of Judge0 — the API talks to the judge directly, and Judge0's own internal
> Redis queue plus the autoscaling fleet absorb the modest bursts. This is the single
> biggest divergence from the Repovive reference, and it's a reversible one: the proposal
> notes a thin BullMQ layer can be inserted later if the load profile ever changes. Adding
> a queue you don't need is a real cost — operational surface, latency, another thing to
> scale and monitor — so it's left out until the load justifies it.

Likewise, Spot instances are skipped for the baseline judge fleet (the savings don't
justify the interruption-handling complexity at classroom scale), and the architecture is
single-region in v1 (cross-region pilot-light DR is explicitly future work).

## 18.6 Scaling the data tier

DocumentDB scales vertically (instance size) and horizontally (read replicas for read-heavy
load — and SigmaLoop is read-heavy). The S3 keystone (Chapter 17) helps here too: pushing
test cases and generated content out of the database keeps documents small, so the working
set stays in memory and the database scales on *metadata* volume, not *content* volume.
DocumentDB's ~$180/month floor is the largest cost lever, which is why MongoDB Atlas
(including its serverless tier) is kept as a defined fallback for cost-sensitive or
smaller deployments.

## 18.7 Bounding AI cost as a form of scaling

For an AI-native product, *cost* scales with usage as surely as compute does, and is
managed the same way — with limits and alarms rather than capacity:

- **Per-feature CloudWatch budget alarms** (e.g. an alarm if mentor-chat token spend
  crosses $100/month).
- **The math run limit** (`mathRunLimit`, default 10) caps how many times a learner can
  spend a grading call before a final submission — a per-user rate limit on the one
  per-submission AI cost (Chapter 14).
- **The generation pacing delay** keeps the worker under provider RPM ceilings.
- **The fallback cooldown** (Chapter 11) bounds the latency cost of a provider outage.

> 💡 **Design Note — the AIClient seam is also a cost-scaling lever.** Because every model
> call goes through one interface, the provider can be switched — DeepSeek ↔ Gemini ↔
> Bedrock ↔ a self-hosted model (Chapter 19) — to chase the best cost/quality trade for the
> current load, without touching business logic. Routing hard challenges to the reasoner
> and everything else to the cheap base model (Chapter 11) is the same lever applied per
> request: spend the expensive model only where it changes the outcome.

## 18.8 The shape of growth

Put together: a small, horizontally-scaled API fronting an elastic, queue-aware judge
fleet and a fan-out generation pipeline, over a read-replicated metadata database with the
bulk content in S3 — with AI cost bounded by limits and alarms rather than left to grow.
Each tier scales on its own honest signal (requests, queue depth, items, reads, dollars),
and the one component that *can't* be serverless (the judge) is the one given the most
careful autoscaling. Chapter 19 covers the last operational option: bringing the model
in-house.
