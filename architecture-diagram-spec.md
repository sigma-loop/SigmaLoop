# SigmaLoop System Architecture — Diagram Specification

Use this document to generate a system architecture diagram for the university presentation.

SigmaLoop is a **personalized AI tutor** for programming and mathematics. The mentor chat is the entry point; an async pipeline generates a per-user curriculum; PROGRAMMING challenges are graded by Judge0; MATH challenges are graded by an LLM that compares the student's LaTeX against a canonical solution.

---

## DIAGRAM LAYOUT (Top to Bottom, 4 Layers)

```
=======================================================================
LAYER 1: CLIENT LAYER (Top)
=======================================================================

  +---------------------------------------------------------+
  |              USER'S BROWSER / DEVICE                     |
  |                                                          |
  |  +-------------------+  +------------------------+       |
  |  | React 19 SPA      |  | Mentor Chat            |       |
  |  | (TypeScript +Vite)|  | (primary entry point)  |       |
  |  +-------------------+  +------------------------+       |
  |                                                          |
  |  +-------------------+  +------------------------+       |
  |  | Monaco Editor     |  | LaTeX Input + KaTeX    |       |
  |  | (PROGRAMMING)     |  | Preview (MATH)         |       |
  |  +-------------------+  +------------------------+       |
  |                                                          |
  |  +-------------------+  +------------------------+       |
  |  | Tailwind / Glass  |  | Auth Context (JWT      |       |
  |  | UI                |  | in localStorage)       |       |
  |  +-------------------+  +------------------------+       |
  +---------------------------------------------------------+
              |
              | HTTPS / REST API (JSend JSON)
              | Authorization: Bearer <JWT>
              v

=======================================================================
LAYER 2: WEB SERVER / REVERSE PROXY
=======================================================================

  +---------------------------------------------------------+
  |              NGINX (Production)                          |
  |  - Serves static frontend files (HTML/JS/CSS)            |
  |  - SPA routing (all paths -> index.html)                 |
  |  - Asset caching (1 year for static files)               |
  |  - Reverse proxy API requests to backend                 |
  +---------------------------------------------------------+
              |
              | HTTP (port 80 -> port 4000)
              v

=======================================================================
LAYER 3: APPLICATION SERVER (Middle)
=======================================================================

  +---------------------------------------------------------+
  |              NODE.JS + EXPRESS (TypeScript)              |
  |              Port 4000 — /api/v1/*                       |
  |                                                          |
  |  MIDDLEWARE PIPELINE:                                    |
  |  +----------+  +-----------+  +--------+  +---------+    |
  |  |   CORS   |->| Body      |->|  Auth  |->| Request |    |
  |  |  Filter  |  | Parser    |  | (JWT)  |  | Logger  |    |
  |  +----------+  +-----------+  +--------+  +---------+    |
  |                                                          |
  |  ROUTE HANDLERS:                                         |
  |  +-----------------------------------------------------+ |
  |  | /auth         - Register, Login, Profile            | |
  |  | /users        - User account                        | |
  |  | /chat         - Mentor chat threads & messages      | |
  |  | /curriculum   - Request generation, poll job status | |
  |  | /courses      - READ-ONLY: list user's courses      | |
  |  | /lessons      - READ-ONLY                           | |
  |  | /challenges   - READ-ONLY                           | |
  |  | /execution    - PROGRAMMING: run + submit (Judge0)  | |
  |  | /math         - MATH: submit LaTeX -> LLM grader    | |
  |  | /admin        - ADMIN-only ops                      | |
  |  +-----------------------------------------------------+ |
  |                                                          |
  |  SERVICES:                                               |
  |  +-----------------+  +--------------------+             |
  |  | Auth Service    |  | AI Service         |             |
  |  | (bcrypt + JWT)  |  | (AIClient -> Gemini)|            |
  |  +-----------------+  +--------------------+             |
  |  +-----------------------+  +--------------------+       |
  |  | Curriculum Worker     |  | Judge0 Service     |       |
  |  | (drains job queue,    |  | (HTTP wrapper)     |       |
  |  | runs async generation)|  |                    |       |
  |  +-----------------------+  +--------------------+       |
  +---------------------------------------------------------+
         |                    |                    |
         v                    v                    v

=======================================================================
LAYER 4: EXTERNAL SERVICES & DATA (Bottom)
=======================================================================

+----------------+    +------------------+    +--------------------+
|   MongoDB 7    |    | Google Gemini    |    | Judge0 CE          |
|   Database     |    | AI API           |    | Code Execution     |
|                |    |                  |    | Engine             |
| 9 Collections: |    | Model:           |    |                    |
| - User         |    |  gemini-2.5-flash|    | +----------------+ |
|   (STUDENT|    |    |                  |    | | Judge0 Server  | |
|    ADMIN)      |    | Features:        |    | | (port 2358)    | |
| - ChatThread   |    | - Mentor chat    |    | +----------------+ |
| - ChatMessage  |    | - Course gen     |    | | Judge0 Workers | |
| - CurriculumJob|    | - Lesson gen     |    | | (4 processes,  | |
| - Course       |    | - Challenge gen  |    | |  privileged)   | |
|   (per user)   |    |   (incl. tests)  |    | +----------------+ |
| - Lesson       |    | - Math grading   |    | | PostgreSQL     | |
| - Challenge    |    |   (LaTeX verdict)|    | | (Judge0 DB)    | |
|   kind:        |    |                  |    | +----------------+ |
|    PROGRAMMING |    |                  |    | | Redis          | |
|    | MATH      |    |                  |    | | (Resque queue) | |
| - Submission   |    |                  |    | +----------------+ |
|   (polymorphic |    |                  |    +--------------------+
|    by kind)    |    |                  |
| - LessonProg.  |    |                  |
+----------------+    +------------------+
   Port 27017           External Cloud           Port 2358
   (Docker volume)      (googleapis.com)         (Docker network)
```

