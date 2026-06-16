# Chapter 4 — Data Models

Everything in SigmaLoop is a document in MongoDB, described by a Mongoose schema in
`Backend/src/models/`. This chapter is the domain-model reference: every collection,
its fields, its indexes, and how it relates to the others. Two patterns are worth
internalizing before the tables:

- **Per-user ownership is pervasive.** Almost every model carries a `userId`, because
  there is no shared content — a course, its lessons, its challenges, and even
  translations all belong to exactly one learner.
- **Two models are polymorphic** via Mongoose **discriminators** on a `kind` field:
  `Challenge` (PROGRAMMING / MATH / MCQ) and `Submission` (one shape per kind).

> 🎨 **FIGURE 4.1 — Entity-relationship diagram**
> *Diagram — generate with Claude image generation.* **Prompt:**
> "A clean entity-relationship diagram on a white background, indigo (#6366f1) accent.
> Central entity **User**. From User, one-to-many edges to: **ChatThread** (→
> **ChatMessage**), **CurriculumJob**, **Course**, **MentorAction**. **Course**
> one-to-many **Lesson**; **Lesson** one-to-many **Challenge**; **Challenge** shown as a
> discriminated entity with three sub-types PROGRAMMING / MATH / MCQ. **Submission**
> links **User** and **Challenge**, also discriminated into PROGRAMMING/MATH/MCQ.
> **LessonProgress** links **User** and **Lesson** (unique pair). **LessonTranslation**
> links **Lesson**+language; **UiTranslation** stands alone (global cache). **AppSettings**
> stands alone. Show crow's-foot notation, label each edge with its foreign key
> (userId, courseId, lessonId, challengeId, threadId). Flat, hairline borders, no
> shadows."

## 4.1 The model catalogue

| Model | Purpose | Key relations |
|-------|---------|---------------|
| **User** | Account (role STUDENT \| ADMIN), preferences, stats | root of ownership |
| **ChatThread** | A mentor-chat container, scoped GENERAL \| COURSE \| LESSON | belongs to User |
| **ChatMessage** | A message in a thread (USER \| ASSISTANT \| SYSTEM) | belongs to ChatThread |
| **CurriculumJob** | An async generation job | owned by User, may target a Course |
| **Course** | A personalized course (PENDING→GENERATING→READY/FAILED) | owned by User |
| **Lesson** | A generated lesson (STUB→GENERATING→READY) | belongs to Course |
| **Challenge** | A generated challenge, discriminated by `kind` | belongs to Lesson |
| **Submission** | A learner's attempt, discriminated by `kind` | User + Challenge |
| **LessonProgress** | Lesson completion state (unique User+Lesson) | User + Lesson |
| **MentorAction** | Append-only audit log of a mentor mutation | owned by User |
| **AppSettings** | One runtime config override per key | standalone |
| **LessonTranslation** | Per-(lesson, language) translation cache | Lesson + language |
| **UiTranslation** | Global UI-string translation cache (hash-deduped) | standalone |

> ⚠️ **Implementation Note — models that do *not* exist.** There is no `Enrollment`,
> no separate `GeneratedCourse`/`GeneratedLesson`, and no INSTRUCTOR role anywhere.
> These were part of the old LMS design and have been removed. The `Graduation Project/`
> PDFs still show them; ignore those for the current system.

## 4.2 User — `models/User.ts`

The account, and the root of all ownership.

| Field | Type | Default / constraints |
|-------|------|------------------------|
| `email` | String | required, **unique**, lowercased, trimmed |
| `passwordHash` | String | required (bcrypt, cost 10) |
| `role` | enum `STUDENT` \| `ADMIN` | default `STUDENT` |
| `profileData` | Mixed | default `null` (e.g. `{ name }`) |
| `preferences.notifications` | `{ curriculumReady, weeklyProgress, productUpdates }` | `true, true, false` |
| `preferences.privacy` | `{ marketingEmails, usageAnalytics }` | `false, true` |
| `preferences.localization` | `{ language: 'en', direction: 'ltr' \| 'rtl' }` | direction derived server-side |
| `preferences.learning` | `{ lessonLockMode: 'PROGRESS' \| 'VIEW_ALL' }` | default `PROGRESS` |
| `stats` | `{ streakDays, totalXp, lessonsCompleted, lastActiveAt }` | `0, 0, 0, null` |

