# Chapter 12 — The AI Generation Pipeline ★

> *This is one of the book's focus chapters. It is the engine that turns a one-sentence
> goal into a full personalized course.*

Every course, lesson, and challenge in SigmaLoop is produced here. The pipeline's
defining quality is that it is **lazy and self-healing**: a request for a twelve-lesson
course costs only a couple of model calls up front, the rest of the work is deferred to
the moment a learner actually opens a lesson, and every step can fail and recover
without corrupting the database.

## 12.1 The mental model in one paragraph

A learner triggers generation (onboarding, `/curriculum/request`, the mentor's
`create_course` tool, or a course's generate-more / generate-challenges endpoint). Each
path does the **same minimal thing**: write a `CurriculumJob` with `status: PENDING` and
return immediately (HTTP 202). An in-process polling worker (`curriculumWorker.ts`)
atomically claims the oldest pending job. Generation is deliberately lazy: the worker
generates only a *course outline*, writes every lesson as a cheap **STUB** (title +
summary + challenge specs, no body, no challenges), fully materializes just the **first**
lesson, and flips the job to `READY`. The remaining lessons are materialized on first
open. Every model call goes through `aiClient` (Chapter 11).

> 🎨 **FIGURE 12.1 — The lazy generation pipeline**
> *Diagram — generate with Claude image generation.* **Prompt:**
> "A detailed pipeline diagram on dark navy. Left: four trigger sources stacked
> (Onboarding wizard, POST /curriculum/request, Mentor tool create_course, Course
> generate-more) all pointing to a single green cylinder 'CurriculumJob (status:
> PENDING)'. Middle: a box 'Curriculum Worker (polls every 5s)' with an atomic-claim
> badge 'findOneAndUpdate PENDING→GENERATING'. From it, a vertical pipeline for
> NEW_COURSE: '1. generateCourseOutline (≥12 lessons)' → '2. Course.create
> (GENERATING)' → '3. write ALL lessons as STUBs (insertMany)' → '4. materialize ONLY
> lesson 1' → '5. status READY'. Show stubs as faded grey lesson cards and the first
> lesson as a solid indigo card. Right: a separate later flow 'Learner opens lesson N →
> POST /lessons/N/generate → materializeLesson: body + challenges generated
> concurrently → status READY'. Use a clock icon on async parts and a small AI-chip icon
> on each model call. Hairline arrows, labels on each step."

## 12.2 The job contract

Generation is mediated entirely by the `CurriculumJob` document (Chapter 4). Three things
about it matter here:

- `type` ∈ `{ NEW_COURSE, EXTEND_COURSE, GENERATE_CHALLENGES }` — the three jobs below.
- `prompt` (always) and `goals` (for questionnaire-driven jobs) — the *what to build*.
- `status` (`PENDING → GENERATING → READY/FAILED`) and `courseId` — the *progress*.

The index `{ status: 1, createdAt: 1 }` exists specifically so the worker can cheaply
find the oldest pending job.

## 12.3 The four entry points

All four create a job and return **HTTP 202** immediately — none waits for generation.

| Trigger | Code | Job type |
|---------|------|----------|
| `POST /curriculum/request` (free-text *or* questionnaire `goals`) | `curriculum.controller.ts → requestGeneration` | `NEW_COURSE` |
| `POST /courses/:id/generate-more` | `requestExtension` | `EXTEND_COURSE` |
| `POST /courses/:id/generate-challenges` | `requestChallenges` | `GENERATE_CHALLENGES` |
| Mentor tools `create_course` / `generate_more_lessons` | `mentorTools.ts` | `NEW_COURSE` / `EXTEND_COURSE` |

`requestGeneration` accepts either a `prompt` or a `goals` object; if only `goals`, it
compiles a human-readable prompt *and* stores the structured goals on the job (the
generator uses both). It validates the difficulty and returns `503 AI_NOT_CONFIGURED` if
no provider is set. The extend/challenge endpoints additionally enforce **ownership**
(404) and that the course is `READY` (`409 CONFLICT` otherwise).

## 12.4 The worker loop

The worker starts in `server.ts` after Mongo connects and settings load. It polls every
5 seconds, and the heart of it is an **atomic claim**:

```ts
async function tick() {
  if (processing) return
  processing = true
  try {
    // Atomically claim the oldest pending job so a second worker (or a restart)
    // never picks up the same job twice.
    const job = await CurriculumJob.findOneAndUpdate(
      { status: 'PENDING' },
      { status: 'GENERATING' },
      { sort: { createdAt: 1 }, new: true }
    )
    if (job) await processJob(job)   // → processNewCourseJob / processExtendJob / processChallengeSetJob
  } catch (err) { console.error('[CurriculumWorker] Tick error:', err) }
  finally { processing = false }
}
```