---

## CONNECTION DESCRIPTIONS (Arrows Between Layers)

### Client -> Nginx
- **Protocol:** HTTPS (in production)
- **What flows:** Static file requests (HTML, JS, CSS, images) and API calls
- **Format:** REST / JSON

### Nginx -> Express Backend
- **Protocol:** HTTP (internal Docker network)
- **Port:** 80 -> 4000
- **What flows:** API requests proxied from `/api/*`

### Express -> MongoDB
- **Protocol:** MongoDB Wire Protocol (Mongoose ODM)
- **Port:** 27017
- **What flows:** All CRUD — users, chat threads, curriculum jobs, generated courses/lessons/challenges, submissions, lesson progress. Per-user ownership is enforced on every read.
- **Connection:** Persistent connection pool via `mongoose.connect()`

### Express -> Google Gemini API
- **Protocol:** HTTPS (external)
- **Auth:** API key (`GEMINI_API_KEY`)
- **What flows:**
  1. **Mentor chat (sync):** scoped system prompt + conversation history + user message -> AI response.
  2. **Curriculum generation (async):** learning goals JSON -> course outline JSON; lesson stub -> lesson markdown + challenge specs; challenge spec -> problem statement + (for PROGRAMMING) reference solution + test cases or (for MATH) canonical LaTeX + grading rubric.
  3. **Math grading:** problem + canonical LaTeX + student LaTeX -> structured verdict { correct, equivalentForm, rationale, confidence }.
- **SDK:** `@google/generative-ai` — wrapped behind the internal `AIClient` interface so the provider is swappable.

### Express -> Judge0 API
- **Protocol:** HTTP (internal Docker network)
- **Port:** 2358
- **What flows:**
  1. **Request:** source code + language ID + AI-generated stdin + expected stdout (per test case).
  2. **Response:** status (accepted / wrong / error / timeout) + stdout + stderr + execution time + memory usage.
- **Supported Languages (7):** Python, C++, Java, JavaScript, TypeScript, Go, Rust.

---

## DATA FLOW DIAGRAMS (Key User Journeys)

### Flow 1: Student Talks to the Mentor and Requests a Curriculum

```
Student opens /mentor and types: "I want to learn linear algebra
                                  to prepare for ML"
        |
        v
Frontend POST /api/v1/chat/threads/:id/messages
        |
        v
Backend calls Gemini (mentor chat, scope: GENERAL)
  -> Returns a reply that proposes a curriculum
        |
        v
Student clicks "Generate this curriculum"
        |
        v
Frontend POST /api/v1/curriculum/request { threadId }
        |
        v
Backend creates CurriculumJob (status: PENDING),
  returns jobId immediately
        |
        v
Curriculum worker picks up job:
  - Gemini: deduce learning goals from chat history
  - Gemini: generate course outline (lesson stubs)
  - For each lesson:
      - Gemini: lesson markdown body
      - For each challenge spec:
          - kind PROGRAMMING -> Gemini: prompt + reference solution + test cases
          - kind MATH        -> Gemini: problem LaTeX + canonical LaTeX + rubric
  - Writes Course, Lesson, Challenge documents to MongoDB
  - Sets job status to READY
        |
        v
Frontend polls GET /api/v1/curriculum/jobs/:id (useCurriculumJob hook)
  -> Detects READY -> Navigates to the new course
```

### Flow 2: Student Solves a PROGRAMMING Challenge

```
Student writes code in Monaco Editor
        |
        v
Frontend POST /api/v1/execution/submit
  { challengeId, code, language }
        |
        v
Backend loads Challenge from MongoDB
  - Asserts kind === 'PROGRAMMING'
  - Asserts user owns the parent course
  - Loads AI-generated test cases
        |
        v
For each test case:
  POST http://judge0:2358/submissions?wait=true
  -> { status, stdout, stderr, time, memory }
        |
        v
Backend aggregates results
  - All passed? -> Mark lesson complete, award XP
  - Save Submission record (kind: PROGRAMMING)
        |
        v
Frontend displays per-test-case results
  (pass/fail, execution time, memory)
```

