# Chapter 7 — Configuration & Runtime Settings

SigmaLoop has two layers of configuration: a static `config` object built from
environment variables at boot, and a **runtime overlay** that lets an admin retune most
of that config *live, from the UI, without a redeploy*. This chapter explains both, and
the clever-but-simple mechanism that makes the live retuning work.

## 7.1 The `config` singleton

`config/index.ts` calls `dotenv.config()` and then assembles one exported object. Its
shape (abridged, with defaults):

```ts
export const config = {
  port,                                  // PORT || 4000
  nodeEnv,                               // NODE_ENV || 'development'
  database: { url },                     // DATABASE_URL
  jwt: { secret, expiresIn },            // JWT_SECRET (throws in prod if unset), '7d'
  judge0: { dashboard },                 // JUDGE0_DASHBOARD || http://localhost:2358
  generation: {                          // the curriculum-worker tunables
    pacingMs: 6000, initialLessonCount: 1, maxChallengesPerLesson: 1,
    courseLessonCount: 12, extendLessonCount: 5, challengeSetSize: 3
  },
  ai: {
    provider,                            // 'deepseek' (default) | 'gemini'
    geminiApiKey, model: 'gemini-2.5-flash',
    maxTokens: 65536, thinkingBudget: 8192, thinkingBudgetHard: 24576,
    deepseek: {
      baseUrl, apiKey, model: 'deepseek-chat', temperature: 0.3,
      maxTokens: 8000, chatMaxTokens: 1024, timeoutMs: 120000,
      reasonerModel: 'deepseek-reasoner', reasonerEnabled: true,
      reasonerKinds: ['PROGRAMMING','MATH'], reasonerMinDifficulty: 'INTERMEDIATE',
      reasonerMaxTokens: 8000, reasonerTimeoutMs: 300000
    },
    qwenHint: { enabled, url, format: 'chat', fallback: true, timeoutMs: 45000 }
  }
}
```

Everything in the system reads from this object. The full environment variable reference
is Appendix B.

> 💡 **Design Note — read config at call-time, never capture it.** Because the runtime
> overlay (below) mutates this object *in place*, every consumer reads `config.x.y` when
> it needs the value, not into a module-level constant at import time. The worker even
> carries a comment warning future maintainers: read `config.generation.*` at call time.
> Capturing a value once would silently ignore live admin changes.

## 7.2 The runtime settings overlay

The admin Settings panel (`PUT /admin/settings`) can override most tunables without a
restart. Three pieces collaborate.

> 🎨 **FIGURE 7.1 — The runtime settings overlay**
> *Diagram — generate with Claude image generation.* **Prompt:**
> "A horizontal flow diagram on white with indigo accents. Left: 'Admin Settings UI'
> sends 'PUT /admin/settings {key,value}'. Middle: a box 'settings.service.ts' with
> three steps stacked — '1. validate against settingsRegistry', '2. upsert into Mongo
> AppSettings', '3. applyToConfig: setByPath(config, def.path, value) — MUTATE IN
> PLACE'. An arrow from step 3 to a glowing box 'live config singleton'. Below, a
> dashed arrow labelled 'if reresolveAI flag' to a box 'rebuild AIClient (Proxy swaps
> activeClient)'. Right: many small consumers (controllers, worker, ai.service) all
> reading 'config.x.y at call-time'. Show secrets as a separate locked box labelled
> 'env-only, never in Mongo, shown as configured/not-configured'. Flat, hairline."

### 7.2.1 The registry — `config/settingsRegistry.ts`

A code registry maps each settings **KEY** to a dotted **path** into the `config`
object, plus metadata:

```ts
interface SettingDef {
  key, path, type,           // 'AI_PROVIDER', 'ai.provider', 'enum'
  group, label, help?,
  options?, min?, max?,      // validation
  sensitive?, editable?,     // flavour (see below)
  reresolveAI?               // does changing this require rebuilding the AI client?
}
```

About 35 keys are registered, in groups: *AI Provider, DeepSeek, DeepSeek Reasoner,
Gemini, Qwen Hint, Generation, Judge0, Auth, Secrets, Infrastructure.* Each key falls
into one of three **flavours**:

| Flavour | Behaviour |
|---------|-----------|
| **Editable** (default) | Admin-tunable; the override is persisted in Mongo and applied live. |
| **Sensitive** (`sensitive: true`) | A secret. **Never** stored in Mongo, never returned — the API reports only a `configured` boolean. Writes are rejected. |
| **Read-only** (`editable: false`) | Infrastructure that genuinely needs a restart (`PORT`, `NODE_ENV`). |

A representative slice of the map:

