# Chapter 3 — Codebase Tour

This chapter is a map of the source tree: enough to know where to look for anything in
the rest of the book. It is descriptive, not exhaustive — the deep dives live in their
own chapters.

## 3.1 The monorepo, and the repos inside it

The top-level `SigmaLoop/` directory is an **orchestration repository**. The two
applications, `Frontend/` and `Backend/`, are themselves separate git repositories
nested inside it, each with its own history, `package.json`, lint rules, and Husky
hooks. The root holds the glue: orchestration scripts, hosting proposals, the academic
reference material, and this `docs/` book.

```
SigmaLoop/
├── Backend/                  # Node.js + Express + TypeScript API (its own git repo)
├── Frontend/                 # React 19 + TypeScript + Vite SPA (its own git repo)
├── Hosting SigmaLoop/        # AWS deployment proposal for this product
├── Hosting Judge/            # Repovive/Judge0 AWS migration — reference design
├── Graduation Project/       # Original academic design docs (historical reference)
├── docs/                     # ← this book
├── architecture-diagram-spec.md   # the presentation diagram spec
├── README.md                 # repo orchestration readme
├── setup.sh                  # clone/pull + install the nested repos
├── lap.sh                    # local service manager (mongo/judge0/backend/frontend)
└── CLAUDE.md                 # agent-facing project instructions (the source of truth)
```

The two orchestration scripts are worth knowing:

- **`setup.sh`** clones or pulls the `Frontend` and `Backend` repos and installs their
  dependencies (`./setup.sh install`).
- **`lap.sh`** is a service manager: `./lap.sh start|stop|status|logs <service>`, where
  a service is `mongo`, `judge0`, `backend`, `frontend`, or `all`. It runs Mongo and
  Judge0 via Docker Compose and the apps via `npm run dev` as host processes.

> ⚠️ **Implementation Note — the real dev workflow differs slightly.** In practice the
> team reuses a shared external Mongo and starts the API + Frontend with `npm run dev`
> directly, bringing up only Judge0 via Compose. Chapter 16 documents the exact,
> tested startup sequence. Treat `lap.sh` as the convenient default, not the only path.

## 3.2 The Backend tree

```
Backend/src/
├── app.ts                 # Express app: CORS, body parsing, logging, routes, errors
├── server.ts              # boot: connect Mongo → load settings → start worker → listen
├── config/
│   ├── index.ts           # the env-derived `config` object (the live singleton)
│   └── settingsRegistry.ts# KEY → config-path map for the admin runtime settings
├── constants/             # errorCodes, roles, languages (programming), locales, challengeKinds
├── types/                 # shared interfaces + Express request augmentation
├── middlewares/
│   ├── auth.middleware.ts # authenticate / optionalAuthenticate / authorize
│   └── rateLimit.middleware.ts  # (currently pass-through — see Ch 6)
├── models/                # Mongoose schemas — the domain model (Ch 4)
├── controllers/           # one per route group — request handlers
├── routes/                # kebab-case.routes.ts — endpoint definitions (Ch 5)
├── services/              # the brains:
│   ├── ai.service.ts          # AIClient, DeepSeek + Gemini, all generation prompts
│   ├── curriculumWorker.ts    # the async generation worker (Ch 12)
│   ├── mentorTools.ts         # the autonomous mentor's tool registry (Ch 13)
│   ├── qwenHint.service.ts    # the fine-tuned lesson-hint model (Ch 13)
│   ├── judge0.service.ts      # the Judge0 HTTP wrapper (Ch 14)
│   ├── progress.service.ts    # lesson completion + streaks (Ch 14)
│   └── settings.service.ts    # the runtime config overlay (Ch 7)
├── utils/                 # jsend, challengeSerializer, queryBuilder, judge0-mapper, db
├── scripts/seed.ts        # dev seeding (a sample STUDENT user; no content)
└── __tests__/             # Jest suites (auth, math, curriculum, execution, settings, …)
```

A useful mental model: **routes** are thin and just wire middleware to controllers;
**controllers** validate input, enforce ownership, and orchestrate; **services** hold the
real work (AI calls, the worker loop, Judge0, grading, progress); **models** are the
Mongoose schemas; **utils** are pure helpers.

### Key backend files, by chapter