### Flow 3: Student Solves a MATH Challenge

```
Student writes their solution in LaTeX
  - KaTeX preview pane renders it live
        |
        v
Frontend POST /api/v1/math/submit
  { challengeId, latex }
        |
        v
Backend loads Challenge from MongoDB
  - Asserts kind === 'MATH'
  - Asserts user owns the parent course
        |
        v
Backend calls aiService.gradeMath({
  problem: challenge.problemLatex,
  canonical: challenge.canonicalSolutionLatex,
  rubric: challenge.gradingRubric,
  studentLatex: req.body.latex,
})
        |
        v
Gemini returns structured JSON:
  { correct, equivalentForm, rationale, confidence }
        |
        v
Backend saves Submission (kind: MATH)
  - If confidence < 0.7 -> status = PENDING_REVIEW
        |
        v
Frontend renders verdict panel
  - Correct / Incorrect / Pending review
  - LLM's rationale rendered with Markdown + KaTeX
```

---

## DOCKER DEPLOYMENT ARCHITECTURE

```
+----------------------------------------------------------+
|                    HOST MACHINE                          |
|                                                          |
|  docker-compose.yml:                                     |
|  +-------------------+    +-------------------+          |
|  |   api             |    |   mongo           |          |
|  |   Node.js:4000    |--->|   MongoDB:27017   |          |
|  |   + curriculum    |    |   (mongo_data vol)|          |
|  |     worker        |    |                   |          |
|  +-------------------+    +-------------------+          |
|                                                          |
|  docker-compose.judge0.yml:                              |
|  +-------------------+    +-------------------+          |
|  | judge0-server     |    | judge0-workers    |          |
|  | API:2358          |    | (4 processes,     |          |
|  | (privileged)      |    |  privileged)      |          |
|  +-------------------+    +-------------------+          |
|  +-------------------+    +-------------------+          |
|  | judge0-db         |    | judge0-redis      |          |
|  | PostgreSQL        |    | Redis (queue)     |          |
|  +-------------------+    +-------------------+          |
|                                                          |
|  Frontend Dockerfile:                                    |
|  +-------------------+                                   |
|  |   nginx           |                                   |
|  |   Static:80       |                                   |
|  |   (serves SPA)    |                                   |
|  +-------------------+                                   |
+----------------------------------------------------------+
```

The production deployment (AWS) hoists the curriculum worker into Step Functions + Lambda and the math grader into its own Lambda — see `Hosting SigmaLoop/README.md` for the full proposal.

---

## VISUAL STYLING GUIDE FOR THE DIAGRAM

### Colors (match SigmaLoop brand):
- **Background:** Dark navy (#0a0e1a or #1a1a2e)
- **Client layer:** Teal/Cyan (#2dd4bf)
- **Nginx layer:** Gray (#6b7280)
- **Backend layer:** Purple (#7c3aed)
- **MongoDB:** Green (#22c55e)
- **Gemini AI:** Blue (#3b82f6)
- **Judge0:** Orange (#f59e0b)
- **Arrows/connections:** White or light gray (#e5e7eb)

### Typography:
- Component names: Bold, 14-16px
- Descriptions: Regular, 10-12px
- Layer labels: Bold caps, 18px

### Layout Tips:
- Rounded rectangles for services.
- Cylinders for databases.
- Cloud shape for external APIs (Gemini).
- Arrows labeled with the data that flows.
- Highlight the **two grading paths** (Judge0 for PROGRAMMING, Gemini for MATH) — they're the most distinctive part of the architecture.
- Highlight the **async generation pipeline** (curriculum worker pulling from CurriculumJob) — this is what makes the experience personalized.

---

## SIMPLIFIED VERSION (For Non-Technical Slide)

If the full diagram is too detailed for the professors, use this simplified version:

```
+------------------+
|    Student's     |
|    Browser       |
|  (React Web App) |
+--------+---------+
         |
    REST API (JSON)
         |
+--------v---------+
|   Backend Server  |
|   (Node.js)       |
+--+------+------+--+
   |      |      |
   v      v      v
+----+ +-------+ +--------+
| DB | |  AI   | |  Code  |
|    | | Tutor | | Runner |
+----+ +-------+ +--------+
MongoDB Gemini    Judge0
         |          |
   chat, gen,    runs AI-generated
   math grading  test cases
```

Three layers, three backend services — clean enough for a 30-second explanation. The takeaway slide: *"Every student gets their own AI-generated curriculum, with Judge0 grading programming and Gemini grading math."*