Timestamps: `createdAt` only. The only index is the implicit unique index on `email`.

- `lessonLockMode` gates lesson navigation: `PROGRESS` requires finishing a lesson
  before the next unlocks; `VIEW_ALL` frees them all.
- `localization.direction` is **never trusted from the client** — it is re-derived from
  `language` on every preference write (Chapter 15).
- `stats` drives the dashboard; `streakDays`/`lastActiveAt` power the streak logic in
  `progress.service.ts` (Chapter 14).

## 4.3 Chat: ChatThread & ChatMessage

**ChatThread** (`models/ChatThread.ts`) — a conversation container.

| Field | Type | Notes |
|-------|------|-------|
| `userId` | → User | required |
| `title` | String | required |
| `scope` | enum `GENERAL` \| `LESSON` \| `COURSE` | default `GENERAL` |
| `scopeId` | ObjectId | the course/lesson id when scoped; untyped by ref |

Index: `{ userId: 1, scope: 1, scopeId: 1 }`. Timestamps: both.

**ChatMessage** (`models/ChatMessage.ts`) — append-only, immutable.

| Field | Type | Notes |
|-------|------|-------|
| `threadId` | → ChatThread | required |
| `role` | enum `USER` \| `ASSISTANT` \| `SYSTEM` | required |
| `content` | String | required |

Timestamps: `createdAt` only (messages never change). Only the **final** assistant
message of a mentor tool-loop is persisted; the intermediate tool turns are ephemeral
(Chapter 13).

## 4.4 CurriculumJob — `models/CurriculumJob.ts`

The async generation request. This is the contract between the chat/onboarding entry
points and the worker.

| Field | Type | Notes |
|-------|------|-------|
| `userId` | → User | required |
| `threadId` | → ChatThread | default null (the chat that triggered it) |
| `type` | enum `NEW_COURSE` \| `EXTEND_COURSE` \| `GENERATE_CHALLENGES` | default `NEW_COURSE` |
| `prompt` | String | required |
| `difficulty` | enum `BEGINNER` \| `INTERMEDIATE` \| `ADVANCED` \| null | default null |
| `targetCourseId` | → Course | default null (for extend / challenge jobs) |
| `focus` | String | default null |
| `lessonCount` | Number | default null, **min 1, max 12** |
| `goals` | Mixed | structured questionnaire answers |
| `status` | enum `PENDING` \| `GENERATING` \| `READY` \| `FAILED` | default `PENDING` |
| `courseId` | → Course | set once the course exists |
| `error` | String | failure message |

