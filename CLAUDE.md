# SigmaLoop — Project Root

## Product Vision

**SigmaLoop — "Master the Logic behind the Code"** is a **personalized AI tutor** for programming and mathematics. Every learner starts by talking to a mentor chatbot; the mentor deduces what they need; the system then generates a **personalized curriculum** (course → lessons → challenges → test cases / canonical solutions) tailored to that specific learner.

There are no instructor-authored courses, no public catalog, no contests. Every course, lesson, challenge, and test case in the system was produced by the AI generation pipeline for a specific user.

### Two Kinds of Challenges

| Kind | Authoring | Grading |
|---|---|---|
| **PROGRAMMING** | AI generates prompt + reference solution + test cases | Judge0 sandbox executes the user's code against the AI-generated test cases |
| **MATH** | AI generates problem (LaTeX) + canonical solution (LaTeX) + grading rubric | The user's LaTeX submission is sent to Gemini with the problem and canonical solution; Gemini returns a structured verdict |

This split is deliberate: programming grading stays deterministic (Judge0), and LLM judgement is confined to math equivalence — the place where deterministic grading is genuinely brittle.

## Repository Structure

```
SigmaLoop/
├── Backend/              # Node.js + Express + TypeScript API server (MongoDB)
│   ├── src/
│   │   ├── config/       # Environment config
│   │   ├── constants/    # Error codes, roles, supported languages, challenge kinds
│   │   ├── types/        # Shared TypeScript interfaces + Express augmentation
│   │   ├── controllers/  # Request handlers (auth, mentor chat, curriculum, execution, math)
│   │   ├── middlewares/  # Auth, rate limiting
│   │   ├── models/       # Mongoose schemas (see "Data Models")
│   │   ├── routes/       # Express route definitions
│   │   ├── services/     # AI service layer (DeepSeek primary + Gemini fallback) — chat, generation, math grading
│   │   ├── utils/        # JSend helpers, query builder, DB connection, Judge0 mapper
│   │   ├── scripts/      # Database seeding (for dev only)
│   │   └── __tests__/    # Jest tests
│   ├── Dockerfile        # Multi-stage Docker build
│   ├── docker-compose.yml       # API + MongoDB local stack
│   └── docker-compose.judge0.yml  # Judge0 code execution engine stack
├── Frontend/             # React 19 + TypeScript + Vite SPA client
│   ├── src/
│   │   ├── components/   # common/ (Navbar, ErrorBoundary, Skeletons), ui/, layouts/
│   │   ├── constants/    # API URL, roles, languages, route paths
│   │   ├── contexts/     # AuthContext (global auth state)
│   │   ├── hooks/        # useDebounce, useLocalStorage, useClickOutside
│   │   ├── utils/        # cn() class merge, formatters (date, number, string)
│   │   ├── pages/        # Mentor (entry point), MyCourses, Lesson, Auth, Admin
│   │   ├── services/     # Axios API client + service modules
│   │   └── types/        # API response interfaces
│   ├── Dockerfile        # Multi-stage Docker build (nginx)
│   └── nginx.conf        # SPA routing + static asset caching
├── Hosting Judge/        # AWS hosting proposal — Repovive (reference)
├── Hosting SigmaLoop/    # AWS hosting proposal — SigmaLoop (this repo's hosting plan)
├── Graduation Project/   # Original design docs (reference material only)
└── CLAUDE.md             # This file
```

## Architecture

- **Backend**: REST API at `http://localhost:4000/api/v1` using JSend response format.
- **Frontend**: SPA at `http://localhost:5173` (Vite dev server), Axios to the API.
- **Database**: MongoDB with Mongoose ODM.
- **Auth**: JWT-based with Bearer tokens, two roles: **STUDENT, ADMIN**.
- **AI**: **DeepSeek is the primary model** (OpenAI-compatible API), with **Google Gemini 2.5 Flash as an automatic fallback** for mentor chat, async curriculum generation, and math grading. The active provider is set by `AI_PROVIDER` (default `deepseek`). All calls go through a single `AIClient` interface (`FallbackAIClient` composes primary → fallback), so the provider is swappable. When `AI_PROVIDER=deepseek` but `DEEPSEEK_API_KEY` is unset, the system runs on Gemini only.
- **Code execution**: Judge0 CE sandbox (Docker, port 2358) for programming challenges. Test cases are AI-generated and run via `POST /submissions?wait=true`.
- **Async generation pipeline**: A curriculum request from the mentor chat enqueues a `CurriculumJob`; a worker processes it and writes `Course`, `Lesson`, `Challenge` documents. The chat is non-blocking — the user is notified when the curriculum is ready.

