# SigmaLoop System Architecture — Diagram Specification

Use this document to generate a system architecture diagram for the university presentation.

---

## DIAGRAM LAYOUT (Top to Bottom, 4 Layers)

```
=======================================================================
LAYER 1: CLIENT LAYER (Top)
=======================================================================

  +-------------------------------------------------------+
  |              USER'S BROWSER / DEVICE                   |
  |                                                        |
  |  +-------------------+  +------------------+           |
  |  | React 19 SPA      |  | Monaco Code      |           |
  |  | (TypeScript + Vite)|  | Editor           |           |
  |  +-------------------+  +------------------+           |
  |                                                        |
  |  +-------------------+  +------------------+           |
  |  | Tailwind CSS      |  | AI Chat Widget   |           |
  |  | Glass UI          |  | (SigmaBot)       |           |
  |  +-------------------+  +------------------+           |
  |                                                        |
  |  +---------------------------------------------+       |
  |  | Auth Context (JWT Token in localStorage)     |       |
  |  +---------------------------------------------+       |
  +-------------------------------------------------------+
              |
              | HTTPS / REST API (JSON - JSend Format)
              | Authorization: Bearer <JWT>
              v

=======================================================================
LAYER 2: WEB SERVER / REVERSE PROXY
=======================================================================

  +-------------------------------------------------------+
  |              NGINX (Production)                        |
  |  - Serves static frontend files (HTML/JS/CSS)          |
  |  - SPA routing (all paths -> index.html)               |
  |  - Asset caching (1 year for static files)             |
  |  - Reverse proxy API requests to backend               |
  +-------------------------------------------------------+
              |
              | HTTP (port 80 -> port 4000)
              v

=======================================================================
LAYER 3: APPLICATION SERVER (Middle)
=======================================================================

  +-------------------------------------------------------+
  |              NODE.JS + EXPRESS (TypeScript)             |
  |              Port 4000 — /api/v1/*                     |
  |                                                        |
  |  MIDDLEWARE PIPELINE:                                   |
  |  +----------+  +-----------+  +--------+  +---------+ |
  |  |   CORS   |->| Body      |->|  Auth  |->| Request | |
  |  |  Filter  |  | Parser    |  | (JWT)  |  | Logger  | |
  |  +----------+  +-----------+  +--------+  +---------+ |
  |                                                        |
  |  ROUTE HANDLERS:                                       |
  |  +---------------------------------------------------+ |
  |  |                                                   | |
  |  |  /auth          - Register, Login, Get Profile    | |
  |  |  /users         - User management, enrollments    | |
  |  |  /courses       - CRUD courses                    | |
  |  |  /lessons       - CRUD lessons                    | |
  |  |  /challenges    - CRUD challenges                 | |
  |  |  /execution     - Run code, Submit solutions      | |
  |  |  /chat          - AI chat threads & messages      | |
  |  |  /ai            - AI course/lesson generation     | |
  |  |                                                   | |
  |  +---------------------------------------------------+ |
  |                                                        |
  |  SERVICES:                                             |
  |  +-----------------+  +--------------------+           |
  |  | Auth Service    |  | AI Service         |           |
  |  | (bcrypt + JWT)  |  | (Gemini SDK)       |           |
  |  +-----------------+  +--------------------+           |
  +-------------------------------------------------------+
         |                    |                    |
         |                    |                    |
         v                    v                    v

=======================================================================
LAYER 4: EXTERNAL SERVICES & DATA (Bottom)
=======================================================================

+----------------+    +------------------+    +--------------------+
|   MongoDB 7    |    | Google Gemini    |    | Judge0 CE          |
|   Database     |    | AI API           |    | Code Execution     |
|                |    |                  |    | Engine              |
| 13 Collections:|    | Model:           |    |                    |
| - User         |    |  gemini-2.5-flash|    | +----------------+ |
| - Course       |    |                  |    | | Judge0 Server  | |
| - Lesson       |    | Features:        |    | | (port 2358)    | |
| - Challenge    |    | - Chat responses |    | +----------------+ |
| - Enrollment   |    | - Course gen     |    | | Judge0 Workers | |
| - LessonProg.  |    | - Lesson gen     |    | | (4 processes)  | |
| - Submission   |    | - Challenge gen  |    | +----------------+ |
| - ChatThread   |    |                  |    | | PostgreSQL     | |
| - ChatMessage  |    |                  |    | | (Judge0 DB)    | |
| - GenCourse    |    |                  |    | +----------------+ |
| - GenLesson    |    |                  |    | | Redis          | |
| - GenChallenge |    |                  |    | | (Job Queue)    | |
+----------------+    +------------------+    +--------------------+
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
- **What flows:** All CRUD operations — users, courses, lessons, challenges, submissions, chat history, AI-generated content
- **Connection:** Persistent connection pool via `mongoose.connect()`

### Express -> Google Gemini API
- **Protocol:** HTTPS (external)
- **Auth:** API key (`GEMINI_API_KEY`)
- **What flows:**
  1. **Chat:** System prompt + conversation history + user message -> AI response text
  2. **Course Generation:** User prompt + difficulty -> Full course JSON (title, description, lessons with challenges)
  3. **Lesson Generation:** Course context + prompt -> Lesson markdown + challenges JSON
- **SDK:** `@google/generative-ai` v0.24.1

### Express -> Judge0 API
- **Protocol:** HTTP (internal Docker network)
- **Port:** 2358
- **What flows:**
  1. **Request:** Source code + language ID + stdin + expected output
  2. **Response:** Status (accepted/wrong/error) + stdout + stderr + execution time + memory usage
- **Supported Languages (7):** Python, C++, Java, JavaScript, TypeScript, Go, Rust

---

## DATA FLOW DIAGRAMS (Key User Journeys)

### Flow 1: Student Solves a Challenge
```
Student writes code in Monaco Editor
        |
        v