Indexes: `{ status: 1, createdAt: 1 }` (the worker's claim query) and
`{ userId: 1, createdAt: -1 }` (job lists). Timestamps: both. The three job types and
their handling are the whole of Chapter 12.

## 4.5 Course — `models/Course.ts`

| Field | Type | Notes |
|-------|------|-------|
| `userId` | → User | required (every course is per-user) |
| `title` | String | required |
| `description` | String | required |
| `difficulty` | enum `BEGINNER` \| `INTERMEDIATE` \| `ADVANCED` | default `BEGINNER` |
| `tags` | [String] | default `[]` |
| `language` | String | a `SUPPORTED_LANGUAGES` key; **unset** for math-only courses |
| `status` | enum `PENDING` \| `GENERATING` \| `READY` \| `FAILED` | default `PENDING` |

Index: `{ userId: 1, createdAt: -1 }`. Timestamps: `createdAt` only.

The `language` field is load-bearing: when set, it **pins every programming challenge in
the course to that one language**, and it decides the "anchor kind" for practice sets
(`language ? PROGRAMMING : MATH`). When unset, the course is treated as math/agnostic.

## 4.6 Lesson — `models/Lesson.ts`

This is where the system's laziness lives.

| Field | Type | Notes |
|-------|------|-------|
| `userId` | → User | required |
| `courseId` | → Course | required |
| `title` | String | required |
| `orderIndex` | Number | required (position in the course) |
| `contentMarkdown` | String | default `''` (empty for challenge-only lessons) |
| `status` | enum `STUB` \| `GENERATING` \| `READY` | **default `READY`** |
| `challengeOnly` | Boolean | default false (practice lessons skip the body) |
| `summary` | String | default `''` (outline summary; used as generation context) |
| `challengeSpecs` | `[{ kind, topic, difficulty? }]` | the per-challenge plan kept on a stub |

Index: `{ courseId: 1, orderIndex: 1 }`. Timestamps: `createdAt` only.

> 💡 **Design Note — why `status` defaults to `READY`, not `STUB`.** Lazy generation
> writes new lessons as `STUB`s and materializes them on demand. But lessons created
> *before* that feature (or by the mentor's manual `create_lesson` tool) have no stub
> machinery — defaulting to `READY` means legacy and hand-authored lessons are treated
> as already-generated and render immediately, while only true stubs trigger
> on-open materialization. The `challengeSpecs` subdocument is the seed the worker
> expands into real `Challenge` documents (Chapter 12).

## 4.7 Challenge — the first discriminator — `models/Challenge.ts`

`Challenge` is a Mongoose **discriminator** keyed on `kind`. A base schema holds the
common fields; three sub-schemas add the kind-specific shape.

**Base** (`discriminatorKey: 'kind'`, index `{ lessonId: 1 }`, `createdAt` only):

| Base field | Type | Notes |
|------------|------|-------|
| `userId` | → User | required |
| `lessonId` | → Lesson | required |
| `title` | String | required |
| `kind` | discriminator | `PROGRAMMING` \| `MATH` \| `MCQ` |

```ts
// models/Challenge.ts — the discriminator setup (abridged)
const ChallengeSchema = new Schema<IChallengeBase>(
  {
    userId:   { type: Schema.Types.ObjectId, ref: 'User',   required: true },
    lessonId: { type: Schema.Types.ObjectId, ref: 'Lesson', required: true },
    title:    { type: String, required: true, trim: true }
  },
  { timestamps: { createdAt: true, updatedAt: false }, discriminatorKey: 'kind' }
)
export const Challenge = mongoose.model('Challenge', ChallengeSchema)
export const ProgrammingChallenge = Challenge.discriminator('PROGRAMMING', ProgrammingChallengeSchema)
export const MathChallenge        = Challenge.discriminator('MATH', MathChallengeSchema)
export const MCQChallenge         = Challenge.discriminator('MCQ', MCQChallengeSchema)
```

**PROGRAMMING sub-schema:**

| Field | Type | Notes |
|-------|------|-------|
| `description` | String | required (markdown prompt) |
| `starterCodes` | `{ python?, cpp?, java?, javascript?, typescript?, go?, rust? }` | default `{}` |
| `solutionCodes` | same shape | **server-only** (reference solution) |
| `testCases` | `[{ input: '', expectedOutput (required), isHidden: false }]` | |

A `pre('validate')` hook requires at least one starter language, at least one solution
language, and at least one test case.

**MATH sub-schema:**

| Field | Type | Notes |
|-------|------|-------|
| `problemLatex` | String | required |
| `canonicalSolutionLatex` | String | required, **server-only** |
| `gradingRubric` | String | default `''`, **server-only** |
| `mathRunLimit` | Number | default 10, min 1 (caps practice runs) |

**MCQ sub-schema:**

| Field | Type | Notes |
|-------|------|-------|
| `prompt` | String | required (markdown stem) |
| `options` | `[{ _id, text, isCorrect, explanation }]` | `_id` is the **stable option identity**; `isCorrect`/`explanation` are **server-only** |
| `allowMultiple` | Boolean | required, default false |
| `overallExplanation` | String | default `''`, **server-only** |

Its `pre('validate')` hook enforces ≥2 options, ≥1 correct, and — when not
`allowMultiple` — **exactly one** correct option.

> 💡 **Design Note — `_id` as option identity.** Each MCQ option is a subdocument with
> its own Mongoose `_id`. That id is what the client selects and what the grader
> compares — so option text can be translated, reordered, or rewritten without
> breaking grading, and the correctness flags never need to travel to the client
> (Chapter 14).

## 4.8 Submission — the second discriminator — `models/Submission.ts`

`Submission` mirrors `Challenge`: a base + three sub-shapes, discriminated on `kind`.

**Base** (`discriminatorKey: 'kind'`, index `{ userId: 1, challengeId: 1, kind: 1 }`):

| Base field | Type | Notes |
|------------|------|-------|
| `userId` | → User | required |
| `challengeId` | → Challenge | required |
| `status` | enum `PENDING` \| `RUNNING` \| `PASSED` \| `FAILED` \| `PENDING_REVIEW` | required |
| `kind` | discriminator | PROGRAMMING / MATH / MCQ |

- **PROGRAMMING_SUBMISSION:** `code`, `language` (one of the 7), `outputLog`, `metrics`.
- **MATH_SUBMISSION:** `latex`, `verdict { correct, equivalentForm, rationale, confidence(0–1) }`, `isFinal`.
- **MCQ_SUBMISSION:** `selectedOptionIds: string[]`, `verdict { correct, partial, correctOptionIds, rationale }`.

> ⚠️ **Implementation Note — discriminator naming quirk.** Unlike `Challenge` (whose
> discriminator name *is* the `kind` value), the submission discriminators register
> under a different model name with an explicit value:
> `Submission.discriminator('PROGRAMMING_SUBMISSION', schema, { value: 'PROGRAMMING' })`.
> The **stored `kind` is still `PROGRAMMING`/`MATH`/`MCQ`** — only the registered model
> name differs. Worth knowing if you ever query by discriminator model.

## 4.9 LessonProgress — `models/LessonProgress.ts`

| Field | Type | Notes |
|-------|------|-------|
| `userId` | → User | required |
| `lessonId` | → Lesson | required |
| `isCompleted` | Boolean | default false |
| `completedAt` | Date | default null |

**Unique compound index** `{ userId: 1, lessonId: 1 }` — exactly one record per learner
per lesson. A lesson flips to complete only when **every** challenge in it has a
`PASSED` submission (Chapter 14). Completion is sticky: it is never revoked, so XP is
never clawed back.

## 4.10 MentorAction — `models/MentorAction.ts`

The append-only audit log of every mutation the autonomous mentor performs.

| Field | Type | Notes |
|-------|------|-------|
| `userId` | → User | required |
| `threadId` | → ChatThread | default null |
| `type` | enum `CREATE_COURSE` \| `GENERATE_MORE_LESSONS` \| `CREATE_LESSON` \| `EDIT_LESSON` \| `UPDATE_COURSE` \| `OTHER` | required |
| `summary` | String | required (human-readable) |
| `courseId` / `lessonId` / `jobId` | refs | default null |

Index `{ userId: 1, createdAt: -1 }`, `createdAt` only. *Reads* the mentor performs are
not logged — only mutations. This is the durable counterpart to the per-response
`actions[]` array (Chapter 13).

## 4.11 Config & i18n caches

- **AppSettings** (`models/AppSettings.ts`) — one document per overridden config key:
  `{ key (unique), value (Mixed), updatedBy? }`. Secrets are **never** written here
  (Chapter 7).
- **LessonTranslation** (`models/LessonTranslation.ts`) — a per-(lesson, language)
  cache of translated prose: `{ lessonId, userId, language, title, contentMarkdown,
  challenges[], translatedAt }`, unique on `{ lessonId, language }`. Stores only prose;
  code, LaTeX, and MCQ answer keys are never translated (Chapter 15).
- **UiTranslation** (`models/UiTranslation.ts`) — a **global** cache of translated UI
  strings: `{ language, sourceHash, value }`, unique on `{ language, sourceHash }`.
  Identical English strings dedupe to one row by SHA-256 hash, shared across all users.

## 4.12 The barrel and how models are used

`models/index.ts` re-exports every model. Controllers and services import from there.
Two query habits recur and are worth recognizing:

- **Ownership filter** — nearly every read is `Model.find({ ..., userId })`, which is
  how the 404-not-403 ownership guarantee is implemented at the data layer.
- **`distinct` for progress** — completion is computed by comparing
  `Challenge.distinct('_id', { lessonId })` against
  `Submission.distinct('challengeId', { userId, status: 'PASSED', challengeId: {$in} })`.
  That set comparison *is* the "all challenges passed" rule (Chapter 14).

With the nouns of the system defined, Chapter 5 turns to the verbs: the API.
