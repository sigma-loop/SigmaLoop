# Lambda LAP — GitHub Copilot Instructions

## Project Overview

Lambda LAP (SigmaLoop) is a full-stack educational platform for learning programming with interactive code execution, courses, challenges, and AI mentorship.

## Repository Structure

| Folder | Purpose | Tech |
|--------|---------|------|
| `Backend/` | REST API server | Node.js, Express v5, TypeScript, MongoDB/Mongoose |
| `Frontend/` | Single-page app | React 19, TypeScript, Vite, Tailwind CSS |
| `Graduation Project/` | Design reference (read-only) | API contract, DB schema, UI mockups |

## Backend Conventions

- **Framework**: Express v5.2.1 with TypeScript strict mode
- **Database**: MongoDB with Mongoose v8.8.4
- **API Base**: `http://localhost:4000/api/v1`
- **Response Format**: JSend — always use `success(data)` and `error(message, code?, details?)` from `src/utils/jsend.ts`
- **Auth**: JWT with `authenticate` and `authorize(...roles)` middleware from `src/middlewares/auth.middleware.ts`
- **Roles**: STUDENT, INSTRUCTOR, ADMIN
- **Pattern**: Model → Controller → Route → Register in `src/routes/index.ts`
- **Style**: ESLint Standard + TypeScript, Prettier (single quotes, no trailing commas, 100 char width)

### Models
User, Course, Lesson, Challenge, Enrollment, LessonProgress, Submission, ChatThread, ChatMessage

### Key Imports
```typescript
// Response helpers
import { success, error } from '../utils/jsend';
// Auth middleware
import { authenticate, authorize } from '../middlewares/auth.middleware';
// Models
import { User, Course, Lesson, Challenge } from '../models';
```

## Frontend Conventions

- **Framework**: React 19.2.0 with TypeScript 5.9.3
- **Build**: Vite 7.2.4
- **Routing**: React Router DOM v7.10.1
- **HTTP**: Axios v1.13.2 (instance in `src/services/api.ts`, auto-attaches JWT)
- **State**: Context API via `AuthContext.tsx` — use `useAuth()` hook
- **Styling**: Tailwind CSS v4.1.17, custom utilities: `.glass-panel`, `.glass-card`, `.text-gradient`
- **Code Editor**: Monaco Editor (`@monaco-editor/react`)
- **Style**: ESLint recommended + TypeScript, Prettier (double quotes, trailing commas es5, 80 char width)

### Key Imports
```typescript
// Auth hook
import { useAuth } from '../contexts/AuthContext';
// API instance
import api from '../services/api';
// UI components
import { Button } from '../components/ui/Button';
import { Card } from '../components/ui/Card';
```

### Component Organization
- `src/components/ui/` — Reusable primitives (no business logic)
- `src/components/common/` — Shared components (Navbar, Footer)
- `src/components/layouts/` — Page layout wrappers
- `src/pages/<Name>/` — Page components with co-located sub-components

## Supported Languages (Challenges)

Python, C++, Java, JavaScript, TypeScript, Go, Rust

## Testing

- Backend: Jest + Supertest (`npm test` in Backend/)
- Frontend: Vitest + @testing-library/react (`npm test` in Frontend/)

## Important Notes

- Code execution endpoint returns mock results (sandbox not integrated)
- Rate limiting middleware exists but is disabled
- Frontend API URL is hardcoded in `src/services/api.ts`
- `Graduation Project/Backend/api.md` contains the full API contract v3.0
