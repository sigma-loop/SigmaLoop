# Graduation Project — Design Reference

This folder contains the original design documents, prototypes, and mockups for the Lambda LAP / SigmaLoop project. **This is reference material — do not modify for implementation work.**

## Contents

### Backend/
- `api.md` — Master API contract (v3.0). Defines all endpoints, request/response shapes, and auth requirements. This is the source of truth for API design.
- `Database/DB.pdf` — Database schema documentation (3 pages)
- `Database/DatabaseORM.png` — Visual ORM/entity relationship diagram

### Frontend/
A **Next.js 16 prototype** using shadcn/ui + Radix UI. This is a more polished UI prototype — not the production implementation (which lives in `/Frontend` at the repo root using React + Vite).

Key differences from production Frontend:
- Uses Next.js (app router) instead of React + Vite
- Uses shadcn/ui (40+ Radix primitives) instead of custom UI components
- Uses pnpm instead of npm
- Has IDE components (`components/ide/`) with SigmaBot AI chat widget
- Darker theme with "deep-space" color palette

### UI/
Responsive UI mockups (PNG screenshots) for all pages:
- `Auth/` — Login/signup (desktop, mobile, tablet)
- `Home/` — Landing page
- `Dashboard/` — User dashboard
- `Course/` — Course detail/syllabus
- `Catalog/` — Course browsing (called "Curriculum" in some places)
- `Lesson/` — IDE/editor view
- `Mentor/` — AI chat interface

### Other
- `Logo.png`, `Logo-1.png` — Brand assets (Sigma symbol)
- `UI.zip` — Archive of mockups

## How to Use This Folder

1. **API Design** — Reference `Backend/api.md` when implementing new endpoints or understanding expected request/response shapes
2. **Database Schema** — Reference `Database/DB.pdf` and `DatabaseORM.png` for entity relationships and field definitions
3. **UI/UX** — Reference `UI/` mockups for visual design targets
4. **Component Ideas** — Browse the Next.js prototype for advanced component patterns (especially `components/ide/` and `components/catalog/`)
