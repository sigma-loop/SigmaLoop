# Claude Design UI Reference Guide — SigmaLoop Figures

This document maps the visual figures from the SigmaLoop technical book into detailed UI specifications. It serves as a guide for rebuilding or prototyping these user interfaces in **Claude Design** (React + CSS/Tailwind) with exact layout structures, states, styling rules, and mock data.

---

## 🎨 Global Design Tokens (The SigmaLoop Aesthetic)
For maximum fidelity, all designs should adhere to the following design system tokens:
* **Palette**: Sleek dark/light monochrome + Indigo primary accent.
  * **Light Theme Background**: `bg-white` / `bg-gray-50`
  * **Dark Theme Background**: `bg-[#0d1117]` (Github Dark) / `bg-[#161b22]` (Card Dark)
  * **Accents**: Indigo (`text-indigo-600`, `bg-indigo-600`), Emerald for success (`text-emerald-500`), Amber for warning/pending (`text-amber-500`).
* **Typography**: Clean, geometric sans-serif (e.g., *Inter* or *Outfit*). High contrast headers.
* **Layouts**: Flat, borders-only cards (`border border-gray-200 dark:border-gray-800`), glassmorphism overlays, and thin, custom scrollbars (`sample-scroll`).

---

## 📂 Figure Layout Breakdowns & Specs

### 1. Figure 1.1 — The Mentor Chatbot in Action
* **Page Route**: `/mentor?thread=60d5ec49f323e2001c8b45bb`
* **Purpose**: Demonstrates the AI assistant executing background operations autonomously via the JSON protocol.
* **UI Specs**:
  * **Sidebar**: List of previous chat threads with a "New Thread" button.
  * **Main Chat Pane**: Thread container with a vertical scroll of messages.
  * **Autonomous Action Row (`MentorActionRow`)**:
    * A green-tinted card (`bg-emerald-500/10 border border-emerald-500/20`) showing a timeline of tools being executed.
    * Progress items: *"Analyzing syllabus..."* (checked), *"Creating lessons..."* (checked), *"Started generating a new course..."* (active).
    * Action control button: *"Generating... → Open course"* (which transitions from disabled to a green active link).
  * **Input box**: Textarea with send button and microphone icon.
* **Mock Data**:
  * Assistant response: *"I've analyzed your onboarding answers. I am now generating a custom course on Big O notation. Here's my progress:"*

---

### 2. Figure 8.1 — Landing Page Hero
* **Page Route**: `/`
* **Purpose**: Marketing entry point showing the unique language translation highlights.
* **UI Specs**:
  * **Header**: Glassmorphism navbar, logo, language selector dropdown (English / Spanish / Japanese), "Login" button.
  * **Hero Section**:
    * Tagline with `[[logic]]` highlighted terms.
    * Interactive chat input preview (a mockup of the chatbot input to drive engagement).
    * CTA buttons: "Start Learning" (primary Indigo) and "Talk to Assistant" (secondary ghost).

---

### 3. Figure 8.2 — Student Dashboard
* **Page Route**: `/dashboard`
* **Purpose**: The core user panel with gamification statistics and resume cards.
* **UI Specs**:
  * **Stat Cards Row**: Three metric panels:
    * **Streak**: Flame icon + "7 Days" (emerald accent).
    * **XP**: Sparkles icon + "1,250 XP".
    * **Lessons Completed**: BookOpen icon + "12 Lessons".
  * **Resume Learning Section**: Large card showing the active course (*"Introduction to Python"*), progress bar at 64%, and a "Resume Lesson 4" button.
  * **Course Grid**: Flat card list with difficulty badges (Beginner, Intermediate, Advanced) and completion percentages.

---

### 4. Figure 8.3 — Onboarding Topic Selection & Questionnaire Wizard
* **Page Route**: `/onboarding`
* **Purpose**: Step-by-step course builder questionnaire.
* **UI Specs**:
  * **Stepper Bar**: Four dots indicating progress (1. Topics ➔ 2. Profile ➔ 3. AI Questions ➔ 4. Building).
  * **Topic Grid (Step 1)**: Flat cards representing topics (e.g., *"Algorithms"*, *"Web Development"*, *"Machine Learning"*). Selected topics carry a thick indigo border and a checkmark badge.
  * **Skeleton Generation Screen (Step 4)**: Loading skeleton screens and a circular spinner representing the backend syllabus compilation.

---

### 5. Figure 8.4 — My Courses Grid
* **Page Route**: `/my-courses`
* **Purpose**: Overview of all generated and generating courses.
* **UI Specs**:
  * **Header**: "My Courses" title + Amber CTA button: *"Learn a New Thing!"* (pointing to onboarding).
  * **Course Grid**:
    * **Active Course Card**: Details, progress bar, and "Resume" button.
    * **In-Flight Job Card**: Shows a loading indicator, text *"Syllabus generating... 45%"*, and a progress bar.
    * **Failed Job Card**: Red border, text *"Generation failed"*, and a "Retry" button.

---

