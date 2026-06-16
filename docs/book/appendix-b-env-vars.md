# Appendix B — Environment Variables & Runtime Settings

This is the complete configuration reference. Most of these are **also** tunable live from
the admin Settings panel (Chapter 7); the "Live?" column says which. **Secrets** are
env-only — never stored in the database, shown in the UI only as *configured / not
configured*. **Read-only** keys need a restart.

## Backend (`Backend/.env`)

### Core

| Variable | Default | Live? | Notes |
|----------|---------|-------|-------|
| `PORT` | `4000` | read-only | API port |
| `NODE_ENV` | `development` | read-only | `development` \| `production` |
| `DATABASE_URL` | `mongodb://localhost:27017/sigmaloop` | **secret** | Mongo connection string |
| `JWT_SECRET` | — | **secret** | throws in prod if unset |
| `JWT_EXPIRES_IN` | `7d` | ✅ (see note) | token lifetime |
| `JUDGE0_DASHBOARD` | `http://localhost:2358` | ✅ | Judge0 base URL |

> ⚠️ `JWT_EXPIRES_IN` is registered as live-tunable, but the auth controller currently
> signs with a hard-coded `'7d'` — so changing it has no effect on new tokens until the
> controller is updated (Chapter 6).

### AI provider selection & secrets

| Variable | Default | Live? | Notes |
|----------|---------|-------|-------|
| `AI_PROVIDER` | `deepseek` | ✅ (rebuilds client) | `deepseek` \| `gemini` |
| `DEEPSEEK_API_KEY` | — | **secret** | primary model key |
| `GEMINI_API_KEY` | — | **secret** | fallback model key |

### DeepSeek (primary)

| Variable | Default | Live? |
|----------|---------|-------|
| `DEEPSEEK_BASE_URL` | OpenAI-compatible base | ✅ |
| `DEEPSEEK_MODEL` | `deepseek-chat` | ✅ (rebuilds client) |
| `DEEPSEEK_TEMPERATURE` | `0.3` | ✅ |
| `DEEPSEEK_MAX_TOKENS` | `8000` | ✅ |
| `DEEPSEEK_CHAT_MAX_TOKENS` | `1024` | ✅ |
| `DEEPSEEK_TIMEOUT_MS` | `120000` | ✅ |

### DeepSeek reasoner (difficulty-aware routing)

| Variable | Default | Live? |
|----------|---------|-------|
| `DEEPSEEK_REASONER_ENABLED` | `true` | ✅ |
| `DEEPSEEK_REASONER_MODEL` | `deepseek-reasoner` | ✅ |
| `DEEPSEEK_REASONER_KINDS` | `PROGRAMMING,MATH` | ✅ |
| `DEEPSEEK_REASONER_MIN_DIFFICULTY` | `INTERMEDIATE` | ✅ |
| `DEEPSEEK_REASONER_MAX_TOKENS` | `8000` | ✅ |
| `DEEPSEEK_REASONER_TIMEOUT_MS` | `300000` | ✅ |

### Gemini (fallback)

| Variable | Default | Live? |
|----------|---------|-------|
| `AI_MODEL` | `gemini-2.5-flash` | ✅ |
| `AI_MAX_TOKENS` | `65536` | ✅ |
| `AI_THINKING_BUDGET` | `8192` | ✅ |
| `AI_THINKING_BUDGET_HARD` | `24576` | ✅ |

### Generation tunables (the curriculum worker)

| Variable | Default | Effect |
|----------|---------|--------|
| `GENERATION_PACING_MS` | `6000` | delay between AI calls (stay under RPM limits) |
| `INITIAL_LESSON_COUNT` | `1` | lessons materialized eagerly on a new course |
| `MAX_CHALLENGES_PER_LESSON` | `1` | cap on challenge specs per normal lesson |
| `COURSE_LESSON_COUNT` | `12` | minimum lessons a new outline aims for |
| `EXTEND_LESSON_COUNT` | `5` | lessons added by generate-more |
| `CHALLENGE_SET_SIZE` | `3` | challenges in a practice (challenge-only) lesson |

### Qwen lesson-hint model

| Variable | Default | Notes |
|----------|---------|-------|
| `QWEN_HINT_ENABLED` | `true` | route lesson chat to the hint model |
| `QWEN_HINT_URL` | (a dev ngrok tunnel) | the `/generate` endpoint |
| `QWEN_HINT_FORMAT` | `chat` | `chat` \| `structured` |
| `QWEN_HINT_FALLBACK` | `true` | fall back to `aiClient` if the hint model fails |
| `QWEN_HINT_TIMEOUT_MS` | `45000` | request timeout |

### Self-hosted "own" model (optional — Chapter 19)

| Variable | Notes |
|----------|-------|
| `OWN_MODEL_BASE_URL` | e.g. `http://<private-ip>:8000/v1` |
| `OWN_MODEL_API_KEY` | vLLM `--api-key` |
| `OWN_MODEL_NAME` | e.g. `sigmaloop-coder` (selects the LoRA) |
| `OWN_MODEL_MAX_TOKENS` | e.g. `5000` |

## Judge0 stack (`Backend/.env.judge0`)

| Variable | Dev value | Notes |
|----------|-----------|-------|
| `POSTGRES_PASSWORD` | `judge0password` | dev only — committed |
| `REDIS_PASSWORD` | `judge0redispassword` | dev only — committed |

## Frontend (`Frontend/.env`)

| Variable | Default | Notes |
|----------|---------|-------|
| `VITE_API_BASE_URL` | `http://localhost:4000/api/v1` | read by `API_BASE_URL`… |

> ⚠️ …but the live Axios client in `services/api.ts` **hard-codes** the URL and ignores
> this variable. A production build must change that line (Chapter 8).

## Settings groups (admin panel)

The registry organizes live keys into: **AI Provider · DeepSeek · DeepSeek Reasoner ·
Gemini · Qwen Hint · Generation · Judge0 · Auth · Secrets · Infrastructure.** Saving a key
in the *AI Provider* / base-model groups (`reresolveAI`) rebuilds the AI client live; the
*Secrets* group is read-as-`configured`-only; the *Infrastructure* group (`PORT`,
`NODE_ENV`) is read-only.
