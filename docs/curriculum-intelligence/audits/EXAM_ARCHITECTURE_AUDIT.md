# Curriculum Intelligence — Exam Architecture Audit

**Program:** Curriculum Intelligence Pipeline (spec: [`../spec/MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md`](../spec/MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md))
**Date:** 2026-07-06 · **Author:** Chief-architect audit (code-verified, not assumed)
**Method:** four parallel code/schema/docs exploration sweeps over `supabase/functions/_shared/`, `supabase/migrations/` (170 files), `lib/`, and `docs/` — every claim below was verified against source.
**Governing prior art:** 🔒 [`Assessment-Intelligence-Platform.md`](../../Vision/design/Assessment-Intelligence-Platform.md) (Master Plan v3.0, locked owner decisions D1–D11, 2026-07-02) · live baseline [`QUESTION_INTELLIGENCE_LIVE_CERTIFICATION.md`](../../archive/completed/QUESTION_INTELLIGENCE_LIVE_CERTIFICATION.md) (20/20, 2026-06-25).

---

## 1. Headline verdict

Akshara does **not** start this program from zero. Two production subsystems already exist:

1. **Exam Administration** (`supabase/functions/_shared/academics/exam_administration/`) — exam sessions, scheduling, marks entry, grace/moderation ledger, seating, hall tickets, tabulation/merit/report cards, verify→publish lifecycle. Live in the pilot.
2. **Education / Question Intelligence** (`supabase/functions/_shared/education/`) — question bank, deterministic blueprint solver, constrained AI gap-fill (moderation candidates only), submit→review→approve→publish governance, syllabus-boundary enforcement. **Production-certified 20/20** against the VPS (real auth/DB/RBAC/AI).

They live in **separate id-spaces** (`exam_sessions` uses TEXT ids; `edu_*` uses UUIDs) and are **not linked** — the single biggest architectural seam this program must close (v3.0 item 1.7, `edu_exam_paper_links`).

The pipeline spec's Parts 12–14 (paper generation, profiles, backward compatibility) therefore describe an **extension of a certified engine**, not a greenfield build. The genuinely greenfield portion is Parts 02–09: the **curriculum data platform** (acquisition, repository, metadata, knowledge extraction) — nothing of that kind exists anywhere in the repo.

---

## 2. Existing features (verified inventory)

### 2.1 Question Intelligence engine (backend)

| Component | File | Verified behaviour |
|---|---|---|
| Router | `education_router.ts` (212 ln) | `/education/question-bank/*`, `/question-papers/*`, `/homework/*`, `/report-remarks/*` |
| Handlers | `education_handlers.ts` (1176 ln) | RBAC 3-gate (`viewEducation`/`manageEducation`/`approveEducation`), audit, syllabus boundary |
| Repository | `education_repository.ts` (1225 ln) | bank CRUD/import w/ fingerprint dedup, paper lifecycle, publish gate, promote-to-bank |
| **Blueprint solver** | `education_blueprint_solver.ts` (201 ln) | Pure/deterministic: `planSlots` (≈1 Q per 5 marks, bounded 4–30, or explicit `questionTypeMix`), `distributeMarks` (sums **exactly** to totalMarks), bank-first fill, honest `gaps` for unfillable slots |
| AI gap-fill | `education_ai_question_gapfill.ts` (216 ln) | Constrained Claude call for gap slots only; per-candidate validation; `source='ai_candidate'`, `review_status='pending'`; **safe-by-default** (no key → honest gaps, zero fabrication) |
| Syllabus boundary | `education_syllabus_boundary.ts` (139 ln) | Hard 422 `OFF_SYLLABUS`; school `syllabus_chapters` first, global `subject_templates` fallback |
| Fingerprint | `education_fingerprint.ts` | Deterministic dedup hash (subject+chapter+type+text) |
| Orchestration | `education_question_paper_service.ts` (295 ln) | bank → solver → gap-fill → draft; single-item regeneration |
| AI client | `_shared/ai/anthropic_client.ts` (225 ln) | Provider-agnostic `callClaude()` (Anthropic direct / OpenRouter), admin-panel key/model resolution (`ai_settings.ts`), refusal detection |

### 2.2 Data model (migrations, verified)

