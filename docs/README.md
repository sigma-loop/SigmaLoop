# SigmaLoop — The Complete Technical Documentation

> **"Master the Logic behind the Code."**
>
> This `docs/` folder is a full, book-length engineering reference for SigmaLoop —
> a personalized AI tutor for programming and mathematics. It is written to be read
> cover-to-cover **or** dipped into chapter-by-chapter, and to be exported as a
> single ~100-page PDF.

---

## What this is

A single, authoritative book covering SigmaLoop from the smallest building block
(a Mongoose field, a React hook) up to the largest system-design question (how to run
the whole platform on AWS at scale, and how to evolve the generation pipeline into a
society of specialized AI agents).

It pays special, deep attention to the four subsystems that make SigmaLoop interesting:

1. **The AI course / lesson / challenge generation pipeline** — Chapter 12
2. **The translation (i18n / localization) pipeline** — Chapter 15
3. **The judging & evaluation system** (Judge0, LLM math grading, deterministic MCQ) — Chapter 14
4. **Deploying and scaling all of this on AWS** — Chapters 16–19
5. *(Forward-looking)* **Re-architecting generation as a multi-agent system** — Chapter 20

Everything is grounded in the actual source: chapters cite real files and line
numbers (e.g. `Backend/src/services/curriculumWorker.ts:207`) so the book stays
honest and navigable. Where the code and the older design docs disagree, the book
says so in an **Implementation Note**.

---

## How to read it

The book is split into one Markdown file per chapter under [`book/`](./book), numbered
so they sort into reading order:

| # | Chapter | Theme |
|---|---------|-------|
| — | [`00-cover.md`](./book/00-cover.md) | Cover, abstract, how to read |
| 01 | [Introduction & Product Vision](./book/01-introduction.md) | What SigmaLoop is and why |
| 02 | [System Architecture Overview](./book/02-architecture-overview.md) | The 10,000-foot view |
| 03 | [Codebase Tour](./book/03-codebase-tour.md) | Where everything lives |
| 04 | [Data Models](./book/04-data-models.md) | The domain model reference |
| 05 | [The API Surface](./book/05-api-reference.md) | Every endpoint, JSend, conventions |
| 06 | [Authentication, Authorization & Security](./book/06-auth-security.md) | JWT, roles, ownership, hardening |
| 07 | [Configuration & Runtime Settings](./book/07-config-runtime-settings.md) | The live-tunable config overlay |
| 08 | [Frontend Architecture](./book/08-frontend-architecture.md) | SPA, routing, state, services |
| 09 | [The Challenge Workspaces](./book/09-challenge-workspaces.md) | Monaco / MathLive / MCQ |
| 10 | [The Design System](./book/10-design-system.md) | Clean/technical UI language |
| 11 | [The AI Provider Abstraction](./book/11-ai-provider-abstraction.md) | DeepSeek + Gemini behind one interface |
| 12 | **[The Generation Pipeline](./book/12-generation-pipeline.md)** | **★ Focus** — courses → lessons → challenges |
| 13 | [The Autonomous Mentor](./book/13-mentor-agent.md) | Tool-using `[[ACTION]]` agent |
| 14 | **[The Judging & Evaluation System](./book/14-judging-evaluation.md)** | **★ Focus** — three graders |
| 15 | **[The Translation Pipeline](./book/15-translation-pipeline.md)** | **★ Focus** — AI i18n + RTL |
| 16 | [Local Development & Docker](./book/16-local-dev-docker.md) | The dev stack |
| 17 | **[AWS Deployment Architecture](./book/17-aws-deployment.md)** | **★ Focus** — the cloud target |
| 18 | **[Scaling Strategy](./book/18-scaling.md)** | **★ Focus** — autoscaling the judge & pipeline |
| 19 | [Self-Hosting the Fine-Tuned Model](./book/19-self-hosted-model.md) | EC2 + vLLM + Qwen |
| 20 | **[A Society of Agents](./book/20-multi-agent-future.md)** | **★ Focus** — the agentic redesign |
| A | [Appendix A — API Reference Tables](./book/appendix-a-api-tables.md) | Quick endpoint lookup |
| B | [Appendix B — Environment Variables](./book/appendix-b-env-vars.md) | Every env / setting |
| C | [Appendix C — Glossary](./book/appendix-c-glossary.md) | Terms & acronyms |
| D | [Appendix D — Figure & Diagram Index](./book/appendix-d-figures.md) | Every placeholder, in one place |

If you only have an hour, read **01 → 02 → 12 → 14**. That is the heart of the system.

---

## Figures, screenshots & diagrams

This book is illustration-ready but ships with **placeholders** instead of binary
images, so it stays diff-able in git. There are two kinds of placeholder, and they
look like this everywhere in the text:

**A screenshot to capture from the running app:**

> 📸 **FIGURE 9.1 — Lesson workspace (PROGRAMMING mode)**
> *Screenshot placeholder.* **Capture:** `/lessons/:id` with the Monaco editor on the
> left and the Output panel showing a passed/failed test run on the right.

**A diagram to generate with an image model** (the prompt is written for you — paste it
into Claude's image generation / "Claude design"):

> 🎨 **FIGURE 2.1 — The four-layer architecture**
> *Diagram — generate with Claude image generation.* **Prompt:**
> "A clean, technical 4-layer system architecture diagram on a dark navy background…"

Every placeholder carries a stable **figure number** and is collected in
[Appendix D](./book/appendix-d-figures.md). When you produce a real asset, drop it in
[`figures/`](./figures) and replace the placeholder blockquote with a normal Markdown
image. See [`figures/README.md`](./figures/README.md) for the full convention.

---

## Building the PDF

No PDF toolchain is bundled (and none is required to *read* the book). When you want a
single PDF, run the helper script — it auto-detects whatever converter you have:

```bash
cd docs
./build-pdf.sh            # writes docs/SigmaLoop-Documentation.pdf
```

`build-pdf.sh` tries, in order:

1. **pandoc** (+ a LaTeX engine) — best output, real chapter breaks & ToC.
2. **`npx md-to-pdf`** — needs only Node (downloads a headless Chromium once).
3. **weasyprint** — if installed.

If none is available it concatenates every chapter into one
`SigmaLoop-Documentation.md` and tells you how to convert it. Install the easiest path
with one of:

```bash
# Debian/Ubuntu — best quality
sudo apt-get install pandoc texlive-xetex

# Or Node-only, zero system installs
npm i -g md-to-pdf
```

---

## A note on accuracy

This documentation was produced by reading the codebase directly, subsystem by
subsystem. It deliberately surfaces the places where reality diverges from the
aspirational design (disabled rate-limiters, a hard-coded API URL, the
DeepSeek-vs-"Gemini-only" drift in the older hosting proposal, legacy collection
names like `lambda_lap`). Those are flagged as **Implementation Notes** rather than
hidden — a documentation set that lies about the code is worse than none.