## Key Conventions

### Response Format (JSend)
All API responses follow JSend:
```json
// Success
{ "success": true, "data": { ... } }
// Error
{ "success": false, "message": "...", "code": "ERROR_CODE", "details": "..." }
```

### TypeScript
- Both Backend and Frontend use strict TypeScript.
- Backend: CommonJS output (ES2020+).
- Frontend: ESM with Vite.

### Code Style
- **Backend**: ESLint Standard + TypeScript, Prettier (single quotes, no trailing commas, 100 char width).
- **Frontend**: ESLint recommended + TypeScript, Prettier (double quotes, trailing commas es5, 80 char width).
- Both use Husky pre-commit hooks for lint-staged.

### Naming Conventions
- Files: `camelCase.ts` for utils, `PascalCase.tsx` for React components.
- Backend models: `PascalCase.ts` (e.g., `User.ts`, `Course.ts`).
- Routes: `kebab-case.routes.ts` (e.g., `auth.routes.ts`).
- Controllers: `kebab-case.controller.ts`.

## Quick Commands

### Backend
```bash
cd Backend
npm run dev          # Start dev server (nodemon + ts-node)
npm run build        # Compile TypeScript to dist/
npm start            # Run production build
npm test             # Run Jest tests
npm run seed         # Seed a sample STUDENT user (no manual content)
npm run lint:fix     # Fix linting issues
```

### Frontend
```bash
cd Frontend
npm run dev          # Start Vite dev server
npm run build        # Type-check + build
npm test             # Run Vitest tests
npm run lint         # Run ESLint
npm run format       # Run Prettier
```

## Data Models

Every course in SigmaLoop is owned by one user — the learner it was generated for. There is no shared catalog.

| Model | Purpose | Key Relations |
|-------|---------|---------------|
| User | Account with role STUDENT \| ADMIN and stats | - |
| ChatThread | Mentor-chat container, scoped GENERAL \| COURSE \| LESSON | Belongs to User |
| ChatMessage | Messages in threads (USER or ASSISTANT) | Belongs to ChatThread |
| CurriculumJob | Tracks an async curriculum-generation job | Triggered by ChatThread, owned by User |
| Course | Personalized course (status: PENDING / GENERATING / READY / FAILED) | Owned by User, produced by a CurriculumJob |
| Lesson | Generated lesson (markdown body) | Belongs to Course |
| Challenge | Generated challenge with `kind: 'PROGRAMMING' \| 'MATH'` | Belongs to Lesson |
| Submission | A user's attempt at a Challenge (polymorphic by kind) | User + Challenge |
| LessonProgress | Lesson completion state | User + Lesson (unique pair) |

### Challenge — Discriminated Shape

```ts
type Challenge =
  | {
      kind: 'PROGRAMMING'
      prompt: string                 // markdown
      starterCode: Record<Lang, string>
      referenceSolution: { language: Lang; code: string }
      testcases: TestCase[]          // stdin / expectedStdout pairs
    }
  | {
      kind: 'MATH'
      problemLatex: string           // LaTeX problem statement
      canonicalSolutionLatex: string
      gradingRubric: string          // natural-language rubric for the LLM grader
    }
```

`Submission` mirrors the same split: a programming submission carries source code and per-testcase verdicts; a math submission carries the student's LaTeX and the LLM grader's structured verdict (`correct`, `equivalentForm`, `rationale`, `confidence`).

## API Endpoint Groups

