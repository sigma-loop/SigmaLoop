# SigmaLoop — Claude Design Diagram Blueprint Guide

This document is a comprehensive compilation and design specification for the **16 technical diagrams** in the SigmaLoop book. It serves as the single source of truth for generating these diagrams using Claude (via Claude Artifacts, SVG generation, or Claude-driven frontend designs).

By feeding the **Master System Prompt** and the **Refined Prompts** in this guide to Claude, you can generate production-ready, beautiful, and consistent visual assets for the book.

---

## 🎨 SigmaLoop Brand Palette & Visual Identity

To maintain consistency across all diagrams, use the following exact hex codes and shapes:

| Element / Service | Role / Meaning | Hex Code | Visual Shape / Style |
| :--- | :--- | :--- | :--- |
| **Dark Navy Background** | Primary canvas for dark diagrams | `#0a0e1a` / `#1a1a2e` | Solid fill, dark mode layout |
| **Light Background** | Canvas for ERD, Config, UI flows | `#ffffff` | Clean white space, flat layout |
| **Teal / Cyan** | Client / SPA Layer (React 19) | `#2dd4bf` | Rounded rectangles, thin borders |
| **Gray** | Edge / Proxy Layer (Nginx, Gateway) | `#6b7280` | Rounded rectangles, neutral labels |
| **Indigo / Purple** | Application Backend, APIs, Services | `#7c3aed` / `#6366f1` | Rounded rectangles, glowing accents |
| **Green** | Databases & Data Writes (MongoDB, DocumentDB) | `#22c55e` | Cylinders / 3D-effect flat barrels |
| **Blue** | AI Services & LLM calls (DeepSeek, Gemini) | `#3b82f6` | Rounded clouds or dual-color pill shapes |
| **Orange** | Sandboxes & Grading Engines (Judge0) | `#f59e0b` | Structured boxes, warning/critical outlines |
| **Light Gray** | Arrows, Connectors, Text Labels | `#e5e7eb` / `#9ca3af` | Hairline lines (1px), subtle endpoints |

### General Styling Conventions:
- **Aesthetic**: Flat, developer-centric, minimal, inspired by Linear.app or Vercel design systems.
- **Borders**: 1px hairline borders (`stroke-width="1"`). No heavy bevels or drop shadows.
- **Typography**: Clean geometric sans-serif (such as *Inter*, *Outfit*, or *system-ui*).
- **Icons**: Simple line-art icons (clock for async processes, database cylinder for storage, shield for auth, lock for secrets, AI chip for LLM calls).

---

## 🤖 Master System Prompt for Claude (SVG Generator)

Copy and paste this system prompt along with any of the refined prompts below to generate a pixel-perfect, modern SVG diagram directly:

```text
You are an expert systems architect and developer-focused graphic designer.
Your task is to output a single, highly polished, modern SVG diagram based on the user's prompt.

Adhere to these strict visual constraints:
1. Palette: Dark Navy (#0a0e1a) or pure White (#ffffff) background as specified.
   Use the exact colors: Teal (#2dd4bf) for Client, Gray (#6b7280) for Edge/Proxy, Indigo (#7c3aed) or accent (#6366f1) for APIs/Compute, Green (#22c55e) for Databases, Blue (#3b82f6) for AI APIs, Orange (#f59e0b) for Judge0, Light Gray (#e5e7eb) for lines.
2. Layout: Align boxes on a clean grid. Use rounded rectangles (rx="6" ry="6") for services, cylinders for databases, clouds for SaaS APIs, and 1px hairline arrows for data flow.
3. Typography: Use geometric sans-serif (Inter, system-ui) with explicit font-size, font-weight, and text-anchor. Ensure text contrast is high.
4. Cleanliness: Make it look like a Vercel, Linear, or Stripe architectural diagram. Flat elements, no heavy gradients, thin lines (stroke-width="1" or "1.5"), subtle glows or dashed overlays where appropriate.
5. Format: Return ONLY valid, well-structured, self-contained SVG code inside a markdown code block. Do not wrap in HTML or add conversational text. Include viewBox and set width="100%" height="auto" for responsiveness.
```

---

## 🗺️ Individual Diagram Blueprint Directory

Below is the compilation of the 16 diagrams that need to be generated, complete with their chapter context, original prompt, component details, and optimized instructions for Claude.

---

### 📘 Figure 0.1 — Book Cover Art
- **Chapter**: Cover
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: Editorial Poster / Book Cover
- **Visual Breakdown**:
  - A clean, modern book cover layout (2:3 aspect ratio).
  - Centered primary typography "SigmaLoop" with an abstract, elegant geometric logo.
  - Background elements: A subtle, thin-line Sigma symbol ($\Sigma$) represented as a node graph or neural network loop transitioning from teal to indigo.