> 💡 **Design Note — `findOneAndUpdate` *is* the lock.** Claiming and marking-in-progress
> are a single atomic operation, conditioned on `status: PENDING`. Two workers (or a
> worker plus a restarted one) can never grab the same job: the first flips it to
> `GENERATING`, the second's query no longer matches it. This is the simplest possible
> distributed-queue primitive, and it's enough because the work item is idempotent at the
> document level. In production this whole loop is replaced by Step Functions + Lambda
> (Chapter 17), but the *claim-then-process* shape is preserved.

**Orphan recovery.** At startup, `recoverOrphanedJobs` heals anything stuck in
`GENERATING` from a crashed process: extend/challenge jobs are failed but their course is
restored to `READY` (it kept its valid lessons); a `NEW_COURSE` is kept `READY` only if at
least one lesson actually materialized, otherwise the empty shell course and its job are
both marked `FAILED`. The single-process worker also guards re-entrancy with a module-level
`processing` flag.

## 12.5 NEW_COURSE — the headline path

`processNewCourseJob`:

1. `aiClient.generateCourseOutline({ prompt, difficulty, goals })` — asks for **at least
   `config.generation.courseLessonCount`** lessons (default 12; aim 12–16). Throws if the
   outline has no lessons.
2. Validate `outline.language` against `SUPPORTED_LANGUAGES` (invalid → `undefined`,
   i.e. a math/agnostic course).
3. `Course.create({ …, status: GENERATING })`; set `job.courseId`.
4. `createStubLessons(...)` — write **every** outline lesson as a STUB via `insertMany`.
5. Eagerly materialize only the first `config.generation.initialLessonCount` lessons
   (default **1**).
6. `course.status = READY`, `job.status = READY`.

On any error, the job is marked `FAILED` with the message and the course `FAILED`.

**Stub creation** (`createStubLessons`, shared with EXTEND): for normal lessons,
`challengeSpecs` is capped to `config.generation.maxChallengesPerLesson` (default 1); for
`challengeOnly` lessons it keeps the full set. If a stub would have zero challenges, it
injects one MCQ — guaranteeing the lesson is *completable* (progress gating needs at least
one challenge to pass).

## 12.6 `materializeLesson` — the heart of laziness

When a learner opens a stub lesson, `POST /lessons/:id/generate` calls
`materializeLesson`. It is concurrency-safe, idempotent, and self-healing:

```
1. Atomic claim:  findOneAndUpdate({ _id, status: STUB }, { status: GENERATING })
   - not a claimable stub? return the current doc unchanged (handles double-open)
2. Load the course + sibling lesson titles (context for the body prompt)
3. Challenge.deleteMany({ lessonId })           // clear any half-built prior attempt
4. Body:   challengeOnly ? '' : aiClient.generateLesson(courseCtx, lesson)
5. Challenges: Promise.all over challengeSpecs → aiClient.generateChallenge(lesson, spec)
   then persist IN SPEC ORDER (so on-screen order is stable)
6. status = READY, save
   On any failure: Challenge.deleteMany + reset lesson to STUB  // next open retries clean
```

Two design choices stand out:

> 💡 **Design Note — one artefact, one call.** The lesson *body* and each *challenge* are
> generated by **separate** model calls (`generateLesson`, then one `generateChallenge`
> per spec). Each prompt stays focused on a single artefact, which both improves quality
> and means a failure of one challenge doesn't poison the lesson body. The challenges of
> a lesson are generated **concurrently** (`Promise.all`) but **persisted sequentially**
> in spec order, so generation is fast while display order stays deterministic.

> 💡 **Design Note — the stub claim mirrors the job claim.** The same
> `findOneAndUpdate({ status: STUB } → GENERATING)` atomic claim used for jobs is reused
> for lessons. If a learner double-clicks, or two devices open the same lesson at once,
> only the first claim materializes; the second sees a non-stub and returns the current
> document. The lazy pipeline is safe under concurrency *by construction*, not by luck.

**Persisting a challenge** (`saveGeneratedChallenge`) is kind-discriminated and defensive:
MCQ maps options to `{ text, isCorrect, explanation }`; MATH carries the LaTeX fields and
a `mathRunLimit`; PROGRAMMING **filters out malformed test cases** (any without a
non-empty `expectedOutput` string), defaults `input` to `''`, and coerces `isHidden`. The
parsed `kind` is force-pinned to the spec's kind regardless of what the model returned.

## 12.7 EXTEND_COURSE and GENERATE_CHALLENGES

