# Design — AI Question Paper System

**Status:** ✅ Foundation SHIPPED & PRODUCTION CERTIFIED (2026-06-25) · forward vision → [Assessment-Intelligence-Platform.md](./Assessment-Intelligence-Platform.md)

> This track note originated the question-paper module. The rollout below has been
> **built and live-certified** (see `docs/archive/completed/QUESTION_INTELLIGENCE_LIVE_CERTIFICATION.md`,
> 20/20 against the VPS pilot). The long-term architecture now lives in
> **[Assessment-Intelligence-Platform.md](./Assessment-Intelligence-Platform.md)** (Master Plan v3.0,
> locked owner decisions 2026-07-02) — consult that document for all forward planning.

## Goals (original — achieved)

Teachers generate syllabus-aligned papers (unit → annual) with review before print/PDF.

## As-built architecture

| Component | As built |
|-----------|----------|
| Syllabus boundary | `education_syllabus_boundary.ts` — hard server-side 422 on off-syllabus chapters; school syllabus first, global `subject_templates` fallback |
| Question bank | `edu_question_bank_items` — type, difficulty, marks, Bloom (`cognitive_level`), provenance, fingerprint dedup, review status |
| Generator service | Deterministic blueprint solver (`education_blueprint_solver.ts`) bank-first; constrained Claude gap-fill produces **moderation candidates only** |
| Review workflow | draft → submit → review → approve → publish; principal-only `approveEducation`; pending AI candidates hard-block publish (409) |
| Audit | Education events per paper entity; review trail in `edu_question_paper_reviews` |

## As-built permissions

| Permission | Action |
|------------|--------|
| `viewEducation` | Read bank + papers |
| `manageEducation` | CRUD bank items, generate/edit/submit papers, moderate AI candidates |
| `approveEducation` | Principal-level review, approve, publish |

(The finer-grained catalog originally sketched here was consolidated into these three;
future additions are listed in Assessment-Intelligence-Platform.md §16.2.)

## Data model (as built)

- `edu_question_bank_items` · `edu_question_papers` · `edu_question_paper_items` · `edu_question_paper_reviews`
- Migrations: `20260620000000_education_suite_foundation.sql` · `20260710000000_education_question_intelligence.sql` · `20260712000000_education_approve_permission.sql` · `20260728000000_subject_templates_tenant_read.sql`

## APIs (as built, under `/education`)

- `POST /question-papers/generate` · `GET /question-papers/:id`
- `POST /question-papers/:id/submit` · `/review` · `GET /:id/reviews`
- `POST /question-papers/:id/items/:itemId/moderate` · publish · corrections
- `GET/POST /question-bank` (+ import with fingerprint dedup)

## What comes next

The evolution — response-centric data spine, marks-grid collection, canonical concepts,
governed blueprint templates, evidence-based trust pipeline, ERP-integrated adaptive
generation — is specified in **[Assessment-Intelligence-Platform.md](./Assessment-Intelligence-Platform.md)**
with a locked Phase 1/2/3 roadmap. Do not extend this file; it is kept as the track's origin record.
