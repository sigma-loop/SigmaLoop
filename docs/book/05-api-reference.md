# Chapter 5 — The API Surface

The backend is a REST API rooted at `/api/v1`. This chapter documents the response
format, the routing structure, and every endpoint group. Appendix A repeats the
endpoint tables in a compact, printable form.

## 5.1 JSend: one response shape, always

Every response — success or error — follows **JSend** (`Backend/src/utils/jsend.ts`):

```jsonc
// success
{ "success": true, "data": { /* ... */ } }

// error
{ "success": false, "message": "Course not found", "code": "NOT_FOUND", "details": "..." }
```

The helpers are tiny and used everywhere:

```ts
success(data)                 // → { success: true, data }
error(message, code?, details?) // → { success: false, message, code?, details? }
```

Optional fields (`code`, `details`) are omitted when falsy. The frontend's Axios client
unwraps `data` on success and surfaces `message` on error (Chapter 8).

**Error codes** (`constants/errorCodes.ts`) are plain string constants grouped by domain:
`UNAUTHORIZED`, `FORBIDDEN`, `INVALID_CREDENTIALS`, `VALIDATION_ERROR`, `MISSING_FIELD`,
`NOT_FOUND`, `ALREADY_EXISTS`, `CONFLICT`, `EXECUTION_ERROR`, `UNSUPPORTED_LANGUAGE`,
`AI_SERVICE_ERROR`, `AI_NOT_CONFIGURED`, `MATH_RUN_LIMIT_EXHAUSTED`,
`CHALLENGE_TYPE_MISMATCH`, `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE`, `RATE_LIMITED`, and
more.

## 5.2 How routing is wired

`app.ts` mounts the aggregate router at `/api`, and `routes/index.ts` mounts each group
under `/v1/...`, so the **full base path is `/api/v1/<group>`**. The middleware pipeline
in `app.ts` is: manual CORS → `express.json()` / `urlencoded` → a request logger →
routes → a 404 handler → an error handler. (CORS is hand-rolled because `cors@2.8.x`
does not play well with Express 5.)

Each route group is one `*.routes.ts` file delegating to one `*.controller.ts`. Routes
attach middleware — typically `authenticate`, sometimes a rate-limiter (see the note
below), and for admin a role guard.

> ⚠️ **Implementation Note — the rate-limiters are currently no-ops.** Routes reference
> `apiLimiter`, `authLimiter`, and `executionLimiter`, but all three are presently
> exported as **pass-through** functions in `middlewares/rateLimit.middleware.ts` (the
> real `express-rate-limit` definitions are written but commented out). Re-enabling is a
> one-line swap per limiter. This matters for the security chapter (Chapter 6) and for
> any public-facing deployment.

## 5.3 The endpoint groups

The table below is the index; the subsections give the detail. "Auth" means a valid
Bearer JWT is required.

| Group | Base path | Auth | Theme |
|-------|-----------|------|-------|
| Health | `/health` | No | liveness |
| Auth | `/auth` | mixed | register / login / me |
| Users | `/users` | Yes | profile, dashboard, preferences, data export |
| Chat | `/chat` | mixed | mentor threads & messages (+ guest) |
| Curriculum | `/curriculum` | Yes | request generation, questionnaire, poll jobs |
| Courses | `/courses` | Yes | list/read own courses, generate more |
| Lessons | `/lessons` | Yes | read, materialize, translate |
| Challenges | `/challenges` | Yes | read (student-safe) |
| Execution | `/execution` | Yes | PROGRAMMING run/submit (Judge0) |
| Math | `/math` | Yes | MATH submit/run (LLM grader) |
| MCQ | `/mcq` | Yes | MCQ submit (deterministic) |
| i18n | `/i18n` | No | translate UI strings (public) |
| Admin | `/admin` | ADMIN | users, metrics, settings, god-panel CRUD |

### Health — `/health`
- `GET /` — liveness, `{ status: 'healthy', timestamp }`. No auth.

### Auth — `/auth`
- `POST /register` — create a STUDENT, return JWT + user. `400` validation / `409` conflict.
- `POST /login` — verify credentials, return JWT + user. `401` invalid.
- `GET /me` — **(auth)** current profile + preferences + stats.

### Users — `/users` (all auth)
- `GET /dashboard` — aggregated learner dashboard (stats + recent courses).
- `PUT /progress/:lessonId` — set lesson completion `{ isCompleted }`.
- `PATCH /profile` — update `{ name }`.
- `PATCH /password` — `{ currentPassword, newPassword }`.
- `PATCH /preferences` — notification / privacy / localization / learning toggles.
- `GET /export` — export all of the user's data.
- `DELETE /me` — delete the account (password confirmation in body).

### Chat — `/chat`
- `POST /guest` — **(optional auth)** the public, stateless, tool-less mentor.
- `GET /threads` — list the user's threads.
- `POST /threads` — create a thread (scope GENERAL/COURSE/LESSON).
- `POST /threads/import` — carry a guest transcript into a real thread on signup.
- `GET /threads/:threadId/messages` — list messages.
- `POST /threads/:threadId/messages` — **the autonomous mentor turn**; returns the
  assistant message, `actions[]`, and a legacy `curriculumJob`.
- `PATCH /threads/:threadId` — rename.
- `DELETE /threads/:threadId` — delete.

### Curriculum — `/curriculum` (all auth)
- `POST /request` — enqueue a `NEW_COURSE` job from a free-text `prompt` **or** a
  questionnaire `goals` object. Returns **202** with the job. `503 AI_NOT_CONFIGURED`
  if no provider is configured.
