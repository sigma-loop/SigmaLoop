# Appendix A — API Reference Tables

A compact, printable index of every endpoint. Full discussion is in Chapter 5. Base path
for all: **`/api/v1`**. "Auth" = a valid Bearer JWT required.

## Health & Auth

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/health` | — | liveness |
| POST | `/auth/register` | — | create STUDENT, return JWT + user |
| POST | `/auth/login` | — | verify credentials, return JWT + user |
| GET | `/auth/me` | ✅ | current profile + preferences + stats |

## Users

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/users/dashboard` | ✅ | aggregated dashboard |
| PUT | `/users/progress/:lessonId` | ✅ | set lesson completion |
| PATCH | `/users/profile` | ✅ | update name |
| PATCH | `/users/password` | ✅ | change password |
| PATCH | `/users/preferences` | ✅ | notifications / privacy / localization / learning |
| GET | `/users/export` | ✅ | export all user data |
| DELETE | `/users/me` | ✅ | delete account (password in body) |

## Chat (mentor)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/chat/guest` | optional | public, tool-less, stateless mentor |
| GET | `/chat/threads` | ✅ | list threads |
| POST | `/chat/threads` | ✅ | create thread (GENERAL/COURSE/LESSON) |
| POST | `/chat/threads/import` | ✅ | carry a guest transcript into a real thread |
| GET | `/chat/threads/:id/messages` | ✅ | list messages |
| POST | `/chat/threads/:id/messages` | ✅ | autonomous mentor turn → `actions[]` |
| PATCH | `/chat/threads/:id` | ✅ | rename |
| DELETE | `/chat/threads/:id` | ✅ | delete |

## Curriculum & Courses

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/curriculum/request` | ✅ | enqueue NEW_COURSE (prompt or goals) → **202** |
| POST | `/curriculum/questionnaire/next` | ✅ | AI follow-up questions |
| GET | `/curriculum/jobs` | ✅ | list jobs |
| GET | `/curriculum/jobs/:id` | ✅ | poll one job |
| GET | `/courses` | ✅ | list the user's courses |
| GET | `/courses/:id` | ✅ | read one course |
| GET | `/courses/:id/syllabus` | ✅ | course → lessons |
| POST | `/courses/:id/generate-more` | ✅ | EXTEND_COURSE job → **202** (409 if not READY) |
| POST | `/courses/:id/generate-challenges` | ✅ | GENERATE_CHALLENGES job → **202** |
| DELETE | `/courses/:id` | ✅ | delete course + descendants |

## Lessons & Challenges

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/lessons/:id` | ✅ | read lesson (challenges carry `passed`) |
| GET | `/lessons/course/:courseId` | ✅ | lessons of a course |
| POST | `/lessons/:id/generate` | ✅ | lazily materialize a STUB lesson |
| GET | `/lessons/:id/translation` | ✅ | read cached translation (no AI) |
| POST | `/lessons/:id/translate` | ✅ | on-demand AI translation (cached) |
| DELETE | `/lessons/:id` | ✅ | delete lesson + descendants |
| GET | `/challenges/:id` | ✅ | read one challenge (student-safe) |
| GET | `/challenges/lesson/:lessonId` | ✅ | challenges of a lesson |

## Grading

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/execution/run` | ✅ | run code vs public tests (no persist) |
| POST | `/execution/submit` | ✅ | run vs all tests → grade + progress |
| GET | `/execution/submissions` | ✅ | list programming submissions |
| POST | `/math/run` | ✅ | trial-grade LaTeX (decrements run limit) |
| POST | `/math/submit` | ✅ | final LLM grade; <0.7 → PENDING_REVIEW |
| GET | `/math/status/:challengeId` | ✅ | remaining run budget |
| POST | `/mcq/submit` | ✅ | deterministic set-equality grade (reveals answers) |

## i18n & Admin

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/i18n/translate` | — | translate UI strings (global cache) |
| GET/POST/PUT/DELETE | `/admin/users[...]` | ADMIN | user management |
| GET | `/admin/jobs` | ADMIN | all curriculum jobs |
| GET | `/admin/metrics` | ADMIN | platform metrics |
| GET | `/admin/users/:id/overview` | ADMIN | per-user 360° |
| GET/PUT/DELETE | `/admin/settings[/:key]` | ADMIN | runtime config overlay |
| GET | `/admin/resources` | ADMIN | collection catalogue |
| GET/POST/PATCH/DELETE | `/admin/data/:resource[/:id]` | ADMIN | generic CRUD ("god panel") |

## Common error codes

`UNAUTHORIZED`, `FORBIDDEN`, `INVALID_CREDENTIALS`, `VALIDATION_ERROR`, `MISSING_FIELD`,
`NOT_FOUND`, `ALREADY_EXISTS`, `CONFLICT`, `EXECUTION_ERROR`, `UNSUPPORTED_LANGUAGE`,
`AI_SERVICE_ERROR`, `AI_NOT_CONFIGURED`, `MATH_RUN_LIMIT_EXHAUSTED`,
`CHALLENGE_TYPE_MISMATCH`, `RATE_LIMITED`, `SERVICE_UNAVAILABLE`, `INTERNAL_ERROR`.
