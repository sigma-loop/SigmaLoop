# Appendix D — Figure & Diagram Index

Every figure in the book, in one place — the checklist of art still to produce. Two types:
**📸 Screenshot** (capture from the running app) and **🎨 Diagram** (generate from the
written prompt in the chapter, or render the referenced Mermaid source). See
[`../figures/README.md`](../figures/README.md) for the workflow and the brand palette.

| Fig | Type | Chapter | Subject |
|-----|------|---------|---------|
| 0.1 | 🎨 | Cover | Book cover art |
| 1.1 | 📸 | 1 — Introduction | The mentor in action (action row + "Generating → Open course") |
| 2.1 | 🎨 | 2 — Architecture | The four-layer architecture |
| 2.2 | 🎨 | 2 — Architecture | Mentor chat → async curriculum generation |
| 4.1 | 🎨 | 4 — Data Models | Entity-relationship diagram |
| 7.1 | 🎨 | 7 — Config | The runtime settings overlay |
| 8.1 | 📸 | 8 — Frontend | Landing page hero |
| 8.2 | 📸 | 8 — Frontend | Returning-user dashboard |
| 8.3 | 📸 | 8 — Frontend | Onboarding wizard (topic-pick + generating) |
| 8.4 | 📸 | 8 — Frontend | My Courses (mixed statuses + empty state) |
| 8.5 | 📸 | 8 — Frontend | Course syllabus (lock-mode toggle) |
| 8.6 | 📸 | 8 — Frontend | Settings (toggles + delete-account modal) |
| 8.7 | 📸 | 8 — Frontend | Admin Command Center & runtime Settings |
| 9.1 | 🎨 | 9 — Workspaces | The kind-dispatched workspace |
| 9.2 | 📸 | 9 — Workspaces | Programming workspace (Monaco + Output) |
| 9.3 | 📸 | 9 — Workspaces | Math workspace (MathLive + verdict) |
| 9.4 | 📸 | 9 — Workspaces | MCQ workspace, post-submit coloring |
| 9.5 | 📸 | 9 — Workspaces | Multi-challenge lesson (ChallengeTabs) |
| 10.1 | 📸 | 10 — Design System | The component library (light + dark) |
| 12.1 | 🎨 | 12 — Generation | The lazy generation pipeline |
| 13.1 | 🎨 | 13 — Mentor | The mentor tool loop |
| 14.1 | 🎨 | 14 — Judging | Three graders, one progress engine |
| 14.2 | 📸 | 14 — Judging | A graded programming submission |
| 14.3 | 📸 | 14 — Judging | A math verdict (equivalent form) |
| 15.1 | 🎨 | 15 — Translation | The translation pipeline |
| 17.1 | 🎨 | 17 — AWS | AWS target topology |
| 17.2 | 🎨 | 17 — AWS | Generation as a Step Functions state machine |
| 18.1 | 🎨 | 18 — Scaling | Independent scaling dimensions |
| 19.1 | 🎨 | 19 — Self-hosted | Self-hosted model serving |
| 20.1 | 🎨 | 20 — Multi-agent | The generation agent society |
| 20.2 | 🎨 | 20 — Multi-agent | One verified programming challenge |

**Totals:** 31 figures — 19 diagrams (🎨, prompts ready to paste into an image model) and
12 screenshots (📸, to capture from the running app).

## Existing Mermaid sources

Several diagrams in Chapters 17–18 correspond to **Mermaid** source that already exists
inside `Hosting SigmaLoop/README.md` (and the Repovive reference in `Hosting Judge/README.md`)
— the overall AWS topology, the generation state machine, the submission sequence, the
deployment Gantt, and the Judge0 autoscaling loop. Those can be rendered directly with
`mmdc` (mermaid-cli) or any Mermaid live editor instead of an image model, then dropped in
as `figure-17-1.png`, etc. The `architecture-diagram-spec.md` at the repo root also carries
the ASCII version of Figure 2.1 and the full brand-colour styling guide.
