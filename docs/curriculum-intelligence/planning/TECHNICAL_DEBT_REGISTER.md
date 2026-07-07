# Curriculum Intelligence — Technical Debt Register

**Date:** 2026-07-06 · Debt **found during the audit** (pre-existing) + debt **knowingly taken** by this program's plan. Scoped to the exam/education/curriculum domain — repo-wide debt lives in [`../../TechnicalDebtRegister.md`](../../TechnicalDebtRegister.md).

---

## A. Pre-existing debt (found, verified)

| ID | Debt | Where | Impact | Proposed resolution | When |
|---|---|---|---|---|---|
| **TD-CI-1** | Legacy stub-question generator superseded by Batch 8b but still present | `education_generator.ts` (template strings, greedy fill) | Dead/misleading code beside the certified path | Confirm zero callers; delete stub paths; keep blueprint-metadata helpers that survive | CI-C1 (same files open) |
| **TD-CI-2** | Duplicate design doc: active `docs/design/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` says "Do not plan from this file" while an archived copy exists | docs tree | Doc-drift risk (violates one-doc-per-concern) | Archive the active copy; leave pointer in v3.0 | Any docs pass |
| **TD-CI-3** | Bank items carry both free-text `chapter` and `syllabus_chapter_id` FK; free text still authoritative in filters | `edu_question_bank_items` + list filters | Coverage analytics will mis-count as bank scales | FK becomes authoritative where present; backfill FKs from text via catalogue match; free text kept as display fallback | CI-C2/CI-C4 |
| **TD-CI-4** | Grade bands hardcoded (`gradeForPercent()`) | `exam_administration_repository.ts:168` | Multi-board grading (ICSE vs CBSE bands) impossible; violates config-over-hardcode (Part 16) | Config-driven grade scales (school/board-level), default = current bands | Post-M4 (not on critical path; owner may pull earlier) |
| **TD-CI-5** | Solver: 100-item selection cap, flat slots, difficulty/chapter soft-only | `education_blueprint_solver.ts` | Cannot honour real board patterns | **Resolved by CI-C1** (pagination + hard constraints) | CI-C1 |
| **TD-CI-6** | Exam id-space split: `exam_sessions` TEXT ids vs `edu_*` UUIDs; no link | both modules | Papers and marks live in separate worlds | **Bridged by CI-C8** link table (id-space split itself accepted — migration would be pilot-hostile) | CI-C8 |
| **TD-CI-7** | `subject_templates` has no version/effective-date columns; Grade-10-only seed | `subject_templates` | Continuous sync impossible; silent edition drift | **Resolved by CI-C2** versioning columns + CI-C9 sync | CI-C2/C9 |
| **TD-CI-8** | Client AI pipeline simulated + bypassed; "live" provider is a stub with misleading name | `lib/core/ai/` (edge_ai_provider) | Confusion; already flagged as audit finding AI-6 | Owned by the adaptive-AI program (P3) — tracked here for awareness only, **not this program's scope** | P3-AI-1 |
| **TD-CI-9** | Exam admin client repo has api+mock but no hybrid wrapper (education has all three) | `lib/core/repositories/api/exam_administration/` | Pattern inconsistency; offline behaviour differs | Align when exam client next opened; not education-critical | Opportunistic |
| **TD-CI-10** | Basic text-only paper PDF (no sections/branding/math) | `education_pdf_service.dart` | Unusable for real board-pattern papers | **Resolved by CI-C3** (PDF v2 on XCT-1); LaTeX/diagram rendering explicitly deferred (v3.0 v2.0-§15 timing) | CI-C3 |

## B. Debt knowingly taken by this program (with exit)

| ID | Debt taken | Why acceptable | Exit |
|---|---|---|---|
| **TD-CI-11** | Difficulty stays easy/medium/hard + cognitive_level rather than the spec's 5-level model | Evidence-based difficulty (v3.0 D6, Phase 2) will supersede labels anyway; migrating an enum twice is waste | v3.0 Phase 2 item-statistics |
| **TD-CI-12** | Semantic (vector) dedup deferred; fingerprint-only | pgvector timing locked to Phase 3 (v3.0 §16.1); fingerprint certified | v3.0 Phase 3.8 |
| **TD-CI-13** | Blueprint templates seeded for CBSE + pilot state first; other boards' templates trail their B3 transcription | Critical path G1 must not wait on 4-board acquisition | CI-B3 increments per board |
| **TD-CI-14** | Dormant schema (CI-E1) ships unused tables | Owner-locked v3.0 §5.3 rationale: data cannot be backfilled | Activated by v3.0 Phase 2 |
| **TD-CI-15** | DOCX/HTML export may ship after PDF v2 + JSON if CI-C3 overruns | PDF + JSON cover print + machine needs; DOCX is convenience | Post-M5 backlog item |
| **TD-CI-16** | Live-cert extensions staged locally while the live lane is owner-deferred | Same posture as the rest of the frozen roadmap (R13) | Live lane opening |
| **TD-CI-17** *(A1)* | Legacy certified bank rows grandfathered under the AIMS metadata-completeness mandate (missing concept ID, family, quality score, license fields) | Blocking would delist the pilot's working bank; completeness is enforced for **new** certifications only (A1-9/A1-O3) | Backfill via CI-C4 tagging + Phase-2 concept mapping |
| **TD-CI-18** *(A1)* | Post-CERTIFIED lifecycle states (`ACTIVE → CONTINUOUS_REVIEW → RETIRED`) + evolving quality score recorded as schema/mapping only; the automation loop is not built | Needs the response spine + usage signals (v3.0 Phase 2, E1a seed) — building it now would violate D11 | v3.0 Phase-2 trust pipeline |

## Rules

- New debt requires a row here **at the moment it is taken** (wave checklist enforces).
- Every row names its exit — debt without an exit is a decision, and decisions belong to the owner queue.
