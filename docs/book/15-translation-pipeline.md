# Chapter 15 — The Translation Pipeline ★

> *A focus chapter. How SigmaLoop speaks 30 languages — including the AI-generated
> content — with no static translation files and first-class right-to-left support.*

Most apps localize a fixed set of UI strings from a translator-maintained catalogue.
SigmaLoop has a harder problem: not only the chrome but the **AI-generated course content
itself** must be translatable, and there is no human translator in the loop. The solution
is two complementary, fully custom systems built on the same AI provider — and,
notably, **no off-the-shelf i18n library and no static translation files** anywhere.

## 15.1 Two systems, three things translated

| What | Mechanism | Cache |
|------|-----------|-------|
| **UI chrome strings** | `POST /i18n/translate` (AI, batched) | `UiTranslation` — global, hash-deduped |
| **Lesson / challenge prose** | `POST /lessons/:id/translate` (AI) | `LessonTranslation` — per (lesson, language) |
| **Mentor chat replies** | *not translated* — a system-prompt instruction tells the model to reply in the target language | — |

The first two are AI translation with caching; the third is generation-in-language. We
take them in turn.

> 🎨 **FIGURE 15.1 — The translation pipeline**
> *Diagram — generate with Claude image generation.* **Prompt:**
> "A diagram on white with indigo accent, three lanes. Lane 1 'UI strings': a React
> component calls t('Save') → 'i18n registry (Set of English strings)' → batched 'POST
> /i18n/translate' → 'SHA-256 hash' → cylinder 'UiTranslation (global cache)'; miss →
> 'aiClient.translateStrings (batch of 50)'. Lane 2 'Lesson content': 'POST
> /lessons/:id/translate' → 'extractTranslatable (branch on kind: body, PROGRAMMING
> description, MATH problemLatex prose, MCQ prompt+option text)' → markdown fields to
> 'translateMarkdown', short labels to 'translateStrings' → cylinder 'LessonTranslation
> (per lesson+language)'. Lane 3 'Mentor': 'buildLanguageInstruction → system prompt:
> reply in {language}, keep code & LaTeX verbatim'. Bottom band: 'English is always a
> no-op — never cached, never sent to AI'. Show a small RTL flag note: '<html dir> flips
> layout; code/math pinned LTR'. Hairline."

## 15.2 The locale catalogue

`Backend/src/constants/locales.ts` (mirrored on the frontend) defines 30 locales, each
`{ code, name, nativeName, dir }`:

- `name` (English) is injected into translation prompts.
- `nativeName` (endonym) is shown in the picker.
- `dir` is the **authoritative** layout direction: `rtl` for `ar`, `he`, `fa`, `ur`; `ltr`
  for the other 26.
- `DEFAULT_LOCALE = 'en'` is the authoring language — nothing is ever translated or cached
  for English.

> 💡 **Design Note — `dir` is server-owned.** The catalogue's comment is explicit: *the
> client never decides direction on its own.* On every preference write the server
> re-derives `direction` from `language` via `getLocaleDir()`. The client cannot send a
> mismatched `{ language: 'ar', direction: 'ltr' }`; direction is a function of language,
> computed in one place. This is also a security/consistency property — there is one
> source of truth for something that controls the entire layout.

(Note: this `locales.ts` is *not* `constants/languages.ts` — that's the seven
*programming* languages for code challenges. Different axis entirely.)

## 15.3 Backend: the AI translation service

Two methods were added to the `AIClient` interface (Chapter 11), implemented by both
providers and composed by the fallback:

```ts
translateMarkdown(markdown, targetLanguage): Promise<string>   // prose; preserve code/LaTeX/structure
translateStrings(texts, targetLanguage): Promise<string[]>     // short UI labels, batched, same order
```

The two prompts are the load-bearing part. The **markdown prompt** instructs the model to
translate only human-readable prose into the target language while preserving *exactly*:
fenced and inline code (and all identifiers/keywords/output), inline and display LaTeX
(`$...$`, `$$...$$`), markdown structure, URLs, file paths, HTML tags, and the brand name
"SigmaLoop." It returns only the translated markdown. The **short-strings prompt** adds
two product-specific rules:

