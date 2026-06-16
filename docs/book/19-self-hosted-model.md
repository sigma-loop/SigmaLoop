# Chapter 19 — Self-Hosting the Fine-Tuned Model

The `AIClient` seam (Chapter 11) means SigmaLoop is not married to a SaaS model provider.
This chapter covers the option documented in `Hosting SigmaLoop/own-model-aws-deployment.md`:
running a **fine-tuned Qwen model on a single EC2 GPU instance with vLLM**, exposing an
OpenAI-compatible API that the backend consumes as just another provider — with the
external provider as automatic fallback.

## 19.1 The model touchpoints, counted

It's easy to lose track of how many models are in play, so let's enumerate them:

| Touchpoint | What | Where | Role |
|------------|------|-------|------|
| **DeepSeek** | `deepseek-chat` + `deepseek-reasoner` | SaaS | primary provider (default) |
| **Gemini** | `gemini-2.5-flash` | SaaS | automatic fallback |
| **Own model** | fine-tuned Qwen2.5-Coder on vLLM | self-hosted EC2 GPU | optional primary (`AI_PROVIDER=own`) |
| **Qwen hint** | fine-tuned Qwen "Codeforces Tutor" | Flask/vLLM (an ngrok tunnel in dev) | the single-lesson hint model (Chapter 13) |

This chapter is about the third — a *general* self-hosted provider you can point the whole
system at — which is distinct from the fourth, the specialized lesson-hint endpoint.

## 19.2 What gets deployed

`David0dods/Qwen2.5-Coder-3B-Codeforces` is a **LoRA adapter** on the base
`Qwen/Qwen2.5-Coder-3B`. It is served by **vLLM** on a single GPU EC2 instance, exposing an
**OpenAI-compatible** endpoint that the backend's `OwnModelAIClient` calls exactly like
DeepSeek.

> 🎨 **FIGURE 19.1 — Self-hosted model serving**
> *Diagram — generate with Claude image generation.* **Prompt:**
> "A serving diagram on dark navy. Left: the Express API box containing 'OwnModelAIClient'.
> An arrow labelled 'HTTPS, private IP, OpenAI-compatible :8000/v1/chat/completions' to a
> box 'EC2 g4dn.xlarge (NVIDIA T4 16GB)' containing a Docker container 'vllm/vllm-openai'
> with two stacked layers: 'Base: Qwen2.5-Coder-3B (fp16)' and 'LoRA adapter:
> sigmaloop-coder'. A dashed arrow from OwnModelAIClient down to a cloud 'Gemini
> (automatic fallback, 60s cooldown)'. Annotate: '~$0.53/hr on-demand; stop when idle; EBS
> model cache persists ~$8/mo'. Indigo API, orange GPU box, blue fallback cloud. Hairline."

## 19.3 The runbook (condensed)

1. **Set a billing budget alarm** before launching any GPU.
2. **Request the GPU quota** (one-time, blocks everything else): Service Quotas → EC2 →
   "Running On-Demand G and VT instances" → 4 vCPUs. Approval can take hours to ~2 days.
3. **Launch** an EC2 instance: the "Deep Learning OSS NVIDIA Driver AMI (Ubuntu 22.04)",
   **g4dn.xlarge** (one NVIDIA T4, 16 GB), 100 GiB gp3, a security group opening **22**
   (admin IP) and **8000** (admin + backend IP only), and an Elastic IP.
4. **Start vLLM** (the load-bearing command):
   ```bash
   docker run --gpus all -p 8000:8000 -v /opt/hf-cache:/root/.cache/huggingface \
     -e HUGGING_FACE_HUB_TOKEN=... vllm/vllm-openai \
     --model Qwen/Qwen2.5-Coder-3B \
     --enable-lora --lora-modules sigmaloop-coder=David0dods/Qwen2.5-Coder-3B-Codeforces \
     --max-lora-rank 16 --dtype float16 --max-model-len 16384 --api-key <SECRET>
   ```
   `--dtype float16` is **required on the T4** (no bfloat16 support). Selecting the model
   `sigmaloop-coder` uses the LoRA; the bare base name uses the untuned base.
5. **Smoke test** with a `curl` Bearer request.
6. **Wire the backend** (`Backend/.env`): `AI_PROVIDER=own`,
   `OWN_MODEL_BASE_URL=http://<private-ip>:8000/v1`, `OWN_MODEL_API_KEY`,
   `OWN_MODEL_NAME=sigmaloop-coder`, `OWN_MODEL_MAX_TOKENS=5000`. On boot you should see
   `[AIClient] Provider: own model (sigmaloop-coder) with Gemini fallback`.

## 19.4 Cost and operations

A g4dn.xlarge is **~$0.53/hour** on-demand — so the dominant operational discipline is
*stop the instance when idle* (the EBS volume with the cached model persists for ~$8/month,
so restarts are fast). Failures — the instance stopped, an out-of-memory, or bad JSON after
the client's three retries — fall back to the external provider with the usual 60-second
primary cooldown (Chapter 11), so a self-hosted model going down degrades to SaaS rather
than to an outage.

> 💡 **Design Note — same interface, new economics.** Because `OwnModelAIClient` implements
> the same `AIClient` interface, switching the entire platform to a self-hosted model is a
> single `.env` change — no code edits. What changes is the *economics*: SaaS is
> pay-per-token with zero idle cost; a self-hosted GPU is pay-per-hour with zero
> per-token cost. The self-hosted path wins when utilization is high and steady (a busy
> classroom all day), and loses when it's spiky (a few requests an hour), which is exactly
> why "stop when idle" and the SaaS fallback matter.

## 19.5 Production placement and known limits

> 💡 **Design Note — keep the GPU private.** In production the instance belongs in the
> **same VPC as the API**, addressed by its **private IP**; port 8000 should never be
> public (front it with Nginx + TLS if external access is ever needed). The model is a
> trusted internal dependency, not an internet-facing service.

The fine-tune has honest limits, which is why it's a *provider option* and not the only
model: it's a Codeforces-tuned, non-instruct base — strong at competitive-programming-style
code, but weaker at long-form lesson prose and at mathematics. The difficulty-aware routing
(Chapter 11) and the SaaS fallback cover those gaps, sending the work this model is good at
to this model and the rest elsewhere.

Three alternatives were considered and rejected, each for a concrete reason:

- **Hugging Face serverless inference** — doesn't host custom fine-tunes; the old
  api-inference endpoint is gone.
- **SageMaker endpoints** — not OpenAI-compatible, so they'd break the `AIClient` contract.
- **Bedrock custom model import** — requires merged full weights, not a LoRA adapter.

## 19.6 Where self-hosting fits the bigger picture

Self-hosting is the far end of the provider spectrum the `AIClient` abstraction was built
to span: from a frontier SaaS model (DeepSeek/Gemini) for the hardest authoring, to a
cheap base model for routine generation and grading, to a fine-tuned specialist running on
your own GPU for the work it was trained on. The same seam that makes the DeepSeek↔Gemini
fallback transparent (Chapter 11) makes this possible — and it's the conceptual bridge to
Part VI, where we stop thinking of "the model" as one thing and start designing the
generation pipeline as a *team* of specialized models, each doing the one job it's best at.
