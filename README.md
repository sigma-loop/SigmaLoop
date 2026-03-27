# SigmaLoop

**Master the Logic behind the Code** — A full-stack educational platform for learning programming with interactive code execution, courses, challenges, and AI mentorship.

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/sigma-loop/SigmaLoop.git
cd SigmaLoop

# 2. Pull Frontend & Backend repos + install dependencies
./setup.sh install

# 3. Set up environment variables
cp Backend/.env.example Backend/.env    # edit with your values
cp Frontend/.env.example Frontend/.env  # edit with your values

# 4. Start all services
./lap.sh start
```

## Repository Structure

This is the orchestration repo. Frontend and Backend live in their own repositories:

| Directory | Repository | Description |
|-----------|-----------|-------------|
| `Frontend/` | [sigma-loop/Frontend](https://github.com/sigma-loop/Frontend) | React 19 + TypeScript + Vite SPA |
| `Backend/` | [sigma-loop/Backend](https://github.com/sigma-loop/Backend) | Node.js + Express + TypeScript API (MongoDB) |

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

Services: `mongo`, `judge0`, `backend`, `frontend`, `all` (default)

## Tech Stack

- **Backend**: Node.js, Express v5, TypeScript, MongoDB/Mongoose, JWT auth
- **Frontend**: React 19, TypeScript, Vite, Tailwind CSS, Monaco Editor
- **Infrastructure**: Docker Compose (MongoDB, Judge0)

## Reference

The `Graduation Project/` directory contains the original design documents, API contract, database schema, and UI mockups. It is reference material only.