- Preserve placeholders (`{name}`, `{count}`, `%s`) and HTML tags exactly.
- Preserve the **`[[word]]` highlight marker**: a phrase like `Master the [[logic]]
  behind the code` marks "logic" as a highlighted word; the translator must translate the
  word *inside* the brackets but keep the brackets in the natural position for the target
  language (the prompt gives an Arabic worked example).

> 💡 **Design Note — translate the highlight, keep the markers.** The product tagline
> highlights one word with `[[ ]]` markers that the frontend renders as an accent span.
> Naively translating would either drop the markers or leave the bracketed word in
> English. The prompt teaches the model to move the markers to wherever the highlighted
> word lands in the translated sentence — a tiny rule with an outsized effect on whether
> the localized landing page looks native or broken.

Output is normalized to a **same-length array**, echoing the English source on any gap, so
a malformed batch never breaks index alignment or silently drops a string. Translation
always runs on the fast base model (never the reasoner).

## 15.4 Backend: the two endpoints and their caches

### UI strings — `POST /i18n/translate` (public, globally cached)

This endpoint is intentionally **unauthenticated** — guests on the landing and login
pages must localize too. The flow: English/unsupported → echo source, no AI; otherwise
SHA-256-hash each text, look up `UiTranslation` by `{ language, sourceHash }`, translate
the misses in batches of 50, upsert them, and re-expand to the caller's keys (falling back
to source on any gap). Guard rails: ≤1,500 entries, ≤2,000 chars each. A provider
rate-limit maps to `429 RATE_LIMITED`.

`UiTranslation` is **global and hash-deduped**: UI chrome is identical for everyone, so
each distinct English string is translated once per language and shared across all users.

### Lesson prose — `POST /lessons/:id/translate` (per-user, per-lesson)

`extractTranslatable` pulls the translatable prose from the *student-safe* lesson payload
and **branches on `challenge.kind`**:

- lesson `title` + `contentMarkdown`;
- per challenge: `title`;
- PROGRAMMING: `description`;
- MATH: `problemLatex` (prose translated, LaTeX preserved);
- MCQ: `prompt` + each option's `text` (option **ids unchanged**).

It routes markdown-bearing fields to `translateMarkdown` (one call each, in parallel) and
short labels to a single batched `translateStrings` call, then upserts a
`LessonTranslation` keyed `{ lessonId, language }`. A companion `GET /:id/translation` is a
**pure cache read** — it never calls the AI — so reopening a lesson restores the chosen
language without re-spending tokens.

> 💡 **Design Note — never translate code, math, or answer keys.** What is *not* in the
> translatable set is as important as what is: source/solution code, LaTeX expressions,
> and MCQ option ids and correctness are never sent to the translator and never stored in
> `LessonTranslation`. The frontend merges the translated prose *over* the original
> challenge, re-keying on `challengeId`, so code, equations, option identity, and the
> `passed` flags survive untouched. Translating an identifier or an option id would break
> grading; the schema structurally prevents it.