- **`edu_question_bank_items`** (`20260620000000` + `20260710000000`): subject/chapter/topic, difficulty, `question_type` (mcq/fill_blank/match/short_answer/long_answer/diagram), marks, options, **`source`** (teacher/school/import/**pyq**/**publisher**/ai_candidate), `source_reference`, **`program_track`** (board/jee_foundation/neet_foundation/ntse/olympiad), **`jee_question_type`** (single_correct/…/comprehension), **`cognitive_level`** (remember/understand/apply/analyze/hots — the Bloom model), **`syllabus_chapter_id`/`syllabus_topic_id` FKs**, `learning_outcome` TEXT, `fingerprint`, `review_status`.
- **`edu_question_papers`**: chapters JSONB, difficulty, total_marks, exam_type (unit_test…annual), **`blueprint` JSONB**, answer_key JSONB, `program_track`, `review_status` lifecycle (draft/submitted/changes_requested/approved/published/archived), submitted_by/at, approved_by/at.
- **`edu_question_paper_items`**: bank FK, `source` (bank/ai_generated/ai_candidate), per-item `review_status` for moderation.
- **`edu_question_paper_reviews`**: governance trail (round, status, reviewer, comments).
- **Curriculum taxonomy:** `subject_templates` (global board catalogue, chapters JSONB per grade — **Grade-10 CBSE + AP/TS SSC really seeded** in `20260711000000_grade10_curriculum_seed.sql`), `academic_subjects`, `syllabus_chapters`, `syllabus_topics`, `syllabus_generations`, `syllabus_topic_completions`, class/teacher subject assignments.
- **Exam administration:** `exam_sessions` (phase: draft→scheduled→marks_entry→processed→published, coordinator verification), `exam_mark_entries` (+ `effective_marks`, AB/ML/DB status per the frozen exam-result-status design), `exam_mark_adjustments` (append-only grace ledger), `exam_seating_assignments`, `exam_remarks` (history JSONB), `exam_timetable_entries`, `intel_exam_intelligence_snapshots` (weak chapters, forecasts — computed, not LLM).

### 2.3 Flutter client

- `lib/features/education/` — 4-tab screen (Papers · Bank · Homework · Remarks), paper detail with AI-candidate moderation, bank item form **tagged to syllabus chapters** (`syllabusChaptersProvider`), bank import sheet, PDF export, `_allowAiGapFill` toggle. Models mirror backend enums (EduCognitiveLevel, EduProgramTrack).
- `lib/features/school_completion/` — syllabus wizard (auto-generate/clone), academic progress, chapter/topic completion tracking.
- Exam admin/teacher/student/parent exam slices + `lib/features/intelligence/exam/`.
- Canonical repository pattern for any new module: interface → mock → `api/<module>/{remote,mapper,api,hybrid}` → flag-switched provider (`repository_providers.dart:436` is the education reference implementation).

### 2.4 RBAC, audit, tenancy (platform invariants)

- Permissions: `viewEducation`/`manageEducation`/`approveEducation` (education) + 7 granular exam permissions with SoD (submit ≠ verify ≠ publish); `moderateExamMarks`.
- Audit: `educationAudit.*` + `examAudit.*` catalogs; publish is idempotency-keyed and non-reversible; anti-tamper test exists (`qa_x_033`).
- Tenancy/RLS: every table `organization_id`+`school_id`, `FORCE ROW LEVEL SECURITY`, `app_current_*()` GUC helpers, `erp_tenant` NOBYPASSRLS role, narrow grants.
- Subscription primitives exist: `subscription_plans`, `plan_entitlements`, `platform_feature_enablements` (capability gating pattern certified in B2).

---

## 3. Missing features (definitive NOT-FOUND, code-verified)

| # | Missing | Spec ref | Notes |
|---|---|---|---|
| M1 | Curriculum repository + acquisition pipeline (downloads, verification, PM files, logs, reports) | Parts 02–07 | Nothing exists — no `resources/`, no download tooling, no coverage tracking |
| M2 | Resource metadata + index architecture (Resource IDs, checksums, master/secondary/search indexes) | Part 08 | Nothing exists |
| M3 | Knowledge-base extraction (chapter/topic/outcome/competency objects from documents) | Part 09 | `subject_templates.chapters` JSONB is the only structured curriculum, seeded for Grade 10 only |
| M4 | **Competency as a named entity** | Parts 09–13 | NOT FOUND anywhere (closest: `cognitive_level`, `learning_outcome` free text) |
| M5 | Question extraction from documents (PDF/OCR ingestion → Question Objects) | Part 10 | Bank import exists (structured import w/ dedup) but no document/OCR pipeline |
| M6 | Independent AI Validation Engine (second-reviewer, quality scoring, blind-solve answer verification) | Part 11 | Today: schema validation + human moderation only (= v3.0 §11 layers 1–3, 7) |
| M7 | **Governed blueprint templates** (versioned board structures, sections, internal choice, chapter weightage, competency quotas) | Part 12/13 | Blueprint is per-paper JSONB computed from the request — v3.0 D5 inversion not built |
| M8 | **Exam Profile Engine** (profile-driven selection strategies) | Parts 13–14 | `program_track` enum exists on bank+papers, but no profile configuration/strategy layer |
| M9 | Paper ↔ exam-session link (`edu_exam_paper_links`) | Part 12 (audit trail) | Two disconnected id-spaces; v3.0 item 1.7 |
| M10 | Multi-set papers (A/B/C), sections, internal choices in the solver | Part 12 | Solver is a flat slot list |
| M11 | Subscription/tier gating of education capabilities | Part 14 | Gating platform exists (`plan_entitlements`); education capabilities not wired to it |
| M12 | Export beyond basic PDF (DOCX/HTML/structured JSON archive; branded PDF v2 w/ sections+instructions) | Part 12 | `education_pdf_service.dart` prints text-only A4 |
| M13 | Continuous synchronization / change detection for curriculum resources | Part 15 | Nothing exists |
| M14 | Canonical Concept Layer + concept↔board mappings + prerequisite DAG | Part 13 ↔ v3.0 §8 | Phase-2 design locked, zero schema present (verified: no `canonical_concepts`, no pgvector) |
| M15 | Response spine / item statistics / trust pipeline | v3.0 §5, §10 | Phase-2 design locked; schema seed not yet landed (verified absent) |

