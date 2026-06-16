# Chapter 11 — The AI Provider Abstraction

Every model call in SigmaLoop — mentor chat, curriculum generation, math grading,
translation — passes through one file: `Backend/src/services/ai.service.ts` (~1,300
lines). This chapter explains the abstraction that file provides: a single `AIClient`
interface, two concrete providers (DeepSeek and Gemini), a fallback composer, a hot-swap
Proxy, difficulty-aware model routing, and a JSON parser hardened against the realities
of LLM output. Understanding this chapter makes Chapters 12–15 easy.

## 11.1 The `AIClient` interface

The whole system depends only on this interface, never on a concrete provider:

```ts
interface AIClient {
  isConfigured(): boolean
  chat(input): Promise<string>
  generateFollowupQuestions(input): Promise<...>     // onboarding
  generateCourseOutline(input): Promise<...>         // NEW_COURSE
  generateCourseExtension(input): Promise<...>        // EXTEND_COURSE
  generateChallengeSet(input): Promise<...>           // GENERATE_CHALLENGES
  generateLesson(courseCtx, lesson): Promise<string>  // lesson body
  generateChallenge(lesson, spec): Promise<...>       // one challenge
  gradeMath(input): Promise<MathGradeVerdict>         // math grading
  translateMarkdown(md, lang): Promise<string>        // i18n prose
  translateStrings(texts, lang): Promise<string[]>    // i18n UI labels
}
```

> 💡 **Design Note — one interface is the swap point.** Both `CLAUDE.md` files state the
> hard rule: never import `@google/generative-ai` (or any model SDK) outside
> `ai.service.ts`, and never call a model API directly from a controller. Because every
> caller holds an `AIClient`, swapping the provider — DeepSeek↔Gemini today, Bedrock
> tomorrow — is *adding one class*, not editing business logic. The interface is the
> seam the whole "provider-agnostic" promise hangs on.

## 11.2 Two providers

**`DeepSeekAIClient`** speaks the OpenAI-compatible API: `POST {baseUrl}/chat/completions`
with a Bearer key. It is the **primary** provider.

**`GeminiAIClient`** speaks the Google Generative AI SDK (`gemini-2.5-flash`), mapping
the system prompt to `systemInstruction`, history to `Content[]` (`user`/`model`), and
JSON requests to `responseMimeType: 'application/json'`. It is the **fallback**.

A critical property: **both providers call the same prompt-builder functions.** The
prompts for outlines, lessons, challenges, grading, and translation are
provider-agnostic strings built once and handed to whichever provider runs. So a failover
mid-operation changes *who* answers, not *what was asked*.

## 11.3 `FallbackAIClient` — primary, then fallback, with a cooldown

The composer wraps both:

```ts
class FallbackAIClient {
  constructor(primary, fallback) { ... }
  private primaryDownUntil = 0

  async run(label, fn) {
    if (this.primary.isConfigured() && Date.now() >= this.primaryDownUntil) {
      try { return await fn(this.primary) }
      catch (err) {
        this.primaryDownUntil = Date.now() + COOLDOWN_MS   // default 60s
        console.warn(`[AI] primary failed on ${label}; failing over`, err)
      }
    }
    if (this.fallback.isConfigured()) return await fn(this.fallback)
    throw /* the primary error */
  }
  // every interface method is just: run('label', c => c.method(...))
}
```

> 💡 **Design Note — the 60-second cooldown.** A naive fallback retries the primary on
> *every* call. If DeepSeek is unreachable, each request then eats DeepSeek's full
> timeout *before* falling over — multiplying latency across a whole burst. The cooldown
> says: once the primary fails, don't even try it again for 60 s; go straight to the
> fallback. After 60 s it probes the primary once more. This bounds the cost of an
> outage to one slow request per minute, not one per call.

Because every artefact is produced by a *separate, stateless* call, a provider switch
between (say) generating lesson 3 and lesson 4 of the same course is completely safe —
no shared in-flight state to corrupt. This is the same property that lets the mentor's
tool loop survive a mid-conversation failover (Chapter 13).

## 11.4 Choosing the active client, and hot-swapping it

```ts
function resolveAIClient(): AIClient {
  if (config.ai.provider === 'deepseek' && deepseek.isConfigured())
    return new FallbackAIClient(deepseek, gemini)   // DeepSeek primary, Gemini fallback
  return gemini                                      // Gemini-only
}
```