When a lesson is edited (by the mentor's `update_lesson` tool, Chapter 13), its cached
`LessonTranslation` documents are deleted so stale translations don't survive the edit.

## 15.5 Frontend: on-demand, key-less i18n

There is no static catalogue. The English string **is** the key, and strings register
themselves the first time they render.

- **`i18n/registry.ts`** — a module-level `Set<string>` of every English string seen
  through `t()`. It lives outside React so `t()` can register during render.
- **`LocaleContext`** — exposes `{ language, direction, isTranslating, isPageLoading,
  setLanguage, t }`. `t(text, params?)` registers `text`, then returns the cached
  translation (or the English fallback) with `{placeholder}` interpolation:
  `t("Lesson {n}", { n: 3 })`.

The translation loop runs in a `useLayoutEffect` keyed on `[language, pathname]`: on a
language change it drops the previous map, diffs the registry against already-translated
strings, sends the missing batch to `i18nService.translateUi`, and marks every requested
string done (echoing source on gaps) so it never loops on a string. A debounced
subscription catches strings discovered later (e.g. from async data).

> 💡 **Design Note — the pre-paint skeleton avoids a flash of English.** Because
> translation is fetched at runtime, a naive implementation would paint English, then
> swap to the target language a beat later — an ugly flicker, doubly so for RTL. The
> provider uses `useLayoutEffect` (which runs *before* paint) and initializes
> `isPageLoading = true` when a non-English language is already persisted, so the very
> first paint is a full-screen skeleton (`TranslationLoadingScreen`), not English text.
> An incremental top-up (strings found mid-session) shows only a slim top bar instead.
> The cost — runtime translation latency — is paid once per (string, language) and then
> cached forever.

## 15.6 The language switcher and persistence

`LanguageSwitcher` (in the navbar, available even to guests) offers a featured short-list
(`en, ar, zh-CN, hi`) plus a searchable, portaled full-list modal that annotates RTL
locales with "· RTL". Choosing a language flips the UI instantly via `setLanguage`, and —
if authenticated — fire-and-forget persists it via `userService.updatePreferences`.

Precedence is **server > localStorage**: a guest's choice lives in `localStorage["locale"]`;
once the user loads, `user.preferences.localization.language` (the server's value)
overrides it. On logout, an `auth:logout` event clears the stored language so the next
guest session starts in English/LTR. The single line that drives the entire RTL/LTR
layout is in `LocaleContext`: `root.lang = language; root.dir = getLocaleDir(language)`.

## 15.7 The mentor: instruction, not translation

The mentor's *replies* are **generated directly in the target language** rather than
translated after the fact. `buildLanguageInstruction(userId)` reads
`user.preferences.localization.language` and appends a plain-prose instruction to the
system prompt — "always respond in {language}; keep code and LaTeX exactly as they are; if
the learner writes in a different language, match it." Because it's prose in an ordinary
turn, it survives a mid-conversation provider failover (Chapter 13).

## 15.8 Right-to-left, done properly

The whole UI mirrors under `[dir="rtl"]`, but code and math must **not** mirror. The
carve-out in `index.css`:

```css
[dir="rtl"] pre, [dir="rtl"] code, [dir="rtl"] .katex, [dir="rtl"] .katex-display,
[dir="rtl"] math-field, [dir="rtl"] .monaco-editor { direction: ltr; }
[dir="rtl"] pre, [dir="rtl"] .katex-display { text-align: left; }
```

This pins Monaco, MathLive, KaTeX, and highlighted code blocks back to LTR even on an
Arabic page. The rest of the codebase uses **logical** Tailwind utilities (`ps-/pe-`,
`ms-/me-`, `text-start/end`, `start-/end-`) instead of physical ones, and `gap-x/gap-y`
instead of `space-x` (which breaks in RTL).

> ⚠️ **Implementation Note — the RTL spacing convention is load-bearing.** Flex spacing
> uses `gap-x`/`gap-y`, **not** `space-x` + `rtl:space-x-reverse`. The latter renders
> links "stuck together" in RTL; the codebase was converted to `gap-*` to fix it. New
> components must follow suit, or RTL layouts will regress.

## 15.9 Honest gaps

> ⚠️ **Implementation Note — what is *not* localized.** (1) The **guest mentor** gets no
> explicit language instruction — it relies on the model naturally matching the visitor's
> input language, because a guest has no saved preference. (2) The **Qwen lesson-hint
> model** receives no UI-language instruction, so in-lesson hints are not localized to the
> chosen UI language (its `language` field is the *programming* language of the editor).
> (3) There are no translation-specific config knobs — translation reuses the general AI
> token budgets and is pinned to the fast base model. These are documented limitations,
> not bugs, and are good first candidates if localization coverage is tightened.

## 15.10 Why build it this way

A static catalogue can't localize content that doesn't exist until a learner asks for it.
By making the English source the key, registering strings lazily, translating on demand,
and caching aggressively (globally for chrome, per-lesson for content), SigmaLoop gets
30-language coverage of *everything* — including freshly generated courses — with zero
catalogue maintenance, at the cost of runtime translation latency that each user pays once
per string and never again.

This closes Part IV. We have the whole AI core: the provider abstraction, the generation
pipeline, the agent that drives it, the graders, and the translation layer. Part V takes
all of it to production.
