# SigmaLoop

**Master the Logic behind the Code** — a **personalized AI tutor** for programming and mathematics. Talk to the mentor chatbot; it deduces what you need to learn; it generates a course, lessons, and challenges built specifically for you. Programming work is graded by a sandbox; math work is graded by an LLM that compares your LaTeX answer against a canonical solution.

There are no instructor-authored courses, no public catalog, no contests. Every learner gets their own curriculum.

## How It Works

1. **Talk to the mentor.** The mentor chat (Gemini-backed, scoped to your conversation) deduces your level, prerequisites, and what you actually want to learn.
2. **Get a curriculum.** When you ask — or when the mentor decides you're ready — the system generates a personalized course end-to-end: lessons, programming challenges with test cases, math problems with canonical solutions.
3. **Solve & learn.**
   - **Programming challenges** run in a Judge0 sandbox against AI-generated test cases.
   - **Math challenges** accept LaTeX; an LLM judges your answer against the canonical solution.

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/sigma-loop/SigmaLoop.git
cd SigmaLoop

# 2. Pull Frontend & Backend repos + install dependencies
./setup.sh install

# 3. Set up environment variables
cp Backend/.env.example Backend/.env    # add GEMINI_API_KEY, JWT_SECRET
cp Frontend/.env.example Frontend/.env

# 4. Start all services
./lap.sh start
```

## Repository Structure

This is the orchestration repo. Frontend and Backend live in their own repositories:

| Directory | Repository | Description |
|-----------|-----------|-------------|
| `Frontend/` | [sigma-loop/Frontend](https://github.com/sigma-loop/Frontend) | React 19 + TypeScript + Vite SPA |
| `Backend/` | [sigma-loop/Backend](https://github.com/sigma-loop/Backend) | Node.js + Express + TypeScript API (MongoDB) |
| `Hosting SigmaLoop/` | — | AWS hosting proposal for the platform |
| `Graduation Project/` | — | Original design documents (reference only) |

## Scripts

### `setup.sh` — Repository Management

```bash
./setup.sh              # Clone missing repos, pull existing ones
./setup.sh clone        # Force fresh clone (removes existing)
./setup.sh pull         # Pull latest changes
./setup.sh install      # Clone/pull + npm install
```

### `lap.sh` — Service Manager

```bash
./lap.sh start                  # Start all services
./lap.sh stop                   # Stop all services
./lap.sh restart backend        # Restart a specific service
./lap.sh status                 # Show what's running
./lap.sh logs backend           # Tail service logs
```

Services: `mongo`, `judge0`, `backend`, `frontend`, `all` (default).

## Tech Stack

- **Backend**: Node.js, Express v5, TypeScript, MongoDB/Mongoose, JWT auth
- **Frontend**: React 19, TypeScript, Vite, Tailwind CSS, Monaco Editor, KaTeX
- **AI**: Google Gemini (`@google/generative-ai`) — mentor chat, async curriculum generation, math grading. Wrapped in a swappable `AIClient` interface.
- **Code execution**: Judge0 CE (Postgres + Redis + Judge0 server/workers) — runs AI-generated test cases for PROGRAMMING challenges.
- **Roles**: STUDENT and ADMIN. There is no INSTRUCTOR role.
- **Infrastructure**: Docker Compose locally; AWS (ECS Fargate + Judge0 on EC2 + DocumentDB + S3 + Step Functions) in production — see `Hosting SigmaLoop/README.md`.

## Reference

- `Graduation Project/` contains the original academic design documents, API contract, schema PDFs, and UI mockups. The product has since pivoted to the AI-tutor vision described above; treat that folder as historical context.
- `Hosting SigmaLoop/README.md` is the SAA-style AWS deployment proposal.
- `architecture-diagram-spec.md` is the diagram specification used for the university presentation.
