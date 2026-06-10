# Deploying the Own Model (Qwen2.5-Coder-3B-Codeforces) to AWS

> Serves `David0dods/Qwen2.5-Coder-3B-Codeforces` (a LoRA adapter on
> Qwen2.5-Coder-3B) on an EC2 GPU instance with vLLM, exposing an
> OpenAI-compatible API consumed by the backend's `OwnModelAIClient`
> (`Backend/src/services/ai.service.ts`). Gemini remains the automatic
> fallback (`AI_PROVIDER=own` in `Backend/.env`).

## Architecture

```
Backend (Express)  ──HTTP──▶  EC2 g4dn.xlarge (T4 16GB)
  OwnModelAIClient              └─ Docker: vllm/vllm-openai
  (falls back to Gemini)           ├─ base: Qwen/Qwen2.5-Coder-3B (fp16)
                                   └─ LoRA: David0dods/Qwen2.5-Coder-3B-Codeforces
                                   API: POST :8000/v1/chat/completions
```

Cost: ~$0.53/hr on-demand (g4dn.xlarge). Stop the instance when idle —
disk (with the cached model) persists for ~$8/month.

## 1. Account prep
- Set a monthly budget alarm (Billing → Budgets) before launching GPUs.

## 2. GPU quota (one-time, blocks everything else)
Service Quotas → Amazon EC2 → "Running On-Demand G and VT instances" →
request 4 vCPUs. Approval can take hours to 2 days.

## 3. Launch instance
- AMI: Deep Learning OSS Nvidia Driver AMI GPU PyTorch (Ubuntu 22.04)
- Type: g4dn.xlarge · Storage: 100 GiB gp3
- Security group: 22 from admin IP; 8000 from admin IP + backend IP ONLY
- Allocate + associate an Elastic IP

## 4. Start vLLM
```bash
sudo docker run -d --name sigmaloop-llm --restart unless-stopped --gpus all \
  -p 8000:8000 \
  -v /opt/hf-cache:/root/.cache/huggingface \
  -e HUGGING_FACE_HUB_TOKEN=hf_YOUR_TOKEN \
  vllm/vllm-openai:latest \
  --model Qwen/Qwen2.5-Coder-3B \
  --enable-lora \
  --lora-modules sigmaloop-coder=David0dods/Qwen2.5-Coder-3B-Codeforces \
  --max-lora-rank 16 \
  --dtype float16 \
  --max-model-len 16384 \
  --api-key <LONG_RANDOM_SECRET>
```
- `--dtype float16` is required on T4 (no bfloat16).
- If startup rejects the LoRA rank, match `--max-lora-rank` to `r` in the
  adapter's `adapter_config.json`.
- Watch `sudo docker logs -f sigmaloop-llm` until "Uvicorn running".

## 5. Smoke test
```bash
curl http://<ELASTIC_IP>:8000/v1/chat/completions \
  -H "Authorization: Bearer <LONG_RANDOM_SECRET>" \
  -H "Content-Type: application/json" \
  -d '{"model":"sigmaloop-coder","messages":[{"role":"user","content":"Reverse a string in Python."}],"max_tokens":200}'
```
`"model": "sigmaloop-coder"` selects the LoRA; the bare base model name
selects the un-tuned base.

## 6. Wire into the backend
`Backend/.env`:
```
AI_PROVIDER=own
OWN_MODEL_BASE_URL=http://<ELASTIC_IP>:8000/v1
OWN_MODEL_API_KEY=<LONG_RANDOM_SECRET>
OWN_MODEL_NAME=sigmaloop-coder
OWN_MODEL_MAX_TOKENS=5000
```
Restart; expect log `[AIClient] Provider: own model (sigmaloop-coder) with
Gemini fallback`. Failures (instance stopped, OOM, bad JSON after 3
retries) fall back to Gemini with a 60s primary cooldown.

## Troubleshooting
| Symptom | Fix |
|---|---|
| vCPU limit exceeded on launch | quota (step 2) not approved yet |
| CUDA OOM at startup | lower `--max-model-len` to 8192 |
| bfloat16 unsupported error | add `--dtype float16` |
| 401 from API | Bearer value must equal `--api-key` |
| Backend always on Gemini | security group must allow backend IP on 8000 |

## Production notes
- Put the instance in the same VPC as the API server and use the private
  IP; do not expose 8000 publicly. Front with nginx + TLS if external.
- Known quality limits: adapter is Codeforces-tuned on the non-instruct
  base — strong at programming challenges, weaker at long-form lessons and
  math grading. The provider routing + Gemini fallback covers this.
- Rejected alternatives: HF serverless (does not host custom fine-tunes —
  the old api-inference.huggingface.co is dead), SageMaker endpoints (not
  OpenAI-compatible), Bedrock custom import (requires merged full weights,
  not LoRA adapters).
