# Curriculum Intelligence — Backward Compatibility Plan

**Date:** 2026-07-06 · Companion to [`EXAM_ARCHITECTURE_AUDIT.md`](EXAM_ARCHITECTURE_AUDIT.md) and [`GAP_ANALYSIS.md`](GAP_ANALYSIS.md).
**Prime directive (spec Part 14 + v3.0 §4):** *"Preserve, never replace"* the live-certified foundation. No decision in this program may weaken a certified guarantee.

---

## 1. The invariants (certified guarantees that must survive every wave)

| # | Invariant | Enforced today by | Compatibility rule |
|---|---|---|---|
| I1 | Bank-first, deterministic generation | `education_blueprint_solver.ts` (pure) | Solver stays pure/deterministic; templates become **inputs**, never side effects (v3.0 §9.2) |
| I2 | Hard syllabus boundary — 422 `OFF_SYLLABUS` | `education_syllabus_boundary.ts` | Expanding `subject_templates` widens the *catalogue*, never bypasses the check; new boards enter through the same two-tier lookup (school chapters → global template) |
| I3 | AI output = moderation candidates only; publish blocked while pending (409 `PAPER_HAS_PENDING_ITEMS`) | gap-fill contract + publish gate | Every new AI surface (validation engine, ingestion assist, profile generation) emits **candidates/flags**, never auto-approved content |
| I4 | Safe-by-default: no API key → honest gaps, zero fabrication | gap-fill contract | Applies verbatim to all new AI calls (Part 16 golden rule) |
| I5 | Governance: draft→submit→review→approve→publish; submitter ≠ approver; principal-only `approveEducation` | `edu_question_paper_reviews` + RBAC (live-certified) | New workflow states extend, never bypass; new permissions follow the certified catalog pattern (v3.0 §16.2) |
| I6 | Exam-results integrity: AB/ML/DB = NULL marks + status codes; grace via append-only ledger; publish idempotent + audited | frozen exam-result-status design + `exam_mark_adjustments` | Paper↔exam linking (`edu_exam_paper_links`) reads exam data; it never alters marks semantics |
| I7 | Tenancy/RLS: org+school scope, `FORCE RLS`, `erp_tenant` narrow grants | every `edu_*` migration | Every new table copies the certified policy shape; global catalogues (templates, canonical concepts) follow the `subject_templates` read-grant pattern |
| I8 | Money/finance untouched | — | This program has **zero** finance surface; tier gating uses entitlement reads only |

## 2. Compatibility risk register (what could break what)

| # | Change | Risk | Mitigation |
|---|---|---|---|
| B1 | Solver upgrade (slot groups, sections, hard constraints, pagination) | Existing generate-paper API callers (Flutter + tests) see different papers for identical requests | **Template-absent ⇒ legacy path**: when no blueprint template is supplied, `planSlots`/`distributeMarks` behaviour is pinned by the existing unit tests (golden solver tests added *before* refactor). New behaviour activates only when a `blueprint_template_id` is present in the request |
| B2 | `edu_question_papers` schema additions (template FK, set_code, sections JSONB) | Client mappers break on unknown/missing fields | Additive nullable columns only; mapper contract tests on both sides; Flutter models tolerate absent fields (existing pattern) |
| B3 | Expanding `subject_templates` (classes 6–9, ICSE, versioning columns) | Syllabus wizard + boundary fallback read this table today | Additive rows + nullable `curriculum_version` columns; unique key `(board, subject_code, grade_label)` unchanged; wizard regression tests; keep the certified `erp_tenant` SELECT grant (`20260728000000`) |
| B4 | New entities (competencies, learning outcomes, concepts, blueprint templates, profile rules) | None — greenfield tables | Standard RLS shape; FKs to existing tables are nullable; no triggers on certified tables |
| B5 | Bank-item enrichment (competency tags, concept_id, D-6 lifecycle state, trust_status later) | Bank list/filter APIs | Additive nullable columns; existing rows migrate with safe defaults — **existing `active ∧ approved` rows map to `CERTIFIED`** (D-6), so the certified engine's selection behaviour ("CERTIFIED-only by default") is unchanged; v3.0 §10.2 evidence trust composes downstream of CERTIFIED in Phase 2 |
| B6 | Exam Profile Engine | Misconfigured profile could silently narrow selection | Profile = **soft weighting + validation report**, never a silent hard filter beyond the existing enum filter; incompatibilities reported pre-generation (spec Part 13 "never silently downgrade") |
| B7 | Capability gating (Part 14) | Gating a live feature could lock out the pilot school | Default-allow for existing certified capabilities; gating applies to **new** capabilities first; entitlement checks server-side beside RBAC, never replacing it |
| B8 | `edu_exam_paper_links` | id-space mismatch (TEXT exam_id vs UUID paper_id) | Link table exactly as specified in v3.0 §5.2 (exam_id TEXT matching `exam_mark_entries.exam_id`); no changes to either parent table |
| B9 | Data lane (curriculum repository) | None to the app — no app code touched | Storage isolation per D-2; `.gitignore` guard so binaries can never enter the app repo accidentally |
| B10 | PDF v2 / export formats | Schools' existing paper PDFs change appearance | Keep v1 renderer until v2 passes review; version flag on export |
| B11 *(A1)* | Concept-ID / question-family / extended metadata columns on bank items (AIMS A1-1/5/9) | Bank list/filter APIs; certification gate could delist working legacy rows | Additive nullable columns; **metadata-completeness gate applies to NEW certifications only** — existing `active ∧ approved` rows stay CERTIFIED with defaults (grandfathered, TD-CI-17); generation never requires the new fields on legacy rows |
| B12 *(A1)* | New asset tables: `edu_question_templates` (Item Models), `edu_question_families`, `edu_distractors`, `edu_diagrams` (CI-C10/C11) | None — greenfield tables | Certified RLS shape; nullable FKs to existing tables; factory/diagram outputs enter as **candidates only** through the D-6 lifecycle (I3/I4 verbatim) — nothing auto-certifies |
| B13 *(A1)* | Curriculum Boundary Engine v2 (Bloom/difficulty/outcome/competency dimensions) | Stricter validation could reject requests that pass today | Chapter-level 422 behaviour byte-identical for legacy requests; new dimensions validate **only when the request/item carries the new metadata**; boundary module extended in place, never forked |
| B14 *(A1)* | Certified Diagram Library attachment to questions/papers | Paper rendering/export changes | Diagram reference is optional; papers without diagrams render exactly as today; PDF embeds SVG only when a certified diagram is attached; diagram feature behind flag |

