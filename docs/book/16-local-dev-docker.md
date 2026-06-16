# Chapter 16 — Local Development & Docker

This chapter is the operator's guide to running SigmaLoop on one machine: the containers,
the ports, the multi-stage builds, and the exact startup sequence. It is also the baseline
against which Part V's AWS chapters measure "what changes in production."

## 16.1 The moving parts

A full local stack is four processes plus their datastores:

| Service | Port | How it runs locally |
|---------|------|---------------------|
| Frontend (SPA) | 5173 (Vite) / 80 (Nginx prod) | `npm run dev`, or the Nginx container |
| Backend API (+ in-process worker) | 4000 | `npm run dev`, or the API container |
| MongoDB | 27017 | Docker (or a shared external instance) |
| Judge0 server | 2358 | Docker Compose (privileged) |
| Judge0 workers / Postgres / Redis | internal | Docker Compose |

> 💡 **Design Note — the worker is *inside* the API locally.** There is no separate worker
> process in development. `server.ts` starts the curriculum worker in-process after Mongo
> connects. In production that loop is replaced by Step Functions + Lambda (Chapter 17),
> but locally it's one Node process doing both jobs — which is why a single `npm run dev`
> gives you a fully functional generation pipeline.

## 16.2 The Backend image — a four-stage build

`Backend/Dockerfile` is a multi-stage build on `node:20-alpine`:

1. **base** — `node:20-alpine`, `WORKDIR /app`.
2. **deps** — `npm ci --omit=dev --ignore-scripts` → production-only `node_modules`.
3. **build** — full `npm ci`, copy `src/` + `tsconfig.json`, `npm run build` (TS → `dist/`).
4. **production** — `NODE_ENV=production`, copy `node_modules` from *deps* and `dist` from
   *build*, `EXPOSE 4000`, `CMD ["node", "dist/server.js"]`.

The separation means the runtime image carries only production dependencies and compiled
JS — no TypeScript toolchain, no dev dependencies.

`Backend/docker-compose.yml` wires the API to MongoDB:

| Service | Image | Port | Notes |
|---------|-------|------|-------|
| `api` | `build: .` | 4000 | `DATABASE_URL=mongodb://mongo:27017/lambda_lap`, `depends_on: mongo (healthy)` |
| `mongo` | `mongo:7` | 27017 | volume `mongo_data`, healthcheck `db.adminCommand('ping')` |

> ⚠️ **Implementation Note — the legacy database name.** The Compose default DB is
> `lambda_lap` (and `JWT_SECRET` defaults to `dev-secret-change-me`). The product's
> documented default is `sigmaloop`. Either works locally; just be aware the name is a
> leftover from the pre-pivot era.

## 16.3 The Judge0 stack — and why it's special

`Backend/docker-compose.judge0.yml` brings up four services:

| Service | Image | Port | Privileged | Notes |
|---------|-------|------|------------|-------|
| `judge0-server` | `judge0/judge0:latest` | 2358 | **yes**, `cgroup: host` | mounts `/sys/fs/cgroup` |
| `judge0-workers` | `judge0/judge0:latest` | — | **yes**, `cgroup: host` | `COUNT=4` worker processes |
| `judge0-db` | `postgres:13-alpine` | — | — | volume `judge0-postgres-data` |
| `judge0-redis` | `redis:6-alpine` | — | — | Judge0's Resque queue |

Secrets come from `Backend/.env.judge0` (committed dev values:
`POSTGRES_PASSWORD=judge0password`, `REDIS_PASSWORD=judge0redispassword`).

> 💡 **Design Note — `privileged: true` + `cgroup: host` is the whole story.** Judge0 runs
> untrusted student code inside the `isolate` sandbox, which needs cgroups and elevated
> capabilities. That single requirement — visible right here in the Compose file — is why,
> in production, Judge0 cannot run on Fargate (no privileged mode) and is pinned to EC2
> while everything else goes serverless. Keep this file in mind through Chapters 17–18; it
> is the thread that ties the local stack to the cloud design.

## 16.4 The Frontend image — build, then Nginx

`Frontend/Dockerfile` is three stages: install deps (`npm ci`, full — Vite needs
devDeps), build (`npm run build` → `/app/dist`), then **production** on `nginx:alpine`
serving `/app/dist` on port 80 with the bundled `nginx.conf`.

`Frontend/nginx.conf`:

- **SPA fallback:** `try_files $uri $uri/ /index.html` so client-side routes resolve.
- **Asset caching:** hashed assets (`js|css|png|svg|woff2|…`) get `expires 1y;
  Cache-Control "public, immutable"`.
- **`index.html` is `no-cache`** so a new deploy is picked up immediately (Vite
  content-hashes every other asset, so immutable+1y is safe for them).

> ⚠️ **Implementation Note — Nginx does not proxy the API here.** The presentation diagram
> describes Nginx reverse-proxying API calls, but the committed `nginx.conf` does not — the
> SPA talks to the API by an absolute base URL. (And recall from Chapter 8 that the Axios
> client currently hard-codes that URL.) For a real single-origin deployment you'd add an
> API `location` block or front both with one edge.

## 16.5 The recommended startup sequence

The orchestration scripts (`setup.sh`, `lap.sh`) automate this, but the dependable manual
sequence is:

```bash
# 0. one-time: pull the nested repos and install
./setup.sh install
cp Backend/.env.example Backend/.env     # set DEEPSEEK_API_KEY (or GEMINI_API_KEY), JWT_SECRET
cp Frontend/.env.example Frontend/.env

# 1. MongoDB — reuse a shared local instance, or bring one up

# 2. Judge0 (privileged stack)
docker compose -p backend --env-file Backend/.env.judge0 -f Backend/docker-compose.judge0.yml up -d

# 3. API + in-process worker
cd Backend && npm run dev          # → http://localhost:4000/api/v1

# 4. Frontend
cd Frontend && npm run dev          # → http://localhost:5173
```

Health checks: the API liveness endpoint is `GET /api/v1/health`; Judge0's own is
`GET http://localhost:2358/about`.

> 💡 **Design Note — minimum viable AI config.** The system runs with **either** provider
> configured. If `AI_PROVIDER=deepseek` but no `DEEPSEEK_API_KEY` is set, it logs a warning
> and runs Gemini-only; if neither is set, generation endpoints return
> `503 AI_NOT_CONFIGURED` but the rest of the app works. So a contributor who only has a
> Gemini key (or no key at all) can still run and develop most of the platform.

## 16.6 Tests

Both repos ship test suites. Backend uses **Jest** (`npm test`) with suites for auth,
math grading, curriculum enqueue, execution, settings, AI fallback, AI routing, the Qwen
hint, streaks, and health. Frontend uses **Vitest** (`npm test`). The math suite is
especially worth reading — it asserts the full confidence matrix (confident-correct →
PASS, low-confidence → PENDING_REVIEW, run-limit 429, cross-user 404, completion only on a
confident pass), which is the executable specification of Chapter 14's grading rules.

With the local picture clear, Chapter 17 lifts the whole thing into AWS.