If `AI_PROVIDER=deepseek` but no DeepSeek key is set, the system logs a warning and runs
**Gemini-only** — so a missing key degrades gracefully rather than crashing.

The exported `aiClient` is a **Proxy** over a mutable `activeClient`, and
`reresolveAIClient()` is registered with the settings service's `onSettingsApplied` hook
(Chapter 7). Net effect: an admin can change provider or model from the UI and the live
client rebuilds instantly, with every caller transparently using the new one.

## 11.5 Difficulty-aware model routing (the reasoner)

DeepSeek offers a base model (`deepseek-chat`) and a slower, stronger **reasoner**
(`deepseek-reasoner`). Using the reasoner for everything would be expensive and slow;
using it for nothing would hurt hard problems. So generation **routes by difficulty**:

```ts
function shouldUseReasoner(kind, difficulty): boolean {
  return config.ai.deepseek.reasonerEnabled
      && config.ai.deepseek.reasonerKinds.includes(kind)         // default PROGRAMMING, MATH
      && DIFFICULTY_RANK[difficulty] >= reasonerMinDifficulty     // default INTERMEDIATE
}
```

So an INTERMEDIATE-or-harder programming or math *challenge* is generated by the
reasoner (with a larger token budget and a 5-minute timeout); MCQs, lessons, outlines,
grading, and translation always use the cheap base model. Gemini has an analogous lever —
a larger `thinkingBudget` for hard challenges.

> 💡 **Design Note — the reasoner is for *authoring*, not *grading*.** Note what does
> **not** route to the reasoner: `gradeMath`. Grading runs on the fast base model on
> purpose — it's a bounded comparison with a rubric, not an open-ended generation, and it
> needs to be cheap because it runs on every submission. The expensive model is spent
> where quality is hardest to get (creating a non-trivial problem with a correct
> reference solution), not where it's cheap to verify.

When DeepSeek's reasoner runs, two API quirks are handled: `temperature` and JSON-mode
`response_format` are **dropped** (the reasoner ignores temperature and doesn't reliably
support JSON mode), and its chain-of-thought arrives in a separate `reasoning_content`
field while the actual answer stays in `content`.

## 11.6 Surviving LLM output: the JSON parser

Generation asks the model for JSON, but models wrap JSON in prose, in ```json fences, or
emit literal newlines inside string values. `ai.service.ts` therefore does **not** call
`JSON.parse` directly. `parseAIJson` tries a series of candidates:

1. the raw text;
2. the contents of the first ```json fenced block;
3. the slice from the first `{` to the last `}`.

Each candidate is tried as-is **and** after `escapeControlCharsInStrings` — a small state
machine that escapes literal control characters (newlines, tabs) **only when they appear
inside a JSON string literal**, leaving whitespace between tokens untouched. On total
failure it logs the first 2,000 characters and throws "AI returned invalid JSON…".

Layered on top are **two retry tiers**:

- **Client-level:** DeepSeek's `generateJSON` retries up to 3 times (a fresh generation
  usually parses) before the call fails over to Gemini.
- **Worker-level:** the curriculum worker treats "invalid JSON" / "validation failed" as
  *transient* and retries the whole generation with backoff (Chapter 12).

> 💡 **Design Note — distrust the model's output, structurally.** Beyond JSON parsing,
> the service pins `parsed.kind = spec.kind` after parsing (the model sometimes echoes
> the wrong kind), validates an outline's `language` against the supported set, drops
> malformed test cases, clamps a math `confidence` to `[0,1]` (invalid → `0`, which
> forces review), and forces practice-set composition regardless of what the model
> returned. The rule throughout: the model's text is an *untrusted input* to be
> validated, never a value to be trusted. This is what keeps a non-deterministic model
> from writing corrupt rows into the database.

## 11.7 Token and timeout budgets

The defaults (all admin-tunable, Chapter 7):

| Setting | DeepSeek | Gemini |
|---------|----------|--------|
| Generation max tokens | 8,000 | 65,536 |
| Chat / grading max tokens | 1,024 | — |
| Temperature | 0.3 (dropped for reasoner) | — |
| Thinking budget | reasoner 8,000 / timeout 300 s | 8,192 (hard: 24,576) |
| Request timeout | 120 s (reasoner 300 s) | — |

With the abstraction understood, we can read the three things it powers. Chapter 12 is
the big one: the generation pipeline.