## 3. Migration strategy

1. **Additive-only migrations.** No column drops/renames on `edu_*`, `syllabus_*`, `subject_templates`, `exam_*` tables anywhere in this program. Follow the numbered-migration ledger convention (next free `202608xx+`).
2. **Dormant-schema pattern** (v3.0 §5.3): response-spine + trust tables ship as migrations with zero UI at the end of code-lane Phase CI-1.
3. **Flag-gated activation**: education already has `educationApiEnabledProvider`; new client surfaces follow the same per-module flag pattern; server features activate on presence of new inputs (template id, profile id) rather than global switches where possible.
4. **Certification continuity**: `scripts/qa/live_cert_question_intelligence.py` (20/20) is **extended, never replaced** — each code wave adds cases; the original 20 must stay green. EOS gate per commit (Constitution).
5. **Rollback**: every wave's rollback path documented in [`../planning/ROLLBACK_PLAN.md`](../planning/ROLLBACK_PLAN.md) — additive schema means rollback = disable flag / ignore new columns; no destructive down-migrations needed.

## 4. Explicit non-goals (locked constraints this program must respect)

- No per-student answer-sheet OCR/OMR (D2 — not pursued).
- No publisher-content dependency; no bulk republishing of copyrighted or PYQ content into school-facing banks (D8, v2.0 §25).
- No auto-published AI content of any kind (D7, I3).
- No full-app localization work (English-first decision); multilingual question content stays open owner decision O-A.
- No rebuild/replacement of the certified solver, boundary, governance, or exam-administration workflows.
- No third curriculum representation (template JSONB + materialised rows are the two; the knowledge base maps onto them).
- Nothing in this program authorizes touching the frozen FINAL_EXECUTION_MASTER_ROADMAP waves; sequencing per owner decision D-1.
- *(A1)* No copied/raster educational diagrams — ever: no textbook screenshots, no copyrighted illustrations; programmatic vector originals only (AIMS Rule 14 + P12 diagram anti-patterns).
- *(A1)* No runtime AI paper generation: the CI-C10 factory is offline/batch only; runtime assembly stays deterministic over certified assets (AIMS Rule 3/Pattern 6 — already the certified engine's behaviour).
- *(A1)* Post-CERTIFIED continuous-review automation (ACTIVE→CONTINUOUS_REVIEW→RETIRED loop, evolving quality score, teacher-feedback aggregation, student analytics) stays v3.0 Phase 2 — this program ships schema/mapping only.
- *(A1)* AIMS Part 10 (future vision) items create no scope in this program.
