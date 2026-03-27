# Lambda LAP - Project Root

## Project Overview

Lambda LAP (Learning and Practice) is a full-stack educational platform for learning programming. It features interactive code execution, course management, AI-powered mentorship, and a challenge system with automated grading.

**Brand Name:** SigmaLoop — "Master the Logic behind the Code"

## Repository Structure

```
LambdaLAP/
├── Backend/              # Node.js + Express + TypeScript API server (MongoDB)
│   ├── src/
│   │   ├── config/       # Environment config
│   │   ├── constants/    # Error codes, roles, supported languages
│   │   ├── types/        # Shared TypeScript interfaces + Express augmentation
│   │   ├── controllers/  # Request handlers
│   │   ├── middlewares/  # Auth, rate limiting
│   │   ├── models/       # Mongoose schemas (9 collections)
│   │   ├── routes/       # Express route definitions
│   │   ├── utils/        # JSend helpers, query builder, DB connection
│   │   ├── scripts/      # Database seeding
│   │   └── __tests__/    # Jest tests
│   ├── Dockerfile        # Multi-stage Docker build
│   └── docker-compose.yml  # API + MongoDB local stack
├── Frontend/             # React 19 + TypeScript + Vite SPA client
│   ├── src/
│   │   ├── components/   # common/ (Navbar, ErrorBoundary, Skeletons), ui/, layouts/
│   │   ├── constants/    # API URL, roles, languages, route paths
│   │   ├── contexts/     # AuthContext (global auth state)
│   │   ├── hooks/        # useDebounce, useLocalStorage, useClickOutside
│   │   ├── utils/        # cn() class merge, formatters (date, number, string)
│   │   ├── pages/        # Page components by feature
│   │   ├── services/     # Axios API client + service modules
│   │   └── types/        # API response interfaces
│   ├── Dockerfile        # Multi-stage Docker build (nginx)
│   └── nginx.conf        # SPA routing + static asset caching
├── Graduation Project/   # Design docs, UI mockups, Next.js prototype, API contract
├── .editorconfig         # Editor settings (shared)
├── .cursorrules          # Cursor AI context
├── .windsurfrules        # Windsurf AI context
├── .clinerules           # Cline AI context
├── .aider.conf.yml       # Aider AI config
├── .github/copilot-instructions.md  # GitHub Copilot context
└── CLAUDE.md             # This file
```

## Architecture

- **Backend**: REST API at `http://localhost:4000/api/v1` using JSend response format
- **Frontend**: SPA at `http://localhost:5173` (Vite dev server), communicates via Axios
- **Database**: MongoDB with Mongoose ODM
- **Auth**: JWT-based with Bearer tokens, 3 roles: STUDENT, INSTRUCTOR, ADMIN

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
- Both Backend and Frontend use strict TypeScript
- Backend: CommonJS output (ES2020+)
- Frontend: ESM with Vite

### Code Style
- **Backend**: ESLint Standard + TypeScript, Prettier (single quotes, no trailing commas, 100 char width)
- **Frontend**: ESLint recommended + TypeScript, Prettier (double quotes, trailing commas es5, 80 char width)
- Both use Husky pre-commit hooks for lint-staged

### Naming Conventions
- Files: `camelCase.ts` for utils, `PascalCase.tsx` for React components
- Backend models: `PascalCase.ts` (e.g., `User.ts`, `Course.ts`)
- Routes: `kebab-case.routes.ts` (e.g., `auth.routes.ts`)
- Controllers: `kebab-case.controller.ts`

## Quick Commands

### Backend
```bash
cd Backend
npm run dev          # Start dev server (nodemon + ts-node)
npm run build        # Compile TypeScript to dist/
npm start            # Run production build
npm test             # Run Jest tests
npm run seed         # Seed database with sample data
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

## Data Models (9 Collections)

| Model | Purpose | Key Relations |
|-------|---------|---------------|
| User | Accounts with roles & stats | - |
| Course | Learning courses | Has many Lessons |
| Lesson | Course content (markdown) | Belongs to Course, has Challenges |
| Challenge | Coding challenges | Belongs to Lesson |
| Enrollment | User-Course join | User + Course (unique pair) |
| LessonProgress | Lesson completion tracking | User + Lesson (unique pair) |
| Submission | Code submissions | User + Challenge |
| ChatThread | AI chat containers | Belongs to User |
| ChatMessage | Messages in threads | Belongs to ChatThread |

## API Endpoint Groups

| Group | Base Path | Auth Required |
|-------|-----------|---------------|
| Health | `/api/v1/health` | No |
| Auth | `/api/v1/auth` | No (register/login) |
| Users | `/api/v1/users` | Yes |
| Courses | `/api/v1/courses` | Mixed (public list, protected CRUD) |
| Lessons | `/api/v1/lessons` | Mixed |
| Challenges | `/api/v1/challenges` | Mixed |
| Execution | `/api/v1/execution` | Mixed (run=public, submit=auth) |

## Environment Setup

Backend requires a `.env` file (see `Backend/.env.example`):
```
PORT=4000
DATABASE_URL=mongodb://localhost:27017/lambda_lap
JWT_SECRET=<your-secret>
JWT_EXPIRES_IN=7d
NODE_ENV=development
```

Frontend requires a `.env` file (see `Frontend/.env.example`):
```
VITE_API_BASE_URL=http://localhost:4000/api/v1
```

The constant `API_BASE_URL` in `Frontend/src/constants/index.ts` reads from `import.meta.env.VITE_API_BASE_URL` with a fallback to `http://localhost:4000/api/v1`.

### Docker (Full Stack)
```bash
cd Backend && docker-compose up    # API + MongoDB
cd Frontend && docker build -t lambda-lap-frontend .  # Nginx-served SPA
```

## Important Notes for Agents

1. **Code execution is a dummy** — `Backend/src/controllers/execution.controller.ts` returns mock results (70% pass rate). Real sandbox integration is pending.
2. **Rate limiting is disabled** — Middleware exists but all limiters are pass-through in `Backend/src/middlewares/rateLimit.middleware.ts`.
3. **Graduation Project folder is reference material** — Contains the original design docs, API contract (v3.0), database schema (PDF), UI mockups (PNG), and a Next.js prototype. Do NOT modify this folder for implementation work; use it as a design reference.
4. **The Next.js prototype in Graduation Project is separate** — The actual implementation is in `Frontend/` (React + Vite), not the Next.js prototype.
5. **Supported languages for challenges**: Python, C++, Java, JavaScript, TypeScript, Go, Rust.
6. **Frontend uses Monaco Editor** for the code editing experience.
7. **Frontend uses Tailwind CSS** with glass morphism design (`.glass-panel`, `.glass-card`).