Frontend sends POST /api/v1/execution/submit
  { code, language, challengeId }
        |
        v
Backend fetches Challenge from MongoDB
  (gets test cases: public + hidden)
        |
        v
Backend sends code to Judge0 (one request per test case)
  POST http://judge0:2358/submissions?wait=true
        |
        v
Judge0 compiles & runs code in sandbox
  Returns: { status, stdout, stderr, time, memory }
        |
        v
Backend aggregates results
  - All passed? -> Mark lesson complete, award +50 XP
  - Save Submission record to MongoDB
        |
        v
Frontend displays results
  (pass/fail per test case, execution time, memory)
```

### Flow 2: Student Chats with AI Mentor
```
Student types message in ChatWidget
        |
        v
Frontend sends POST /api/v1/chat/threads/:id/messages
  { content: "Explain Big O Notation" }
        |
        v
Backend builds context-aware system prompt:
  - Student's role & level
  - Current scope (GENERAL / LESSON / COURSE)
  - If LESSON: includes lesson content + challenge details
  - If COURSE: includes course structure
        |
        v
Backend fetches last 20 messages from MongoDB
  (conversation history)
        |
        v
Backend calls Gemini API via ai.service.ts
  model.startChat({ history, systemInstruction })
  chat.sendMessage(userMessage)
        |
        v
Gemini returns AI response text
        |
        v
Backend saves both messages to MongoDB
  (UserMessage + AssistantMessage in ChatMessage collection)
        |
        v
Frontend renders response with:
  - Markdown formatting
  - Code syntax highlighting
  - LaTeX math rendering (KaTeX)
```

### Flow 3: AI Generates a Full Course
```
Instructor enters prompt: "Python for Data Science"
  + selects difficulty: Intermediate
        |
        v
Frontend sends POST /api/v1/ai/generate-course
  { prompt, difficulty }
        |
        v
Backend calls Gemini API with structured prompt
  - Requests: course title, description, tags, 3-5 lessons
  - Each lesson: title, markdown content, 1-2 challenges
  - Each challenge: starter code (7 langs), solution code, test cases
  - Response format: application/json
        |
        v
Gemini returns structured JSON
        |
        v
Backend parses & saves to MongoDB:
  - GeneratedCourse document
  - GeneratedLesson documents (linked to course)
  - GeneratedChallenge documents (linked to lessons)
        |
        v
Frontend navigates to generated course view
  (student can browse lessons and solve challenges immediately)
```

---

## DOCKER DEPLOYMENT ARCHITECTURE

```
+----------------------------------------------------------+
|                    HOST MACHINE                           |
|                                                           |
|  docker-compose.yml:                                      |
|  +-------------------+    +-------------------+           |
|  |   api             |    |   mongo           |           |
|  |   Node.js:4000    |--->|   MongoDB:27017   |           |
|  |   (Express app)   |    |   (mongo_data vol)|           |
|  +-------------------+    +-------------------+           |
|                                                           |
|  docker-compose.judge0.yml:                               |
|  +-------------------+    +-------------------+           |
|  | judge0-server     |    | judge0-workers    |           |
|  | API:2358          |    | (4 processes)     |           |
|  +-------------------+    +-------------------+           |
|  +-------------------+    +-------------------+           |
|  | judge0-db         |    | judge0-redis      |           |
|  | PostgreSQL        |    | Redis (queue)     |           |
|  +-------------------+    +-------------------+           |
|                                                           |
|  Frontend Dockerfile:                                     |
|  +-------------------+                                    |
|  |   nginx           |                                    |
|  |   Static:80       |                                    |
|  |   (serves SPA)    |                                    |
|  +-------------------+                                    |
+----------------------------------------------------------+
```

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
- Use rounded rectangles for services
- Use cylinders for databases
- Use cloud shapes for external APIs (Gemini)
- Use arrows with labels describing what data flows
- Keep it horizontal or top-to-bottom (top-to-bottom preferred for presentations)
- Add small icons/logos where possible (React, Node.js, MongoDB, Google Gemini logos)

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
+----+ +-----+ +-------+
| DB | | AI  | | Code  |
|    | |Tutor| | Runner|
+----+ +-----+ +-------+
MongoDB  Gemini   Judge0
```

This simplified version has 3 layers and 3 backend services — clean enough for a 30-second explanation.