- **Original Prompt**:
  > "A premium technical book cover on a dark navy (#0a0e1a) background. Centered title 'SigmaLoop' in a clean geometric sans-serif (Outfit/Inter style), with the tagline 'Master the Logic behind the Code' beneath it in a lighter indigo (#6366f1). Behind the title, a subtle abstract motif: a looping sigma (Σ) symbol formed from flowing nodes-and-edges that suggest both a neural network and a learning path, in teal (#2dd4bf) and indigo. Minimal, Linear/Vercel aesthetic — flat, hairline accents, no glossy gradients. Leave generous negative space. 2:3 portrait aspect ratio."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a premium 2:3 portrait book cover (e.g. viewBox="0 0 600 900") on a dark navy (#0a0e1a) background.
  - Title: 'SigmaLoop' in a bold, geometric sans-serif font (fontSize="56", letterSpacing="2") centered at y="350".
  - Tagline: 'Master the Logic behind the Code' in a lighter indigo (#6366f1, fontSize="18") centered at y="400".
  - Abstract Motif: In the center-background, draw a flowing, stylized Sigma (Σ) symbol formed by hairline connections (stroke-width="1.5") and small glowing circles (radius="3" to "5") that resemble a neural network. Animate the colors smoothly from teal (#2dd4bf) to indigo (#7c3aed).
  - Borders: A very thin, elegant double-hairline border frame in light gray (#e5e7eb, opacity="0.1") around the edges of the cover.
  - Aesthetics: Lots of clean negative space, ultra-sharp vectors, premium minimalism.
  ```

---

### 📘 Figure 2.1 — The Four-Layer Architecture
- **Chapter**: 2 — Architecture Overview
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: Multi-tier System Architecture
- **Visual Breakdown**:
  - Four horizontal tiers stacked vertically (Client, Edge, Application, Data & External).
  - Labeled boxes for components within each tier.
  - Connections with flow labels showing communication protocols.
- **Original Prompt**:
  > "A clean, technical 4-layer system architecture diagram on a dark navy (#0a0e1a) background, four stacked horizontal bands. **Top band — Client (teal #2dd4bf):** a browser containing 'React 19 SPA', 'Mentor Chat', 'Monaco Editor (PROGRAMMING)', 'MathLive + KaTeX (MATH)', 'JWT in localStorage'. **Second band — Edge (gray #6b7280):** 'Nginx / CloudFront — static SPA, SPA routing, asset caching'. **Third band — Application (indigo #7c3aed):** a Node.js + Express box showing a middleware pipeline 'CORS → Body parser → Auth (JWT) → Logger', a row of route groups (auth, users, chat, curriculum, courses, lessons, challenges, execution, math, mcq, i18n, admin), and a services row (AI Service, Curriculum Worker, Judge0 Service, Settings Service). **Bottom band — Data & External (mixed):** a green MongoDB cylinder, a blue cloud 'DeepSeek + Gemini AI', and an orange 'Judge0 CE' box containing server + 4 workers + Postgres + Redis. Label the arrows: Client→Edge 'HTTPS / REST (JSend)', App→Mongo 'Mongoose', App→AI 'HTTPS, AIClient', App→Judge0 'HTTP :2358, base64 submissions'. Rounded rectangles for services, cylinders for databases, a cloud for the external AI. Linear/Vercel flat aesthetic, hairline arrows in light gray (#e5e7eb)."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a landscape system architecture diagram (viewBox="0 0 1000 700") on a dark navy (#0a0e1a) background.
  Draw four stacked horizontal bands with thin boundaries:
  1. Client Tier (Teal #2dd4bf): Frame a browser window enclosing: React 19 SPA, Mentor Chat, Monaco Editor, MathLive, and local JWT storage.
  2. Edge Tier (Gray #6b7280): Box for Nginx / CloudFront (routing & static caching).
  3. Application Tier (Indigo #7c3aed): Node.js + Express box containing:
     - Middleware chain: CORS -> Body parser -> Auth (JWT) -> Logger.
     - Route groups: auth, users, chat, curriculum, courses, lessons, challenges, execution, math, mcq, i18n, admin.
     - Services row: AI Service, Curriculum Worker, Judge0 Service, Settings Service.
  4. Data & External Tier:
     - Green database cylinder for MongoDB.
     - Blue cloud outline for DeepSeek + Gemini AI.
     - Orange boxed sandbox container for Judge0 CE (server + 4 workers + Postgres + Redis).
  Connect tiers with 1px light gray (#e5e7eb) arrows and clear text labels:
  - Client -> Edge: 'HTTPS / REST (JSend)'
  - Edge -> App: 'Proxy'
  - App -> MongoDB: 'Mongoose' (green arrow)
  - App -> AI Cloud: 'HTTPS, AIClient' (blue arrow)
  - App -> Judge0: 'HTTP :2358, base64 submissions' (orange arrow)
  Use a flat Vercel/Linear aesthetic with hairline borders and sharp text.
  ```

---

### 📘 Figure 2.2 — Mentor Chat to Async Curriculum Generation
- **Chapter**: 2 — Architecture Overview
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: Sequential Flow Diagram
- **Visual Breakdown**:
  - Vertical timeline showing the path from a user typing a chat message to an asynchronous course generation process starting, polling, and redirecting.
  - Dashed outline representing the asynchronous worker environment.
- **Original Prompt**:
  > "A vertical sequence/flow diagram on dark navy. Boxes top-to-bottom: (1) 'Student opens /mentor, types: I want to learn linear algebra for ML'; (2) 'POST /chat/threads/:id/messages'; (3) 'API runs the autonomous mentor loop (AIClient: DeepSeek→Gemini)'; (4) decision diamond 'mentor emits [[ACTION: create_course]]?'; if yes → (5) 'Create CurriculumJob (status: PENDING), return immediately with jobId'; (6) dashed box labelled ASYNC 'Curriculum Worker claims job atomically'; inside it a small pipeline 'generate outline (≥12 lessons) → write all lessons as STUBs → materialize lesson 1 → status READY'; (7) 'Frontend polls GET /curriculum/jobs/:id via useCurriculumJob (4s)'; (8) 'READY → navigate to the new course'. Use indigo for API boxes, green for DB writes, a clock icon on the ASYNC block. Hairline arrows."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a vertical sequence flow diagram (viewBox="0 0 800 950") on a dark navy (#0a0e1a) background.
  Layout 8 logical stages stacked vertically from top to bottom with clean, centered hairline arrows:
  1. Box: 'Student opens /mentor, types: I want to learn linear algebra for ML'
  2. Box: 'POST /chat/threads/:id/messages' (API Gateway / Chat Controller)
  3. Box: 'API runs autonomous mentor loop (AIClient: DeepSeek -> Gemini)'
  4. Diamond: 'Mentor emits [[ACTION: create_course]]?'
     - Yes arrow points down to Step 5.
     - No arrow points to a side box: 'Normal chat response returned' (faded gray).
  5. Box (Green border): 'Create CurriculumJob (status: PENDING), return immediately with jobId'
  6. Dashed Box (Large, labeled 'ASYNC WORKER LOOP' with a clock icon): Enclose a pipeline:
     - 'Curriculum Worker claims job atomically (PENDING -> GENERATING)'
     - '1. Generate outline (≥12 lessons)' -> '2. Write all lessons as STUBs' -> '3. Materialize lesson 1 (async)' -> '4. Status to READY' (Green fill).
  7. Box: 'Frontend polls GET /curriculum/jobs/:id (4s Interval)'
  8. Box (Teal border): 'Status READY -> Client redirects to /courses/:id'
  Use indigo (#7c3aed) for API boxes, green (#22c55e) for database actions, and clean hairline connecting lines.
  ```

---

### 📘 Figure 4.1 — Entity-Relationship Diagram (ERD)
- **Chapter**: 4 — Data Models
- **Theme**: Light Mode (Background `#ffffff`)
- **Diagram Type**: Entity-Relationship Diagram (Crow's Foot)
- **Visual Breakdown**:
  - Core database collections represented as boxes.
  - Foreign key linkages labeled clearly on the lines.
  - Discriminated entities (inheritance/variants) shown branching from a base box.
- **Original Prompt**:
  > "A clean entity-relationship diagram on a white background, indigo (#6366f1) accent. Central entity **User**. From User, one-to-many edges to: **ChatThread** (→ **ChatMessage**), **CurriculumJob**, **Course**, **MentorAction**. **Course** one-to-many **Lesson**; **Lesson** one-to-many **Challenge**; **Challenge** shown as a discriminated entity with three sub-types PROGRAMMING / MATH / MCQ. **Submission** links **User** and **Challenge**, also discriminated into PROGRAMMING/MATH/MCQ. **LessonProgress** links **User** and **Lesson** (unique pair). **LessonTranslation** links **Lesson**+language; **UiTranslation** stands alone (global cache). **AppSettings** stands alone. Show crow's-foot notation, label each edge with its foreign key (userId, courseId, lessonId, challengeId, threadId). Flat, hairline borders, no shadows."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a clean Entity-Relationship Diagram (viewBox="0 0 1000 800") on a white background.
  - Style: Hairline borders (stroke-width="1"), indigo (#6366f1) accents for primary borders, black text.
  - Entities (Draw as structured boxes showing fields or just entity names):
    - User (Central box)
    - ChatThread, ChatMessage, CurriculumJob, Course, MentorAction, Lesson, Challenge, Submission, LessonProgress, LessonTranslation, UiTranslation, AppSettings.
  - Connections & Crow's Foot:
    - User has 1-to-many to: ChatThread (labeled 'userId'), CurriculumJob ('userId'), Course ('userId'), MentorAction ('userId'), LessonProgress ('userId'), Submission ('userId').
    - ChatThread has 1-to-many to ChatMessage ('threadId').
    - Course has 1-to-many to Lesson ('courseId').
    - Lesson has 1-to-many to Challenge ('lessonId') and LessonTranslation ('lessonId').
    - LessonProgress links User and Lesson.
    - Challenge is a split box/base showing sub-types: PROGRAMMING, MATH, MCQ.
    - Submission is linked from User and Challenge, with sub-types: PROGRAMMING, MATH, MCQ.
    - UiTranslation and AppSettings are drawn as standalone tables without relational arrows.
  Ensure all arrows use crow's foot notation (one/many lines) and edges are neatly routed with right angles.
  ```

---

### 📘 Figure 7.1 — The Runtime Settings Overlay
- **Chapter**: 7 — Config & Runtime Settings
- **Theme**: Light Mode (Background `#ffffff`)
- **Diagram Type**: Horizontal Flow / Control Loop
- **Visual Breakdown**:
  - Shows how a change in settings from the admin page mutates the live server config in-memory without restarting.
  - Visually separates database settings from environment variables.
- **Original Prompt**:
  > "A horizontal flow diagram on white with indigo accents. Left: 'Admin Settings UI' sends 'PUT /admin/settings {key,value}'. Middle: a box 'settings.service.ts' with three steps stacked — '1. validate against settingsRegistry', '2. upsert into Mongo AppSettings', '3. applyToConfig: setByPath(config, def.path, value) — MUTATE IN PLACE'. An arrow from step 3 to a glowing box 'live config singleton'. Below, a dashed arrow labelled 'if reresolveAI flag' to a box 'rebuild AIClient (Proxy swaps activeClient)'. Right: many small consumers (controllers, worker, ai.service) all reading 'config.x.y at call-time'. Show secrets as a separate locked box labelled 'env-only, never in Mongo, shown as configured/not-configured'. Flat, hairline."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a horizontal data-flow architecture diagram (viewBox="0 0 950 550") on a white background.
  - Layout left-to-right:
    1. Left: 'Admin Settings UI' (a browser dashboard icon) emitting a REST call arrow labeled 'PUT /admin/settings {key, value}' to settings service.
    2. Center: A large bounding box 'settings.service.ts' containing three stacked rectangles:
       - '1. Validate against settingsRegistry'
       - '2. Upsert into MongoDB AppSettings (DB persistence)'
       - '3. Mutate config singleton in-place (applyToConfig)'
    3. Below step 3: Draw a dashed conditional arrow labeled 'if reresolveAI flag === true' pointing down to:
       - 'Rebuild AIClient (Proxy Swaps activeClient)'
    4. Arrow from step 3 points to a glowing indigo box: 'Live In-Memory Config Singleton'.
    5. Right: A column of consumer nodes reading at call-time: 'AI Service', 'Curriculum Worker', 'Express Controllers'. Point arrows from the config singleton to each consumer.
    6. Draw a separate, dashed-out boundary box in gray representing 'Environment Variables (.env)' marked with a lock icon, labeled: 'Sensitive Secrets: Env-only, never saved to MongoDB, exposed in UI only as configured boolean'.
  Maintain a minimal, modern, light-themed aesthetic with sharp lines and indigo (#6366f1) accents.
  ```

---

### 📘 Figure 9.1 — The Kind-Dispatched Workspace
- **Chapter**: 9 — Challenge Workspaces
- **Theme**: Light Mode (Background `#ffffff`)
- **Diagram Type**: Dispatch / Branching Layout
- **Visual Breakdown**:
  - Single entry point (ChallengeWorkspace) branching into three workspace layouts (Programming, Math, MCQ).
  - Converges back into a single callback event when completed.
- **Original Prompt**:
  > "A clean diagram on white, indigo accent. A central rounded box 'ChallengeWorkspace (switch on challenge.kind)' with three labelled branches: 'PROGRAMMING → ProgrammingWorkspace (Monaco editor + Output panel, POST /execution/submit)', 'MATH → MathWorkspace (MathLive math-field + Verdict panel, POST /math/submit)', 'MCQ → MCQWorkspace (option buttons, POST /mcq/submit)'. Each branch shows a tiny wireframe of its UI. All three converge on a shared callback 'onCompleted() → LessonView marks challenge passed'. Flat, hairline borders."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a clean flow dispatch diagram (viewBox="0 0 900 600") on a white background with indigo (#6366f1) highlights.
  - Left: Draw an incoming trigger arrow 'Load Challenge' into the main component box.
  - Center-Left: Rounded box: 'ChallengeWorkspace (Switch on challenge.kind)'.
  - Three paths fork horizontally to the right:
    1. Top Fork: 'PROGRAMMING' pointing to 'ProgrammingWorkspace' box. Include a tiny wireframe representation (split panel: left editor, right console) and path details: 'Monaco Editor + Output Panel' / 'POST /execution/submit'.
    2. Middle Fork: 'MATH' pointing to 'MathWorkspace' box. Include a tiny wireframe representation (formula field + check button) and path details: 'MathLive math-field + Verdict Panel' / 'POST /math/submit'.
    3. Bottom Fork: 'MCQ' pointing to 'MCQWorkspace' box. Include a tiny wireframe representation (vertical option blocks) and path details: 'Option Select Buttons' / 'POST /mcq/submit'.
  - Converging Flow: Point lines from the right side of all three workspace blocks to converge on a single right-side box: 'onCompleted() Callback'.
  - Final Outcome: Point from callback to: 'LessonView updates state -> Mark Challenge as PASSED'.
  Style with 1px black/gray borders, clean font labeling, and indigo accents.
  ```

---

### 📘 Figure 12.1 — The Lazy Generation Pipeline
- **Chapter**: 12 — Curriculum Generation Pipeline
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: System Pipeline & Async State Flow
- **Visual Breakdown**:
  - Triggers pointing to a queue, which is claimed by a worker.
  - The worker performs outline generation and lazy challenge generation.
  - Faded stub vs solid loaded cards comparison.
- **Original Prompt**:
  > "A detailed pipeline diagram on dark navy. Left: four trigger sources stacked (Onboarding wizard, POST /curriculum/request, Mentor tool create_course, Course generate-more) all pointing to a single green cylinder 'CurriculumJob (status: PENDING)'. Middle: a box 'Curriculum Worker (polls every 5s)' with an atomic-claim badge 'findOneAndUpdate PENDING→GENERATING'. From it, a vertical pipeline for NEW_COURSE: '1. generateCourseOutline (≥12 lessons)' → '2. Course.create (GENERATING)' → '3. write ALL lessons as STUBs (insertMany)' → '4. materialize ONLY lesson 1' → '5. status READY'. Show stubs as faded grey lesson cards and the first lesson as a solid indigo card. Right: a separate later flow 'Learner opens lesson N → POST /lessons/N/generate → materializeLesson: body + challenges generated concurrently → status READY'. Use a clock icon on async parts and a small AI-chip icon on each model call. Hairline arrows, labels on each step."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a pipeline and architecture diagram (viewBox="0 0 1000 800") on a dark navy (#0a0e1a) background.
  - Left: Stack four trigger source blocks (Onboarding Wizard, POST /curriculum/request, Mentor 'create_course' action, Course 'generate-more' button). Point them to a central green database cylinder: 'CurriculumJob (status: PENDING)'.
  - Center: A service box 'Curriculum Worker' (marked with a clock icon) showing the claim rule 'findOneAndUpdate: PENDING -> GENERATING'.
    - From here, draw a downward pipeline for course generation:
      - Step 1: 'generateCourseOutline' (Add AI chip icon)
      - Step 2: 'Course.create (status: GENERATING)'
      - Step 3: 'Write all 12+ lessons as STUBs (insertMany)' (Draw 3 stacked faded gray outline cards labeled 'Stub Lesson')
      - Step 4: 'Materialize Lesson 1 details' (Draw a solid indigo filled card labeled 'Active Lesson 1')
      - Step 5: 'Job status to READY' (Green tag)
  - Right Side: A separate flow diagram box for lazy loading:
    - Trigger: 'Learner navigates to Lesson N (Stub)' -> sends 'POST /lessons/:id/generate'.
    - Processing box: 'materializeLesson' (runs body & challenge generation concurrently via LLM - add AI chip icon).
    - Result: 'Lesson changes status to READY'.
  Use the brand palette: green (#22c55e) for database, indigo (#7c3aed) for active app states, gray (#6b7280) for stubs, and light gray hairline arrows.
  ```

---

### 📘 Figure 13.1 — The Mentor Tool Loop
- **Chapter**: 13 — The Mentor Agent
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: Multi-step Agent Loop / ReAct Loop
- **Visual Breakdown**:
  - Circular loop illustrating the ReAct (Reasoning and Acting) execution structure.
  - Decisions around whether an action needs tool execution or can return directly to the user.
- **Original Prompt**:
  > "A loop/cycle diagram on dark navy. Start: 'User message saved'. Into a cycle (max 8 iterations): box 'aiClient.chat(systemPrompt, history, pending)' → 'extractAction: parse last [[ACTION:{...}]]' → decision diamond 'action present?'. If YES → 'executeTool (ownership-scoped)' → 'feed [[TOOL_RESULT]] or [[TOOL_ERROR]] back as next user turn' → back to chat. If NO → 'finalText = cleaned reply, exit loop'. Side annotations: 'each action logged as MentorAction', 'MAX_MUTATIONS=5 → synthetic stop', 'provider failure after an action → finish with: Here's what I did'. End: 'persist final assistant message + return actions[]'. Indigo boxes, green for DB writes, hairline arrows."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a process loop diagram (viewBox="0 0 900 700") on a dark navy (#0a0e1a) background.
  - Entry: 'Start: User message saved in DB' points into the main evaluation loop.
  - Loop Box (Label: 'Execution Loop - Max 8 Iterations'):
    - Box: 'aiClient.chat(systemPrompt, history, pending)'
    - Step: 'extractAction: parse last block [[ACTION: name, args]]'
    - Diamond: 'Is Action Present?'
      - If YES (Right arrow): 'executeTool(ownership-scoped)' -> 'Create MentorAction DB Log' -> points to 'Append [[TOOL_RESULT]] or [[TOOL_ERROR]] to history' -> loops back into 'aiClient.chat'.
      - If NO (Down arrow): 'finalText = cleaned reply' -> 'Exit Loop'.
  - Exit Node: 'Persist final assistant message in thread -> Send Response message & actions[] to client'.
  - Annotate near the loop with small boxes:
    - 'Safety Cap: MAX_MUTATIONS = 5 per thread to prevent runaways.'
    - 'Fallback: If provider fails after tool executions, exit early and prefix with "Here is what I completed..."'
  Color theme: Indigo (#7c3aed) for chat processing, green (#22c55e) for database actions, and clean gray hairline arrows.
  ```

---

### 📘 Figure 14.1 — Three Graders, One Progress Engine
- **Chapter**: 14 — Judging & Evaluation
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: Data Convergence Lanes
- **Visual Breakdown**:
  - Three distinct vertical paths corresponding to Programming, Math, and MCQ submissions.
  - Each path shows its specific validation process (e.g. sandbox, LLM, or set comparison).
  - All paths merge at the bottom into the progress completion service.
- **Original Prompt**:
  > "A diagram on dark navy, three parallel grading lanes converging on one engine. Lane 1 (orange): 'PROGRAMMING — POST /execution/submit → Judge0 sandbox runs all test cases → pass iff status id 3 → ProgrammingSubmission'. Lane 2 (blue): 'MATH — POST /math/submit → LLM gradeMath(problem, canonical, studentLatex) → {correct, equivalentForm, rationale, confidence} → confidence<0.7 ? PENDING_REVIEW : PASSED/FAILED'. Lane 3 (green): 'MCQ — POST /mcq/submit → set-equality(selected, correctIds) → MCQSubmission'. All three arrow into a central box 'progress.service.markLessonComplete — lesson done only when ALL challenges PASSED → +50 XP'. Label the determinism: lanes 1 and 3 tagged 'DETERMINISTIC', lane 2 tagged 'LLM (confidence-gated)'. Hairline arrows, a Status enum chip 'PENDING · RUNNING · PASSED · FAILED · PENDING_REVIEW'."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a parallel process flow diagram (viewBox="0 0 1000 650") on a dark navy (#0a0e1a) background.
  Draw three vertical/parallel lanes from top to bottom:
  - Lane 1 (Orange, labeled 'DETERMINISTIC'): 'PROGRAMMING'
    - Flow: POST /execution/submit -> 'Judge0 sandbox runs test cases' -> 'Pass if status_id === 3 (Accepted)' -> Create ProgrammingSubmission.
  - Lane 2 (Blue, labeled 'LLM (CONFIDENCE-GATED)'): 'MATH'
    - Flow: POST /math/submit -> 'LLM gradeMath(problem, canonical, studentLatex)' -> returns json {correct, equivalentForm, rationale, confidence} -> check 'confidence < 0.7 ? status=PENDING_REVIEW : status=PASSED/FAILED'.
  - Lane 3 (Green, labeled 'DETERMINISTIC'): 'MCQ'
    - Flow: POST /mcq/submit -> 'Set-equality validation (selectedOptions === correctIds)' -> Create MCQSubmission.
  Convergence:
  Point all three lanes to a unified horizontal engine box at the bottom:
  - 'progress.service.markLessonComplete'
  - Action: 'Check if all challenges inside lesson are PASSED -> Mark lesson complete -> Award +50 XP'
  Add a legend chip displaying the 'Status' enum: [PENDING, RUNNING, PASSED, FAILED, PENDING_REVIEW].
  Use 1px hairline lines and color coding corresponding to each lane's type.
  ```

---

### 📘 Figure 15.1 — The Translation Pipeline
- **Chapter**: 15 — Translation Pipeline
- **Theme**: Light Mode (Background `#ffffff`)
- **Diagram Type**: Multi-lane Extraction Flow
- **Visual Breakdown**:
  - Three pipelines showing the processing of UI strings (cached globally), lesson content (cached locally), and live mentor prompts (dynamic, non-cached).
- **Original Prompt**:
  > "A diagram on white with indigo accent, three lanes. Lane 1 'UI strings': a React component calls t('Save') → 'i18n registry (Set of English strings)' → batched 'POST /i18n/translate' → 'SHA-256 hash' → cylinder 'UiTranslation (global cache)'; miss → 'aiClient.translateStrings (batch of 50)'. Lane 2 'Lesson content': 'POST /lessons/:id/translate' → 'extractTranslatable (branch on kind: body, PROGRAMMING description, MATH problemLatex prose, MCQ prompt+option text)' → markdown fields to 'translateMarkdown', short labels to 'translateStrings' → cylinder 'LessonTranslation (per lesson+language)'. Lane 3 'Mentor': 'buildLanguageInstruction → system prompt: reply in {language}, keep code & LaTeX verbatim'. Bottom band: 'English is always a no-op — never cached, never sent to AI'. Show a small RTL flag note: '<html dir> flips layout; code/math pinned LTR'. Hairline."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a landscape process lane diagram (viewBox="0 0 1050 650") on a white background with indigo (#6366f1) accents.
  Layout three horizontal/parallel processing paths:
  1. Lane 1: 'UI Strings Translation'
     - React t('Save') -> 'i18n registry (Set of English strings)' -> 'POST /i18n/translate (Batched)' -> 'SHA-256 hash lookup' -> cylinder 'UiTranslation (Global Cache)'. On Cache Miss -> 'aiClient.translateStrings (Batch of 50)'.
  2. Lane 2: 'Lesson Content Localization'
     - POST /lessons/:id/translate -> 'extractTranslatable (Split by challenge type: body markdown, math LaTeX, MCQ option text)' -> route markdown to 'translateMarkdown' / labels to 'translateStrings' -> cylinder 'LessonTranslation (Local Cache per Lesson + Lang)'.
  3. Lane 3: 'Mentor Localization'
     - 'buildLanguageInstruction' -> system instruction injection: 'Reply in {language}, keep code and LaTeX equations LTR & verbatim'.
  - Bottom Band: Draw a solid divider line. Text: 'English fallback is a no-op: never cached, never sent to AI providers.'
  - Side Note: A small flag icon labeled 'RTL Support: <html dir="rtl"> flips the layout; however, math formulas and code editors remain LTR.'
  Clean typography, thin border containers, and monochrome/indigo palette.
  ```

---

### 📘 Figure 17.1 — AWS Target Topology
- **Chapter**: 17 — AWS Deployment
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: AWS Cloud Architecture Diagram
- **Visual Breakdown**:
  - VPC outline with multiple tiers (Public Edge, Public Subnet, Private App, Private Worker, Data Layer).
  - AWS icons and service relationships representing the production topology.
- **Original Prompt**:
  > "A production AWS architecture diagram, dark navy background, grouped into a VPC with three subnet tiers across two AZs. **Public edge (outside VPC):** CloudFront + S3 'sigmaloop-web' + AWS WAF + ACM. **Public subnet:** a public ALB. **Private app subnet (x2 AZ):** ECS Fargate running the Express API (auto-scaled on request count). **Private worker subnet (x2 AZ):** ECS-on-EC2 Auto Scaling Group running Judge0 (server + workers, privileged) behind an internal ALB; ElastiCache Redis; RDS PostgreSQL (Multi-AZ). **Data:** Amazon DocumentDB cluster; three S3 buckets (sigmaloop-testcases, sigmaloop-generated-content, sigmaloop-submissions). **AI pipeline:** EventBridge bus → Step Functions → Lambdas (deduce-needs, generate-course, generate-lesson, generate-challenge, grade-math) → S3 + DocumentDB → SNS/Web-Push. **Egress:** NAT Gateway to the external AI provider (DeepSeek/Gemini). **Cross-cutting:** Secrets Manager, KMS, CloudTrail, GuardDuty, CloudWatch/X-Ray. Use the brand palette: indigo for compute, green for data, orange for Judge0, blue for AI. Label the ALBs, the NAT, and the S3 gateway endpoint."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a production AWS infrastructure diagram (viewBox="0 0 1100 850") on a dark navy (#0a0e1a) background.
  Draw a large bounding box: 'VPC (10.0.0.0/16)' stretching across two columns representing Availability Zones: 'AZ-A' and 'AZ-B'.
  - Public Edge (Outside VPC):
    - CloudFront -> AWS WAF + ACM -> bucket 'sigmaloop-web' (S3 static hosting).
  - Public Subnet (Both AZs):
    - Public ALB (Application Load Balancer).
  - Private App Subnet (Both AZs, Indigo accent):
    - ECS Fargate tasks running 'Express API (Auto-scaled)'.
  - Private Worker Subnet (Both AZs, Orange accent):
    - ECS-on-EC2 ASG running 'Judge0 Server & Workers (Privileged)'.
    - Internal ALB, ElastiCache Redis Cluster, RDS PostgreSQL Instance (Multi-AZ).
  - Data Tier (Green accent):
    - MongoDB-compatible Amazon DocumentDB Cluster.
    - S3 Buckets: 'sigmaloop-testcases', 'sigmaloop-generated-content', 'sigmaloop-submissions'.
  - AI Pipeline Tier (Blue accent):
    - EventBridge -> Step Functions State Machine -> Lambda Functions (deduce-needs, generate-course, generate-lesson, generate-challenge, grade-math).
  - Egress Route:
    - NAT Gateway pointing outbound to 'External AI Cloud (DeepSeek/Gemini)'.
  - Cross-cutting block at the bottom:
    - Secrets Manager, KMS, CloudWatch + X-Ray.
  Use official AWS-style flat white line-art icons. Color code: compute = indigo (#7c3aed), databases = green (#22c55e), Judge0 = orange (#f59e0b), AI = blue (#3b82f6).
  ```

---

### 📘 Figure 17.2 — Generation as a Step Functions State Machine
- **Chapter**: 17 — AWS Deployment
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: AWS Step Functions State Machine Flow
- **Visual Breakdown**:
  - Logical execution stages of the serverless state machine.
  - Map state execution path highlighting parallel execution blocks.
  - Failure/Dead-letter queue handling branch.
- **Original Prompt**:
  > "An AWS Step Functions state-machine diagram on dark navy. Trigger: 'Mentor chat persists Course (PENDING) → emits curriculum.requested to EventBridge bus'. EventBridge rule → Step Functions (Standard) with states: 'deduce-needs (Lambda) → LearningGoals JSON' → 'generate-course (Lambda) → outline' → a **Map state** 'per lesson: generate-lesson (Lambda) → generate-challenge (Lambda)' → 'persist artifacts to S3 + metadata to DocumentDB' → 'flip PENDING→READY' → 'notify via SNS / Web-Push / SSE'. Show a retry+dead-letter branch 'failed_generations'. Indigo Lambda boxes, green data writes, a clock badge on the whole machine. Hairline arrows with state labels."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate an AWS Step Functions state machine execution flow (viewBox="0 0 950 750") on a dark navy (#0a0e1a) background.
  - State Machine Start Trigger: 'EventBridge (curriculum.requested)'
  - Sequential State Steps:
    1. 'deduce-needs' (Lambda - Indigo) -> Output: LearningGoals JSON
    2. 'generate-course' (Lambda - Indigo) -> Output: Syllabus Outline
    3. Map State (Represented as a large bounding dashed box labeled 'Parallel Map State: For Each Lesson'):
       - Inner Step: 'generate-lesson (Lambda)' -> 'generate-challenge (Lambda)'
    4. 'persist artifacts' (Lambdas saving to S3 & metadata to DocumentDB - Green)
    5. 'flip state' (Update Course PENDING -> READY)
    6. 'notify learner' (Send Web-Push / SSE notification via SNS)
  - Error Handling:
    - Draw a catch/retry link from any step pointing to a red side-box: 'failed_generations (DLQ / SNS Alert)'.
  - Visual Details:
    - Standard AWS Step Function UI styles: circles for start/end nodes, rounded boxes for tasks, double-bordered box for Map state.
    - Add a clock badge overlay on the container to denote async processing. Hairline borders.
  ```

---

### 📘 Figure 18.1 — Independent Scaling Dimensions
- **Chapter**: 18 — Scaling
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: Multi-Column Comparison Grid
- **Visual Breakdown**:
  - Four vertical columns showing different system parts that scale independently.
  - Details the specific scaling triggers/signals for each component.
- **Original Prompt**:
  > "A diagram on dark navy with four independent scaling 'columns'. Column 1 'API (Fargate)': scales on ALBRequestCountPerTarget, small box growing 2→N. Column 2 'Judge0 (ECS-on-EC2 ASG)': scales on CPU + custom metric PendingSubmissions, boxes growing 2→6 t3.medium, a sidecar Lambda polling /system_info feeding a CloudWatch metric. Column 3 'Generation (Step Functions + Lambda)': scales by Map-state concurrency + Lambda concurrency, many small Lambda icons fanning out per lesson. Column 4 'Data (DocumentDB)': scales by instance size + read replicas, a green cylinder. Below, a banner: 'No app-level queue — classroom load, not contest load'. Brand palette, hairline arrows, each column labeled with its scaling signal."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate an infrastructure scaling diagram (viewBox="0 0 1000 600") on a dark navy (#0a0e1a) background.
  Draw four vertical columns side-by-side, each representing an independent scaling vector:
  1. Column 1: 'Express API (Fargate)'
     - Graphic: Small container boxes expanding horizontally (2 -> N replicas).
     - Signal: Labeled 'ALBRequestCountPerTarget'.
  2. Column 2: 'Judge0 Sandbox (ECS EC2)'
     - Graphic: Box cluster growing from 2 -> 6 instances of 't3.medium'.
     - Signal: 'CPU utilization & custom CloudWatch metric (PendingSubmissions)' fed by a sidecar Lambda polling '/system_info'.
  3. Column 3: 'Generation Pipeline (Step Functions & Lambda)'
     - Graphic: A fan-out pattern of dozens of tiny Lambda function icons.
     - Signal: 'Map-State concurrency / Lambda dynamic scaling'.
  4. Column 4: 'Database (DocumentDB)'
     - Graphic: A green database cylinder growing in volume, with read-replica cylinders next to it.
     - Signal: 'Read replicas and Instance sizing scaling'.
  - Bottom Banner: Enclosed rectangle. Text: 'Classroom Load Scaling Profile: No app-level queues required. Designed for classroom usage patterns, not instant competitive contests.'
  Maintain the brand palette (indigo compute, green databases, orange Judge0) and 1px borders.
  ```

---

### 📘 Figure 19.1 — Self-Hosted Model Serving
- **Chapter**: 19 — Self-hosted Model Serving
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: Machine Learning Serving Architecture
- **Visual Breakdown**:
  - The communication route from the backend client to a self-hosted LLM hosting endpoint.
  - Visual display of model layering (base model + LoRA weight adapter).
  - Failover route to public cloud model.
- **Original Prompt**:
  > "A serving diagram on dark navy. Left: the Express API box containing 'OwnModelAIClient'. An arrow labelled 'HTTPS, private IP, OpenAI-compatible :8000/v1/chat/completions' to a box 'EC2 g4dn.xlarge (NVIDIA T4 16GB)' containing a Docker container 'vllm/vllm-openai' with two stacked layers: 'Base: Qwen2.5-Coder-3B (fp16)' and 'LoRA adapter: sigmaloop-coder'. A dashed arrow from OwnModelAIClient down to a cloud 'Gemini (automatic fallback, 60s cooldown)'. Annotate: '~$0.53/hr on-demand; stop when idle; EBS model cache persists ~$8/mo'. Indigo API, orange GPU box, blue fallback cloud. Hairline."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate an ML model serving flow diagram (viewBox="0 0 950 550") on a dark navy (#0a0e1a) background.
  - Left Side: 'Express API Server' box containing an 'OwnModelAIClient' component (Indigo).
  - Main Path: Draw a thick secure connection arrow pointing to the right, labeled 'HTTPS (Private VPC IP) on port 8000/v1/chat/completions'.
  - Right Side: A container box representing 'EC2 Instance (g4dn.xlarge - NVIDIA T4 GPU)' (Orange border) enclosing:
    - Docker container running 'vllm/vllm-openai'. Inside, show two stacked blocks:
      - Top Block: 'LoRA Adapter: sigmaloop-coder' (Indigo accent)
      - Bottom Block: 'Base Model: Qwen2.5-Coder-3B (fp16)'
  - Fallback Path: From 'OwnModelAIClient', draw a dashed line pointing down to:
    - A blue cloud representing 'Gemini AI API (Fallback endpoint)'.
    - Label the line: 'Automatic fallback on timeout or failure (60s cooldown loop)'.
  - Bottom Annotation Box:
    - Write: 'Cost Profile: ~$0.53/hour on-demand EC2; stopped when idle; EBS volume model storage cache persists at ~$8/month.'
  Use the brand colors, flat design elements, and clean vector typography.
  ```

---

### 📘 Figure 20.1 — The Generation Agent Society
- **Chapter**: 20 — Multi-agent Future
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: Hub-and-Spoke Agent Orchestration Network
- **Visual Breakdown**:
  - A central Orchestrator node surrounded by a ring of 12 distinct specialist agents.
  - In the center sits a shared state database (Blackboard).
  - Inter-agent validation loop paths (Generator/Critic pairs).
- **Original Prompt**:
  > "An orchestration diagram on dark navy, a central 'Orchestrator' node coordinating labelled specialist agents arranged around it, with a shared 'Blackboard (structured course state)' cylinder in the middle. Agents (rounded boxes, indigo): 'Needs Analyst', 'Curriculum Architect', 'Dependency Checker', 'Lesson Author', 'Pedagogy Critic', 'Problem Author', 'Test-Case Engineer', 'Solution Verifier (runs code in Judge0)', 'Difficulty Calibrator', 'Distractor Critic', 'Coherence Auditor', 'Localization Agent'. Show generator→critic loops as small circular arrows between an author and its critic. Show the 'Solution Verifier' connected to an orange 'Judge0' box. Show a red 'escalate / dead-letter' path for items that fail their quality gate. Hairline arrows, brand palette."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a hub-and-spoke agent coordination diagram (viewBox="0 0 1000 800") on a dark navy (#0a0e1a) background.
  - Center: Draw a rounded rectangle 'Orchestrator' connected directly to a green cylinder 'Blackboard (Shared Course State)'.
  - Spoke Layout (Arrange 12 rounded indigo boxes in a ring around the center):
    1. Needs Analyst
    2. Curriculum Architect
    3. Dependency Checker
    4. Lesson Author
    5. Pedagogy Critic
    6. Problem Author
    7. Test-Case Engineer
    8. Solution Verifier
    9. Difficulty Calibrator
    10. Distractor Critic
    11. Coherence Auditor
    12. Localization Agent
  - Relationships & Loops:
    - Draw small circular/looping arrows between generator-critic pairs:
      - 'Lesson Author' <-> 'Pedagogy Critic'
      - 'Problem Author' <-> 'Distractor Critic' / 'Coherence Auditor'
    - Point an arrow from 'Solution Verifier' to a side box: 'Judge0 Sandbox' (Orange).
    - Draw a red exit arrow from the Orchestrator pointing to: 'Quality Escalation / Dead-Letter Queue (DLQ)'.
  Make it look clean, symmetrical, and technical. Use 1px hairline connectors and the brand palette.
  ```

---

### 📘 Figure 20.2 — One Verified Programming Challenge
- **Chapter**: 20 — Multi-agent Future
- **Theme**: Dark Mode (Background `#0a0e1a`)
- **Diagram Type**: Process Sequence / Loop Diagram
- **Visual Breakdown**:
  - The step-by-step lifecycle of creating and validating a single programming challenge before saving it.
  - Rejection and verification loops.
- **Original Prompt**:
  > "A sequence diagram on dark navy for generating ONE verified programming challenge. Steps: 'Problem Author → prompt + reference solution' → 'Test-Case Engineer → test set (incl. edge + hidden)' → 'Solution Verifier → submit reference solution + tests to Judge0' → decision diamond 'reference solution passes ALL its own tests?'. If NO → loop back labelled 'critique + regenerate (max N)'. If YES → 'Adversary checks for trivial solution' → 'Difficulty Calibrator confirms target' → green 'ACCEPT → persist Challenge'. Side path 'exceed N attempts → dead-letter / escalate to stronger model'. Orange Judge0 box, indigo agents, green accept, red dead-letter. Hairline."
- **Refined Claude Prompt for SVG Generation**:
  ```text
  Generate a sequence workflow diagram (viewBox="0 0 950 700") on a dark navy (#0a0e1a) background.
  Draw a horizontal process sequence from left to right:
  1. Box: 'Problem Author Agent' -> generates description & reference solution.
  2. Box: 'Test-Case Engineer Agent' -> writes verification test set (including edge and hidden cases).
  3. Box: 'Solution Verifier Agent' -> submits reference code and tests.
  4. Box (Orange): 'Judge0 API sandbox run'.
  5. Diamond: 'Did the reference solution pass all test cases?'
     - If NO: Draw an arrow looping back to step 1, labeled 'Critique & Regenerate (Max N times)' (Red/Orange).
     - If YES: Continue right.
  6. Box: 'Adversary Agent' -> checks for trivial shortcuts or cheat codes.
  7. Box: 'Difficulty Calibrator' -> matches challenge complexity to student level.
  8. Box (Green fill, white text): 'ACCEPT -> Persist Challenge to MongoDB'.
  - Edge Case: Draw a dashed path from the decision diamond leading down to:
    - Box: 'Exceeded Max Attempts -> Escalate to Stronger Model / Dead-Letter' (Red).
  Keep it clean, flat, and visually sequential using hairline connectors.
  ```

---

## 🚀 Execution & Rendering Workflow

To render these diagrams:
1. Copy the **Master System Prompt** above.
2. Select the **Refined Prompt** for the figure you want to generate.
3. Send both to Claude (e.g. in a Claude chat session with Artifacts enabled).
4. Claude will render the diagram as an interactive/viewable SVG.
5. Save the output code as an `.svg` file, or convert/render it to a `.png` file inside the `docs/figures/` folder with the file name `figure-[Chapter]-[Num].png` (e.g. `figure-02-1.png`).
6. Update the documentation links once compiled!