| Key | Config path | Flavour |
|-----|-------------|---------|
| `AI_PROVIDER` | `ai.provider` | editable, **reresolveAI** |
| `DEEPSEEK_MODEL` | `ai.deepseek.model` | editable, **reresolveAI** |
| `DEEPSEEK_TEMPERATURE` / `_MAX_TOKENS` / `_TIMEOUT_MS` | `ai.deepseek.*` | editable |
| `DEEPSEEK_REASONER_ENABLED` / `_KINDS` / `_MIN_DIFFICULTY` | `ai.deepseek.reasoner*` | editable |
| `GENERATION_PACING_MS` / `INITIAL_LESSON_COUNT` / `COURSE_LESSON_COUNT` / … | `generation.*` | editable |
| `QWEN_HINT_ENABLED` / `_URL` / `_FORMAT` | `ai.qwenHint.*` | editable |
| `JUDGE0_DASHBOARD` | `judge0.dashboard` | editable |
| `JWT_EXPIRES_IN` | `jwt.expiresIn` | editable |
| `DEEPSEEK_API_KEY` / `GEMINI_API_KEY` / `JWT_SECRET` / `DATABASE_URL` | — | **sensitive** |
| `PORT` / `NODE_ENV` | `port` / `nodeEnv` | **read-only** |

### 7.2.2 The service — `services/settings.service.ts`

This is where overrides become reality.

- **At boot**, the service snapshots the env-derived defaults into an `ENV_DEFAULTS` map
  (so a reset can restore them), then `loadAppSettings()` reads every `AppSettings`
  document, validates and coerces it, and applies it **in place** onto `config` via
  `setByPath`. Stale, secret, and read-only keys are skipped.

  ```ts
  for (const doc of await AppSettings.find().lean()) {
    const def = getSettingDef(doc.key)
    if (!def || !isEditable(def)) continue          // skip stale / secret / read-only
    const result = coerceSettingValue(def, doc.value)
    if (!result.ok) continue
    applyToConfig(def, result.value)                // setByPath(config, def.path, value)
  }
  fireApplied()
  ```

- **On save** (`updateSettings`), the change is **all-or-nothing**: every entry is
  validated first (unknown key, secret, read-only, or bad value → reject the whole
  batch), then each is upserted into Mongo and applied to the live config. If any changed
  key carries the `reresolveAI` flag, it fires the applied-hook.

- **On reset** (`resetSetting`), the Mongo document is deleted and the value restored
  from `ENV_DEFAULTS`.

`getEffectiveSettings()` powers the admin UI: each setting is annotated with `source`
(`db` vs `env`), `editable`, and `sensitive`; secrets report `value: null` plus a
`configured` boolean.

### 7.2.3 Live AI-client rebuild — the Proxy trick

Most settings take effect simply because consumers re-read `config` at call-time. But
the **AI client** is an *object* built from the config (which provider, which models), so
re-reading a field isn't enough — the object itself must be rebuilt.

The solution (`services/ai.service.ts`):

```ts
let activeClient = resolveAIClient()                 // FallbackAIClient or Gemini-only
export const aiClient = new Proxy({} as AIClient, {
  get: (_t, prop) => { const v = activeClient[prop]; return typeof v === 'function' ? v.bind(activeClient) : v }
})
function reresolveAIClient() { activeClient = resolveAIClient() }
onSettingsApplied(reresolveAIClient)                 // registered with the settings service
```

`aiClient` is a **Proxy** that always delegates to the current `activeClient`. When a
`reresolveAI`-flagged setting (e.g. `AI_PROVIDER`, `DEEPSEEK_MODEL`) is saved,
`fireApplied()` calls `reresolveAIClient()`, which rebuilds `activeClient` — and because
everyone holds the Proxy, not the underlying object, the swap is invisible and instant.

> 💡 **Design Note — `onSettingsApplied` breaks a circular import.** `settings.service`
> must trigger an `ai.service` rebuild, but `ai.service` already imports config the
> settings service mutates. A direct call would create an import cycle. Instead,
> `settings.service` exposes a tiny `onSettingsApplied(fn)` registration hook;
> `ai.service` registers its rebuild function at import time; `fireApplied()` calls the
> registered hooks. Classic dependency inversion — the low-level module doesn't know who
> it's notifying.

## 7.3 What this buys operationally

The overlay turns a whole class of "needs a redeploy" changes into a UI toggle:

- **Switch the AI provider** from DeepSeek to Gemini (or back) live.
- **Swap models** (`deepseek-chat` → a newer model) without touching code.
- **Retune the reasoner** — enable/disable it, change which challenge kinds and
  difficulties route to it, adjust its token budget and timeout.
- **Reshape generation** — how many lessons a new course outlines, how many an extension
  adds, the pacing delay that keeps the worker under free-tier rate limits.
- **Repoint Judge0** at a different sandbox URL.

Secrets stay where they belong — in the environment, never in the database, shown in the
UI only as *configured / not configured*. `PORT` and `NODE_ENV` are explicitly read-only
because they genuinely require a restart.

> ⚠️ **Implementation Note — the registry's help text vs. the code.** A couple of keys
> are aspirational: `JWT_EXPIRES_IN` is registered as editable, but (per Chapter 6) the
> auth controller currently signs with a hard-coded `'7d'`, so changing it has no effect
> on new tokens until the controller is updated to read `config.jwt.expiresIn`.

This closes Part II. We have the data, the API, the trust model, and the configuration
machinery. Part III crosses to the browser.