**EXTEND_COURSE** (`processExtendJob`) appends `config.generation.extendLessonCount`
(default 5, or the caller's count) new STUB lessons after the existing ones. It flips the
course to `GENERATING` for UI progress and restores it to `READY` afterward — and,
notably, **never** marks the course `FAILED` on failure, because it still holds all its
existing valid lessons. It passes the existing lesson titles + short excerpts into the
prompt so the model won't duplicate topics. Unlike NEW_COURSE, it materializes **none** of
the new lessons up front; all are lazy.

**GENERATE_CHALLENGES** (`processChallengeSetJob`) appends **one** `challengeOnly`
practice lesson of `config.generation.challengeSetSize` challenges (default 3). The
**anchor kind** is chosen by the course's nature — `course.language ? PROGRAMMING : MATH`
— and `normalizeChallengeSetStub` then *forces* the composition regardless of model
output: exactly one anchor (inheriting course difficulty, so reasoner routing still fires)
plus `count − 1` MCQs. Topics are salvaged from the model's output where present.

> 💡 **Design Note — forcing composition over trusting the model.** The challenge-set
> generator is *told* to produce "one anchor + N MCQs," but the code doesn't trust it to
> comply — `normalizeChallengeSetStub` rebuilds the spec list to exactly that shape. This
> is the generation pipeline's recurring theme: the model proposes; deterministic code
> disposes. It's why practice sets always have a predictable, gradeable structure even
> when the model gets creative.

## 12.8 The prompts

All generators share provider-agnostic builder functions (so DeepSeek and Gemini emit
the same asks). The reusable blocks:

- **`PLATFORM_CONTEXT`** — "Your output is parsed directly into the database; malformed
  output breaks the platform."
- **`MARKDOWN_RULES`** — GFM, KaTeX math, fenced code with a language id, **no h1**, and
  **150–350 words on ONE concept** per lesson.
- **`JSON_STRICTNESS`** — return only a JSON object, escape all strings, no trailing
  commas, double quotes only.
- **`buildProgrammingChallengeRules(language)`** — the language-pinning logic: if the
  course has a language, `starterCodes`/`solutionCodes` must each contain **exactly one**
  key (that language); otherwise a sensible default set. Plus "3–5 test cases, ≥1 hidden,
  end `expectedOutput` with `\n`, plain text only."
- **`MATH_CHALLENGE_RULES`**, **`MCQ_CHALLENGE_RULES`** (the latter: "don't telegraph the
  answer," plausible distractors, honest `allowMultiple` semantics).

The outline prompt embeds the structured `goals` (selected focus areas, the learner's
follow-up answers, free-text notes) so the course is shaped by what the learner actually
said.

> 💡 **Design Note — the language-pinning fix.** An early bug: a "C++ course" would emit
> challenges with only Python/JavaScript starter code, because the model defaulted to
> popular languages. The rule now *pins the schema itself* — when the course has a
> language, the requested JSON shape has exactly that one key — so the model literally
> cannot return the wrong language. Constraining the output shape is more reliable than
> asking nicely in prose.

## 12.9 Reliability: retries, pacing, and distrust

Two retry layers protect generation:

1. **Worker-level `callWithRetry`** — up to 4 attempts with `[5s, 20s, 60s]` backoff.
   It treats `503 / 429 / "high demand" / rate-limit / overloaded / timeout / network`
   **and** `"invalid json" / "validation failed"` as *transient* (a fresh generation
   usually parses), and fails fast on non-transient errors (auth, persistent bad JSON).
   After each success it sleeps `config.generation.pacingMs` (default 6 s) to stay under
   free-tier RPM limits.
2. **Client-level** — DeepSeek's `generateJSON` retries 3× before failing over to Gemini
   (Chapter 11).

Combined with the structural distrust from §12.6–§12.8 (force-pinned kinds, dropped bad
test cases, forced composition, validated language), the pipeline turns a
non-deterministic model into a source of *valid database rows* — or a clean failure, never
a corrupt one.

## 12.10 The onboarding questionnaire feed

The questionnaire is a hybrid, three-call flow that ends in a `NEW_COURSE` job:

1. **Static topic library** — the learner picks from `Frontend/src/constants/topicLibrary.ts`
   (categories → topics with stable ids).
2. **AI follow-ups** — `POST /curriculum/questionnaire/next` calls
   `generateFollowupQuestions` synchronously (one fast call) and returns 3–5 adaptive
   questions tailored to the picks.
3. **Submit** — `POST /curriculum/request { goals }` builds a `NEW_COURSE` job storing
   both the compiled prompt and the structured goals. The worker renders the goals into
   the outline prompt via `formatGoals`.

The frontend `Onboarding` wizard then polls the job with `useCurriculumJob` and navigates
to the course on `READY`.

## 12.11 Why this design

The lazy-stub approach is the central performance and cost decision:

- **Cost & latency:** a 12-lesson course costs ~2–3 model calls up front (outline +
  lesson-1 body + lesson-1 challenge), not dozens. The learner sees a `READY` course in
  seconds, and pays for lesson *N* only if they actually reach it.
- **Resilience:** every step is atomic and self-healing — job claim, stub claim, rollback
  to STUB on failure, orphan recovery on restart, and "never fail the course on an
  extension error."
- **Honesty about the model:** the model's output is validated, pinned, filtered, and
  re-composed at every step, so non-determinism never reaches the database.

Chapter 20 returns to this pipeline with a forward-looking question: what if each of
these steps — outline, lesson, challenge, test-case authoring, verification — were a
*dedicated, specialized agent* rather than one prompt? For now, Chapter 13 covers the
other side of generation: the mentor that *drives* it.