### 6. Figure 8.5 — Course Syllabus & Details
* **Page Route**: `/courses/:id`
* **Purpose**: Course structure inspector and gating configuration.
* **UI Specs**:
  * **Header**: Course Title, description, and "Delete Course" button.
  * **Configuration Panel**: A toggle switch for Lock Mode:
    * **PROGRESS** (gated — lock icons on subsequent lessons).
    * **VIEW_ALL** (unlocked — checkmarks or open book icons).
  * **Syllabus List**: Vertical stack of lessons. Done lessons display a green check; locked lessons display a gray padlock; active lessons display an interactive arrow.

---

### 7. Figure 8.6 — User Settings Tab Panel
* **Page Route**: `/settings`
* **Purpose**: Student profile modifications.
* **UI Specs**:
  * **Layout**: Left vertical tab navigation (Account, Security, Language, Notifications, Privacy, Danger Zone).
  * **Content Panel (Notifications/Privacy)**:
    * Inline toggles for email notifications and profile visibility.
    * **Danger Zone**: Red border card with button "Delete Account". Clicking triggers a modal requiring password confirmation.

---

### 8. Figure 8.7 — Admin Command Center & Runtime Settings
* **Page Route**: `/admin/settings`
* **Purpose**: System-wide configuration changes and performance metrics.
* **UI Specs**:
  * **Layout**: Left admin navigation sidebar.
  * **Metrics Panel**: High-level charts (User signups, generated courses, Judge0 execution queue length).
  * **Settings Grid**: A tabular list of runtime settings:
    * Key names (e.g., `ai.model.primary`, `judge.timeout`).
    * Configured tag badges: *"Overridden"* (blue) or *"Restart required"* (amber).
    * Inline controls: Text fields, dropdown menus, and toggle switches.
    * "Save" and "Reset to default" buttons.

---

### 9. Figure 9.2 & 14.2 — Graded Programming Workspace
* **Page Route**: `/lessons/:lessonId` (Active Programming tab)
* **Purpose**: Code editor with test case execution panels.
* **UI Specs**:
  * **Monaco Editor Pane (Top 60%)**: Dark theme code pane displaying student Python/JS code.
  * **Output Panel (Bottom 40%)**:
    * A header showing status (*"3/4 Test Cases Passed"*), memory, and execution time.
    * Accordion list of test cases. **Passed test cases** are green and collapsed. **Failed test cases** are expanded, showing:
      * Input: `[5, 3]`
      * Expected: `8`
      * Actual: `15` (highlighted in red diff).
      * Stderr: Empty or debug log.

---

### 10. Figure 9.3 & 14.3 — Math Equivalence Workspace & LLM Grader Verdict
* **Page Route**: `/lessons/:lessonId` (Active Math tab)
* **Purpose**: Rich visual editor for formula input and dynamic verdict evaluations.
* **UI Specs**:
  * **MathLive Editor Pane (Top 55%)**: LaTeX math input area with a virtual floating math keyboard overlay (fractions, roots, symbols).
  * **Verdict Panel (Bottom 45%)**:
    * Renders evaluation result banner: *"Correct (Equivalent Form)"* in green, or *"Pending review (Low Confidence)"* in amber.
    * Explanatory text card: Renders the LLM grading rationale with mathematical terms compiled using KaTeX.
    * Badge showing remaining attempts: *"7 / 10 remaining runs"*.

---

### 11. Figure 9.4 — MCQ Reveal Workspace
* **Page Route**: `/lessons/:lessonId` (Active Quiz tab)
* **Purpose**: Multiple choice question display, showing post-submission correctness highlights.
* **UI Specs**:
  * **Question Header**: Prompt text in markdown (e.g., *"Which of the following are true about bubble sort? Select all that apply."*).
  * **Options List**: Checkbox list where options are colored based on submission:
    * **Correct option, selected**: Green background + checkmark + explanation tooltip.
    * **Incorrect option, selected**: Red background + crossmark + correction details.
    * **Correct option, unselected**: Green dashed border.
  * **Summary Banner**: *"Partially correct (1/2 correct options selected)"* in yellow.

---

### 12. Figure 9.5 — Challenge Tabs
* **Page Route**: `/lessons/:lessonId` (Top bar)
* **Purpose**: Sub-navigation across multiple lesson challenges.
* **UI Specs**:
  * **Tabs Row**: A slim horizontal tab-strip at the top of the IDE:
    * Tab 1: Code icon + "Challenge 1" + green check.
    * Tab 2: Calculator icon + "Challenge 2" (active).
    * Tab 3: ListChecks icon + "Challenge 3".

---

### 13. Figure 10.1 — Design System Showcase Primitives
* **Page Route**: `/design-system`
* **Purpose**: Showcase grid displaying components side-by-side.
* **UI Specs**:
  * Split grid showing light theme on the left and dark theme on the right.
  * **Primitives Grid**:
    * **Buttons**: Solid, Outline, Ghost, Disabled, Icon variants.
    * **Badges**: Success (emerald), Warning (amber), Danger (red), Info (blue).
    * **Cards**: Plain card, glassmorphic card, selected card.
    * **Form Elements**: Text input with placeholder, input with warning highlight, toggle switch.