| You want… | Look at | Chapter |
|-----------|---------|---------|
| The data shapes | `models/*.ts` | 4 |
| Every endpoint | `routes/*.ts` + `controllers/*.ts` | 5 |
| Auth & roles | `middlewares/auth.middleware.ts`, `constants/roles.ts` | 6 |
| Runtime config | `config/index.ts`, `config/settingsRegistry.ts`, `services/settings.service.ts` | 7 |
| The AI provider | `services/ai.service.ts` | 11 |
| Generation | `services/curriculumWorker.ts`, `models/CurriculumJob.ts` | 12 |
| The mentor | `controllers/chat.controller.ts`, `services/mentorTools.ts` | 13 |
| Grading | `controllers/{execution,math,mcq}.controller.ts`, `services/{judge0,progress}.service.ts` | 14 |
| Translation | `controllers/i18n.controller.ts`, `controllers/lesson.controller.ts`, `models/{Ui,Lesson}Translation.ts` | 15 |

## 3.3 The Frontend tree

```
Frontend/src/
├── main.tsx               # createRoot → HelmetProvider → App
├── App.tsx                # provider tree + all routes
├── constants/             # API URL, route paths, topicLibrary, locales, adminResources
├── contexts/
│   ├── AuthContext.tsx    # session, token, login/logout
│   ├── LocaleContext.tsx  # the on-demand i18n engine (Ch 15)
│   ├── ThemeContext.tsx   # light/dark
│   └── ConfirmContext.tsx # promise-based confirm()/alert()
├── hooks/                 # useCurriculumJob, useDebounce, useLocalStorage, useClickOutside
├── services/              # Axios client (api.ts) + one module per API group
├── i18n/registry.ts       # the module-level Set of strings to translate (Ch 15)
├── components/
│   ├── common/            # Navbar, Footer, ErrorBoundary, skeletons, LanguageSwitcher
│   ├── ui/                # Button, Card, Input, Badge, ConfirmDialog, …
│   ├── chat/              # ChatWidget, GuestChat, MessageContent
│   └── layouts/           # MainLayout, AuthLayout, LessonLayout, AdminLayout
├── pages/
│   ├── Mentor/            # the entry point
│   ├── Onboarding/        # the questionnaire wizard
│   ├── MyCourses/, Course/, Dashboard/, Settings/, Auth/, Home/, Legal/
│   ├── Lesson/            # LessonView + components/ (the challenge workspaces, Ch 9)
│   └── Admin/             # CommandCenter, Explorer, Settings, UserOverview
└── types/api.ts           # every API response interface
```

The richest corner is `pages/Lesson/components/` — it holds the three challenge
workspaces (`ProgrammingWorkspace`, `MathWorkspace`, `MCQWorkspace`), their editors
(`CodeEditor` for Monaco, `MathEditor` for MathLive), the output panels, and
`ChallengeTabs`. That subtree is Chapter 9.

> ⚠️ **Implementation Note — legacy names in the Frontend.** The Frontend's
> `package.json` is still named `lambda-lap-frontend`, and a few Admin files
> (`AdminDashboard.tsx`, `AdminUsers.tsx`, `AdminJobs.tsx`) exist on disk but are not
> routed — they were superseded by the CommandCenter + Explorer. These are noted again
> in Chapter 8.

## 3.4 Documentation & reference material

- **`CLAUDE.md`** (root, and one each in `Backend/` and `Frontend/`) — the canonical,
  agent-facing description of the product and its conventions. When this book and the
  code disagree, `CLAUDE.md` is usually the intended truth; when `CLAUDE.md` and the
  *running code* disagree, the book flags it.
- **`Frontend/DESIGN_SYSTEM.md`** — the visual language (Chapter 10).
- **`architecture-diagram-spec.md`** — the presentation diagram spec (excerpted in
  Chapter 2).
- **`Hosting SigmaLoop/`** — the AWS deployment proposal (Chapters 17–19), including
  `own-model-aws-deployment.md` for the self-hosted fine-tuned model.
- **`Hosting Judge/`** — a *separate product's* Judge0 AWS migration (Repovive), kept as
  a reference design. Chapter 17 explains why it's here and how it differs.
- **`Graduation Project/`** — the original academic submission. Historical; do not treat
  as current.

## 3.5 Conventions you'll see repeatedly

- **Backend** is ESLint Standard + TypeScript, Prettier with **single quotes, no
  trailing commas, 100-char** width, CommonJS output (ES2020+).
- **Frontend** is ESLint recommended + TypeScript, Prettier with **double quotes,
  trailing commas (es5), 80-char** width, ESM via Vite.
- **Naming:** `camelCase.ts` for utils, `PascalCase.tsx` for React components and
  Mongoose models; routes are `kebab-case.routes.ts`; controllers
  `kebab-case.controller.ts`.
- Both repos use **Husky** pre-commit hooks with lint-staged.

With the map in hand, we descend into the building blocks. Part II begins with the
domain model.
