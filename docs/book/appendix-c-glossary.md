# Appendix C — Glossary

Terms, acronyms, and SigmaLoop-specific concepts, alphabetically.

**`[[ACTION: {…}]]` protocol** — the plain-text JSON marker the autonomous mentor emits to
call a tool. Chosen over native function-calling so the tool transcript survives a
mid-conversation DeepSeek↔Gemini failover. See Chapter 13.

**AIClient** — the single TypeScript interface every model call goes through
(`services/ai.service.ts`). The swap point for providers. Chapter 11.

**Anchor kind** — in a practice (challenge-only) lesson, the one non-MCQ challenge kind,
chosen by the course's nature (`language ? PROGRAMMING : MATH`). Chapter 12.

**Blackboard** — (Chapter 20, proposed) the shared structured state a society of generation
agents reads from and writes to.

**Challenge** — a graded task inside a lesson. Discriminated by `kind` into PROGRAMMING,
MATH, MCQ. Chapter 4.

**ChallengeOnly lesson** — a lesson with no teaching body, just challenges (a "practice"
lesson). Chapter 12.

**CurriculumJob** — the async job document that drives generation. Types: NEW_COURSE,
EXTEND_COURSE, GENERATE_CHALLENGES. Chapters 4, 12.

**Discriminator** — a Mongoose mechanism for polymorphic documents sharing a base schema.
Used for `Challenge` and `Submission`, keyed on `kind`. Chapter 4.

**DocumentDB** — AWS's MongoDB-compatible managed database; the proposed production app
database (with MongoDB Atlas as fallback). Chapter 17.

**effectiveStreak** — the *display* streak value: the stored streak only if the last
activity was today or yesterday, else 0. Chapter 14.

**FallbackAIClient** — the composer that tries DeepSeek, then (on failure, with a 60s
cooldown) Gemini. Chapter 11.

**Isolate** — the sandbox Judge0 uses to run untrusted code; needs cgroups + privileged
mode, which forces Judge0 onto EC2 in production. Chapters 16–17.

**JSend** — the response envelope: `{ success, data }` or `{ success, message, code,
details }`. Chapter 5.

**Judge0** — the open-source code-execution sandbox that grades PROGRAMMING challenges by
running AI-generated test cases. Chapters 14, 16.

**Lazy materialization** — generating a lesson's body and challenges on first open rather
than up front; the core of the generation pipeline's efficiency. Chapter 12.

**LearnerProfile** — (Chapter 20, proposed) the structured output of a Needs-Analyst agent.

**LessonProgress** — the per-(user, lesson) completion record; a lesson is complete only
when all its challenges are PASSED. Chapter 14.

**LoRA adapter** — a small fine-tuning layer on a base model; the self-hosted Qwen model is
a LoRA on Qwen2.5-Coder. Chapter 19.

**MathLive** — the WYSIWYG math editor (`<math-field>`) used for MATH challenges; emits
LaTeX. Chapter 9.

**MCQ** — multiple-choice question; graded deterministically by set-equality of option ids.
Chapters 4, 14.

**MentorAction** — an append-only audit-log entry for a mutation the mentor performed.
Chapters 4, 13.

**Monaco** — the code editor (the engine behind VS Code) used for PROGRAMMING challenges.
Chapter 9.

**Onboarding questionnaire** — the hybrid entry flow: pick static topics, then AI-tailored
follow-ups, then a generation job. Chapter 12.

**PENDING_REVIEW** — the submission status for a math grade the LLM produced with
confidence < 0.7; counts as neither pass nor fail. Chapter 14.

**Proxy (AI client)** — the JavaScript `Proxy` wrapping the active AI client so it can be
hot-swapped at runtime when settings change. Chapters 7, 11.

**Reasoner** — DeepSeek's stronger, slower model (`deepseek-reasoner`); used to *author*
hard challenges, never to grade. Chapter 11.

**Runtime settings overlay** — the system that mutates the live `config` object in place
from admin-saved overrides, with no redeploy. Chapter 7.

**Scope (chat)** — a thread's context: GENERAL, COURSE, or LESSON. Changes the mentor's
context, not its tools. Chapter 13.

**Set-equality** — the deterministic MCQ grading rule: the chosen option-id set must equal
the correct set exactly. Chapter 14.

**Stub** — a lesson written as a cheap placeholder (title + summary + challenge specs, no
body, no challenges) pending lazy materialization. Chapter 12.

**Step Functions** — AWS's workflow orchestrator; the production replacement for the
in-process generation worker. Chapters 17, 20.

**Student-safe serialization** — stripping every answer (solutions, hidden tests, MCQ
correctness) from student-facing reads via `challengeSerializer.ts`. Chapters 6, 14.

**Verification by execution** — (Chapter 20, proposed) accepting a generated programming
challenge only after running its reference solution against its own test cases in Judge0.