---

## 4. Architecture gaps (structural, beyond missing features)

| # | Gap | Impact |
|---|---|---|
| G1 | **No home for bulk curriculum data.** The repo is a Flutter app + Supabase backend; the spec's `resources/…` tree (thousands of PDFs) cannot live in git unguarded. | Needs an explicit storage decision (gitignored `curriculum/` lane vs separate repo vs R2 bucket) before acquisition starts |
| G2 | Bank items carry **both** free-text `chapter` and `syllabus_chapter_id` FK; free text still authoritative in places | Dual representation will corrupt coverage analytics as data scales |
| G3 | Solver selection pool caps at 100 items, flat slots, difficulty/chapter as soft preferences | Cannot honour real board patterns (v3.0 1.3 names this Phase-1 work) |
| G4 | Grade bands hardcoded (`gradeForPercent()` in `exam_administration_repository.ts:168`) | Conflicts with spec Part 16 "configuration over hard-coding"; multi-board grading needs config |
| G5 | `subject_templates` is the global curriculum catalogue but holds only a Grade-10 seed; no versioning (`curriculum_version`) | Continuous-sync (Part 15) impossible without version columns |
| G6 | No vector/semantic layer (pgcrypto is the only extension) | Fine for now — v3.0 defers pgvector to Phase 3; near-duplicate detection stays fingerprint-only |
| G7 | Client-side AI pipeline (`lib/core/ai/`) is simulated and bypassed by the education flow | Cleanup/naming debt (audit finding AI-6); do not build on it |
| G8 | No CI runner live (P0-TEST live-lane deferred) | Data-platform quality gates must run locally/scripted until CI lane opens |

---

## 5. Technical debt register (exam/education domain)

Tracked formally in [`../planning/TECHNICAL_DEBT_REGISTER.md`](../planning/TECHNICAL_DEBT_REGISTER.md). Highlights: legacy stub generator paths in `education_generator.ts` (superseded by Batch 8b, still present); duplicate active/archived copies of `ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md`; exam repo TEXT-id vs UUID id-space split; education client has hybrid wrapper while exam client does not; `ISO-COUNT` known test-count defect (pre-existing, unrelated but in the exam/communication test space).

---

## 6. Duplicate logic

- **Two generation paths**: the legacy template generator (`education_generator.ts` stub templates) and the certified solver+gap-fill path. The stub path is dead weight — flag for removal after confirming no caller.
- **Two blueprint notions**: `education_generator.ts` builds blueprint metadata; the solver plans slots. Part-12 work must consolidate on one blueprint representation (the governed template, D5).
- **Two curriculum representations**: `subject_templates.chapters` JSONB vs materialised `syllabus_chapters`/`syllabus_topics` rows. This split is intentional (template vs school instance) — keep, but the knowledge base (Part 09) must map onto **both** deliberately, never introduce a third.
- Exam analytics exist in `intel_exam_intelligence_snapshots` **and** ad-hoc report queries; the pipeline's analytics (Part 12 reports) must reuse the snapshot pattern, not add a third path.

---

## 7. Future risks

1. **Legal/copyright** is the program's dominant risk (Parts 03/10 vs locked D8) — see [`GAP_ANALYSIS.md`](GAP_ANALYSIS.md) §Conflicts and [`../planning/RISK_REGISTER.md`](../planning/RISK_REGISTER.md) R1.
2. **Governance collision**: the FINAL_EXECUTION_MASTER_ROADMAP is 🔒 frozen and does not contain this program; v3.0 sequences its phases post-pilot. Starting code work without an owner sequencing decision would violate the one-roadmap rule.
3. **Data before engines**: v3.0 §5.3 warns response data cannot be backfilled; equally, curriculum acquisition is slow and externally-bounded (government portals). The data lane should start early precisely because it has long lead time and zero code risk.
4. **Scope explosion**: 4 boards × 5 classes × ~10 subjects × ~30 resource types ≈ thousands of artifacts. Priority-A-first discipline (Part 07) is mandatory or acquisition never converges.
5. **Single production engine**: extending the certified engine in place risks regressing the pilot; every solver change needs the certified behaviours pinned by tests first (see [`BACKWARD_COMPATIBILITY_PLAN.md`](BACKWARD_COMPATIBILITY_PLAN.md)).

---

## 8. Backward-compatibility risks (summary)

Full plan: [`BACKWARD_COMPATIBILITY_PLAN.md`](BACKWARD_COMPATIBILITY_PLAN.md). The five certified guarantees that must never weaken: bank-first deterministic generation · hard syllabus boundary (422) · AI = moderation candidates only (publish gate 409) · safe-by-default no-key behaviour · draft→submit→review→approve→publish with submitter≠approver. All new capability lands as **additive** schema + **optional** inputs (template absent ⇒ legacy behaviour), behind flags, with the live-cert script extended rather than replaced.