| Group | Base Path | Auth Required | Notes |
|-------|-----------|---------------|-------|
| Health | `/api/v1/health` | No | Liveness only |
| Auth | `/api/v1/auth` | No (register/login) | JWT issuance |
| Users | `/api/v1/users` | Yes | Profile, stats |
| Chat | `/api/v1/chat` | Yes | Mentor chat threads & messages |
| Curriculum | `/api/v1/curriculum` | Yes | Request generation, poll job status |
| Courses | `/api/v1/courses` | Yes | List **the current user's** courses |
| Lessons | `/api/v1/lessons` | Yes | Read a lesson (only if owned by user) |
| Challenges | `/api/v1/challenges` | Yes | Read a challenge (only if owned by user) |
| Execution | `/api/v1/execution` | Yes | Run / submit PROGRAMMING challenges |
| Math | `/api/v1/math` | Yes | Submit MATH challenges (LaTeX → LLM verdict) |
| Admin | `/api/v1/admin` | ADMIN only | User management, ops |

Note: there is **no** instructor-facing CRUD for courses/lessons/challenges. All content is generated through the curriculum pipeline.

## Environment Setup

Backend requires a `.env` file (see `Backend/.env.example`):
```
PORT=4000
DATABASE_URL=mongodb://localhost:27017/sigmaloop
JWT_SECRET=<your-secret>
JWT_EXPIRES_IN=7d
NODE_ENV=development
AI_PROVIDER=deepseek                     # 'deepseek' (default) or 'gemini'
DEEPSEEK_API_KEY=<your-deepseek-api-key> # primary model
GEMINI_API_KEY=<your-gemini-api-key>     # automatic fallback (Gemini 2.5 Flash)
JUDGE0_DASHBOARD=http://localhost:2358
```

Frontend requires a `.env` file (see `Frontend/.env.example`):
```
VITE_API_BASE_URL=http://localhost:4000/api/v1
```

The constant `API_BASE_URL` in `Frontend/src/constants/index.ts` reads from `import.meta.env.VITE_API_BASE_URL` with a fallback to `http://localhost:4000/api/v1`.

### Docker (Full Stack)
```bash
cd Backend && docker-compose up                                    # API + MongoDB
cd Backend && docker-compose -f docker-compose.judge0.yml up       # Judge0
cd Frontend && docker build -t sigmaloop-frontend .                # Nginx-served SPA
```

## Important Notes for Agents

1. **There is no manual authoring path.** Do not add or restore endpoints for creating courses, lessons, or challenges by hand. Generation goes through `/curriculum/request`.
2. **Two roles only: STUDENT and ADMIN.** Any reference to an INSTRUCTOR role in older code or docs is stale — remove it.
3. **Challenges are discriminated by `kind`.** Both controllers and frontend rendering should branch on `kind` rather than assuming programming.
4. **Programming grading uses Judge0** — `Backend/src/controllers/execution.controller.ts` runs AI-generated test cases. Each test case is submitted via `POST /submissions?wait=true` and results are aggregated.
5. **Math grading uses the active AI provider** — `Backend/src/services/ai.service.ts` includes a `gradeMath(problem, canonical, studentLatex)` function (DeepSeek primary, Gemini fallback) that returns a structured verdict. Low-confidence verdicts (`confidence < 0.7`) are surfaced as "pending review" in the UI rather than auto-graded.
6. **Curriculum generation is asynchronous.** A request creates a `CurriculumJob` and returns immediately. The actual generation runs in a worker (local: a separate Node process; production: Step Functions + Lambda, see `Hosting SigmaLoop/README.md`).
7. **AI access is wrapped in an `AIClient` interface.** DeepSeek is primary and Gemini is the automatic fallback (`FallbackAIClient`). Do not import `@google/generative-ai` or call any model API directly in controllers — go through the service layer so we can swap providers (e.g., to Bedrock) without touching business logic.
8. **Supported languages for PROGRAMMING challenges**: Python, C++, Java, JavaScript, TypeScript, Go, Rust.
9. **Frontend uses Monaco Editor** for PROGRAMMING challenges and a **LaTeX input with KaTeX preview** for MATH challenges. The Lesson page branches on `challenge.kind`.
10. **Frontend uses Tailwind CSS** with glass morphism design (`.glass-panel`, `.glass-card`).
11. **Graduation Project folder is reference material** — the original design documents from the academic submission. Do not modify; treat as historical context. The product has since evolved into the personalized-tutor vision described above.
12. **Hosting plan**: see `Hosting SigmaLoop/README.md` for the AWS deployment proposal, including the async generation pipeline (EventBridge + Step Functions + Lambda) and math-grader Lambda.