- `POST /questionnaire/next` — synchronous AI follow-up questions from chosen topics.
- `GET /jobs` — list the user's jobs.
- `GET /jobs/:jobId` — poll one job (ownership-scoped; `404` otherwise).

### Courses — `/courses` (all auth)
- `GET /` — list the **current user's** courses (optional `?status`).
- `GET /:courseId` — read one owned course.
- `GET /:courseId/syllabus` — the course → lessons syllabus.
- `POST /:courseId/generate-more` — enqueue an `EXTEND_COURSE` job (~5 lessons). **202**;
  `409` if the course is not `READY`.
- `POST /:courseId/generate-challenges` — enqueue a `GENERATE_CHALLENGES` job (one
  challenge-only practice lesson). **202**; `409` if not `READY`.
- `DELETE /:courseId` — delete the course and everything under it.

### Lessons — `/lessons` (all auth)
- `GET /:lessonId` — read an owned lesson; each challenge carries a `passed` flag.
- `GET /course/:courseId` — lessons of an owned course.
- `POST /:lessonId/generate` — **lazy materialization** of a `STUB` lesson (body +
  challenges). A no-op if already materialized (lets the client poll while `GENERATING`).
- `GET /:lessonId/translation` — read a cached translation (never calls the AI).
- `POST /:lessonId/translate` — on-demand AI translation (cached).
- `DELETE /:lessonId` — delete the lesson and its challenges/submissions/progress.

### Challenges — `/challenges` (all auth)
- `GET /:challengeId` — read one owned challenge, **student-safe serialized**.
- `GET /lesson/:lessonId` — challenges of an owned lesson.

### Execution — `/execution` (all auth) — PROGRAMMING
- `POST /run` — run against **public** test cases only; nothing persisted.
- `POST /submit` — run against **all** test cases, persist a submission, update progress.
- `GET /submissions` — list the user's programming submissions.

### Math — `/math` (all auth) — MATH
- `POST /run` — trial-grade LaTeX (decrements `mathRunLimit`); persisted, never completes a lesson.
- `POST /submit` — final grade via the LLM; `<0.7` confidence → `PENDING_REVIEW`.
- `GET /status/:challengeId` — remaining run budget.

### MCQ — `/mcq` (all auth)
- `POST /submit` — deterministic set-equality grading; the **only** place option
  correctness/explanations are revealed.

### i18n — `/i18n`
- `POST /translate` — **(public)** translate a batch of UI strings; globally cached. It
  is intentionally unauthenticated so guests on the landing/login pages localize too.

### Admin — `/admin` (ADMIN only)
A router-level guard applies `authenticate` + `authorize(ADMIN)` to the whole group.

- **Users:** `GET /users`, `POST /users`, `GET /users/:id`, `PUT /users/:id`,
  `DELETE /users/:id` (cannot delete self).
- **Ops:** `GET /jobs` (all users' curriculum jobs, filterable), `GET /metrics`
  (totals, breakdowns, 30-day series), `GET /users/:id/overview` (a per-user 360°).
- **Runtime settings:** `GET /settings`, `PUT /settings`, `DELETE /settings/:key`
  (Chapter 7).
- **The "god panel":** generic CRUD over every collection —
  `GET /resources`, `GET /data/:resource`, `POST /data/:resource`,
  `GET /data/:resource/:id`, `PATCH /data/:resource/:id`, `DELETE /data/:resource/:id`.
  It covers users, courses, lessons, challenges, submissions, progress, jobs, threads,
  messages, and actions, each with search/filter/sort/populate/cascade config.

> 💡 **Design Note — no public authoring API.** Notice what is *absent*: there is no
> `POST /courses`, no `POST /lessons`, no `POST /challenges` for end users. Content is
> created in exactly three ways — `/curriculum/request`, the course generate-more /
> generate-challenges endpoints, and the autonomous mentor tools (which call the same
> internal models). This is the API-level expression of the no-catalogue principle from
> Chapter 1. Do not add hand-authoring endpoints back.

## 5.4 Pagination, filtering, sorting

Admin list endpoints (and any paginated read) use `utils/queryBuilder.ts`:

- `getPagination(req, defaults)` — clamps `perPage` to a max (default 100).
- `getSort(req, allowedFields, defaults)` — whitelist-gated `?sort=field:asc|desc`.
- `getFilters(req, allowedFields)` — whitelisted equality filters.
- `getSearchQuery(req, fields)` — a case-insensitive `$or`/`$regex` search.
- `formatPaginationResponse(...)` — the standard `{ items, page, perPage, total }`.

The whitelisting is the security boundary: only fields a resource explicitly allows can
be filtered or sorted, so a client cannot probe arbitrary fields.

## 5.5 The error envelope in practice

When a controller throws or rejects, the global error handler in `app.ts` returns a
`500` JSend error with `err.message` in `details`. Controllers themselves return precise
codes for expected failures — `404 NOT_FOUND` for ownership misses, `409 CONFLICT` for
"course not READY," `503 AI_NOT_CONFIGURED` when no provider is set, `429 RATE_LIMITED`
when the AI provider itself rate-limits, and `429 MATH_RUN_LIMIT_EXHAUSTED` when a
learner exhausts their practice runs. Recognizing these codes is the fastest way to read
a failing request.

Next, Chapter 6 examines how a request proves who it is, and what the system trusts.
