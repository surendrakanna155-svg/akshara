# Curriculum Intelligence — Gap Analysis

**Compares:** [`MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md`](../spec/MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md) (Parts 01–16) **vs** the verified as-built system.
**Date:** 2026-07-06 · Every verdict below is code-verified (see [`EXAM_ARCHITECTURE_AUDIT.md`](EXAM_ARCHITECTURE_AUDIT.md) for evidence).
**Classification:** ✅ Already Implemented · 🟡 Partially Implemented · ❌ Missing · ⚠️ Conflicting · 🗑 Deprecated

---

## 1. Part-by-part verdict table

| Spec part | Requirement | Verdict | Evidence / gap |
|---|---|---|---|
| 01–02 | Mission, execution model, project-management files (TODO/PROGRESS/SESSION_LOG/queues) | ❌ Missing | No curriculum-repo workspace exists; PM-file scaffolding is Wave A1 work |
| 03 | Resource discovery & acquisition (4 boards × classes 6–10, English medium) | ❌ Missing | No download/discovery tooling anywhere in repo |
| 04 | Repository structure & file organization standards | ❌ Missing | Needs storage-location decision first (D-2 below) |
| 05–06 | Official source matrix & search strategy | ❌ Missing | Prior art only as v2.0 §4 source table (JEE archives, NCERT, NTA) — reusable input |
| 07 | Coverage matrix, completeness verification, quality score | ❌ Missing | — |
| 08 | Metadata architecture, Resource IDs, checksums, indexes | ❌ Missing | — |
| 09 | Knowledge base: chapter/topic extraction | 🟡 Partial | Chapter/topic **taxonomy exists** (`subject_templates` JSONB + `syllabus_chapters`/`syllabus_topics`) with a real Grade-10 CBSE/SSC seed; no document-extraction pipeline, classes 6–9 + ICSE absent |
| 09 | Learning-outcome extraction | 🟡 Partial | `learning_outcome` TEXT column on bank items; no structured outcome objects, no extraction |
| 09 | Competency extraction | ❌ Missing | No competency entity anywhere (definitive) |
| 09 | Knowledge objects (definitions/formulae/events/experiments) | ❌ Missing | — |
| 10 | Question extraction from resources into Question Objects | ⚠️ **Conflicting** (see §2 C1) + 🟡 | Bank + provenance (`source='pyq'/'publisher'` enum values, `source_reference`) exist; no extraction pipeline; **bulk extraction from copyrighted material collides with locked D8** |
| 10 | Question classification (difficulty/Bloom/type/skills) | 🟡 Partial | difficulty + `cognitive_level` (Bloom) + `question_type` + `jee_question_type` live on bank items; no auto-classification pipeline, no skills/competency tagging |
| 10 | Question relationships & duplicate detection | 🟡 Partial | Fingerprint dedup ✅ (exact/near-normalized); semantic similarity ❌ (no pgvector — v3.0 defers to Phase 3); relationship graph ❌ |
| 11 | Independent AI Validation Engine (generator ≠ validator, quality scores, revision workflow) | 🟡 Partial | Layers 1–3 + human moderation exist (schema validation, syllabus boundary, fingerprint, candidate gate); independent AI second-review, blind-solve answer verification, quality scoring, revision versioning ❌ (= v3.0 §11 layers 4–6, 8) |
| 12 | Paper composition pipeline (blueprint→selection→balancing→validation→review→publish) | 🟡 Partial (core ✅) | Deterministic solver + governance **live-certified**; missing: sections/internal choice/multi-set, Bloom/competency balancing as hard constraints, coverage validation, time validation |
| 12 | Exam types configurable | ✅ | `exam_type` enum unit_test…annual on papers + exam_sessions |
| 12 | Teacher review capabilities (approve/reject/replace/regenerate/edit/reorder) | 🟡 Partial | Moderate/edit/regenerate/promote per item ✅ (backend + client); reorder/replace-from-bank UX gaps |
| 12 | Export formats (PDF/DOCX/HTML/JSON) | 🟡 Partial | Basic text PDF only |
| 12 | Audit trail (reproducible papers) | 🟡 Partial | Education audit events + review trail ✅; blueprint inputs logged; solver seed/inputs not fully snapshotted for byte-reproducibility |
| 13 | Multi-layer knowledge architecture (L1 curriculum → L5 composition) | 🟡 Partial | L3 (question objects) + L5 (composition) exist; L1 (official corpus) ❌, L2 (academic intelligence) ❌, L4 (profile engine) ❌ |
| 13 | Exam profiles (Standard/Advanced/Foundation/JEE/NEET/Olympiad/Scholarship/Custom) | 🟡 Partial | `program_track` enum (board/jee_foundation/neet_foundation/ntse/olympiad) on bank+papers; **no profile-rule engine**, no profile compatibility validation |
| 13 | Difficulty model L1–L5 independent of marks | 🟡 Partial | easy/medium/hard + cognitive_level; not the 5-level model — map, don't rebuild (see §2 C6) |
| 14 | Examination Type ≠ Examination Profile separation | 🟡 Partial | Type exists; profile = enum only |
| 14 | Subscription-tier capability gating (no hard-coded plan names) | 🟡 Partial | Platform primitives exist (`plan_entitlements`, `platform_feature_enablements`, B2-certified pattern); education capabilities not wired |
| 14 | Backward-compatibility audit before build | ✅ | This document set |
| 15 | Continuous synchronization, change detection, impact analysis | ❌ Missing | — |
| 15 | Testing requirements | 🟡 Partial | Solver/gapfill/boundary/authz tests exist (10+ education test files, 118+ exam tests); no data-platform tests (nothing to test yet) |
| 16 | AI decision policy (never invent, confidence, HITL, explainability, config-over-hardcode) | 🟡 Partial | Never-fabricate + HITL + moderation ✅ (certified); confidence scoring ❌; explainability (selection reasons) ❌; grade bands hardcoded (G4) |

**Score:** of the spec's 16 parts — 0 fully missing engines where the spec assumed one exists; the certified engine covers the core of Parts 12/14/16; Parts 02–08 + 15 (the data platform) are 100% greenfield; Parts 09–11 + 13 are the intelligence layer where locked v3.0 designs exist but schema/code do not.

---

## 2. ⚠️ Conflicts (spec vs locked decisions / frozen governance)

These are **not buildable as written** without an owner ruling. Recommended resolutions below; none is assumed.

| # | Conflict | Locked authority | Recommended resolution |
|---|---|---|---|
| **C1** | Part 10 says *"extract questions from every verified resource"* incl. textbooks, question banks, board papers → Question KB that feeds paper generation. **D8 (locked)**: original-content-first; PYQs/open material = *"pattern analysis and tagging, never bulk republishing"*; publisher content never a dependency. | v3.0 D8 + v2.0 §25 legal guardrails (in force verbatim) | **✅ RESOLVED by owner D-3 (2026-07-07) — three-layer model:** **L1** Official Curriculum & Official Question Banks (acquired corpus, repository-side) · **L2** Previous Question Paper Intelligence (analysis/reference only — pattern analysis, blueprint calibration, tagging; never school-facing bank content) · **L3** Certified Question Bank (teacher-authored, school-owned incl. cold-start past papers, AI-generated **and teacher-approved**). Production generation defaults to **L3 only**. Question-level ingestion of third-party copyrighted material into L3 remains out unless explicitly licensed. |
| **C2** | The spec positions the downloaded curriculum repository as *"the single source of truth for every future educational AI component."* **D1 (locked)**: the primary intelligence asset is the **response corpus**; content is the instrument. | v3.0 D1 | Adopt the repository as SSOT **for curriculum/knowledge data** (L1 of Part 13) only. v3.0 remains the governing architecture; the pipeline fills v3.0's open flank — where curriculum, blueprint-template, and pattern data come from. State this subordination explicitly in every planning doc (done). |
| **C3** | The spec front-loads a large multi-session acquisition program now; the **FINAL_EXECUTION_MASTER_ROADMAP is 🔒 frozen** (currently P1-PROD-15/C17) and v3.0 §15 sequences its phases *after* module-completion → red-team → pilot. | Frozen roadmap + v3.0 D11 | Split lanes: the **data lane** (Parts 02–08, no app code, zero live-path risk) may run as a parallel non-code workstream without amending the frozen roadmap — *if the owner approves the bandwidth*; the **code lane** (Parts 9–14) schedules as/with v3.0 Phase 1+2 per the owner's timing. Owner decision required either way (D-1 below). |
| **C4** | Part 14 subscription tiers (Starter/Professional/Premium/Enterprise examples) vs owner decision **O6**: billing/monetization = Phase 2 commercial. | PRODUCT_COMMERCIAL_BACKLOG O6 | Build capability **flags** only (spec itself demands capability-based flags, not plan names) on the existing `plan_entitlements` platform; actual paid tiers remain Phase-2 commercial scope. No conflict once framed this way. |
| **C5** | Part 03 scope: English medium only. Spec Part 12 lists `Language`/`Medium` as paper config. The **English-first decision (frozen)** bars full-app localization; **v3.0 §17 O-A** leaves multilingual *question content* explicitly open. | English-first decision + v3.0 §17 | Acquisition stays English-medium (spec-aligned). Multilingual question content remains open owner decision O-A — untouched by this program. |
| **C6** | Part 13 difficulty model = 5 levels (Recall→Competitive Foundation); as-built = easy/medium/hard + cognitive_level(5). | As-built certified data | Don't migrate the enum. Derive the 5-level presentation as **(difficulty × cognitive_level × program_track)** mapping; revisit only when evidence-based difficulty (v3.0 D6, Phase 2) replaces labels anyway. |
| **C7** | Part 12 lists OMR-adjacent ideas nowhere, but Part 10's answer/marking extraction could drift toward per-student sheet processing. **D2 (locked)**: per-student answer-sheet OCR/OMR **not pursued**; Marks-Grid instead. | v3.0 D2 | Constraint noted in planning docs: no workstream may build per-student answer-sheet capture. |

## 3. Owner decision record — ✅ ALL RESOLVED (2026-07-07, Program Baseline v1.0)

| # | Decision (owner ruling, verbatim intent) | Consequence in this program |
|---|---|---|
| **D-1** ✅ | **Integration strategy approved.** Curriculum Intelligence = parallel data platform; the certified Assessment Intelligence Platform remains the production paper-generation engine; never replace or redesign it | Integration per [`../INTEGRATION_AND_READINESS_REVIEW.md`](../INTEGRATION_AND_READINESS_REVIEW.md) §4: CI-DATA parallel track + P1-CI-0 pre-red-team wave + engine waves as v3.0 Phase 1 |
| **D-2** ✅ | Dedicated root-level `curriculum/` workspace outside the application source tree; binary resources gitignored | As built; `.gitignore` guard verified |
| **D-3** ✅ | **Three-layer question model** (replaces the two-lane recommendation): **L1** Official Curriculum & Official Question Banks (the acquired corpus) · **L2** Previous Question Paper Intelligence (**analysis/reference only**) · **L3** Certified Question Bank (teacher-authored, school-owned, AI-generated **and teacher-approved**). **Production paper generation uses ONLY L3 (Certified Question Bank) by default** | Supersedes the C1 two-lane wording (mapping: old "pattern/PYQ store" ≈ L2; old "bank" ≈ L3; L1 = the repository corpus itself). L1/L2 content never flows into L3 automatically; D8 guardrails unchanged |
| **D-4** ✅ | Board order: **CBSE → Andhra Pradesh → Telangana → CISCE** | CI-A2 = AP SCERT, CI-A3 = TS SCERT (sequence/sprint docs updated) |
| **D-5** ✅ | Mandatory **Repository Certification** stage: `Downloaded → Verified → Repository Certified → Knowledge Base`; KB generation must never start before certification | CI-A6 exit = certification: `repository_audit.py` PASS + `CURRICULUM_REPOSITORY_CERTIFICATION.md` evidence + `PROJECT_STATUS.json` certified flag (audit tool extended at CI-A6; gate semantics already implemented) |
| **D-6** ✅ | **Question Trust Lifecycle:** `RAW → EXTRACTED → AI_VALIDATED → TEACHER_VALIDATED → CERTIFIED`; only CERTIFIED questions used for production generation by default | Ingestion/authoring lifecycle for CI-C5/C6. Mapping: CERTIFIED ≙ today's `status='active' ∧ review_status='approved'` (the certified engine already selects only these — default behaviour preserved); teacher-authored items enter at TEACHER_VALIDATED. **Composes with, does not replace,** the v3.0 §10.2 evidence trust pipeline: D-6 governs *eligibility*; v3.0 probation→trusted governs *post-certification quality evolution* (Phase 2). **Dependency change:** CI-C6 full lifecycle now depends on CI-C5 (AI_VALIDATED precedes TEACHER_VALIDATED) |

---

## 4. 🗑 Deprecated (found during audit — cleanup candidates, not blockers)

| Item | Why | Action |
|---|---|---|
| `education_generator.ts` stub-question templates | Superseded by Batch 8b solver + gap-fill ("no silent faking") | Remove after confirming zero callers (tracked TD-CI-1) |
| `lib/core/ai/` simulated inference pipeline for education | Education flow bypasses it; server-side AI is real | Do not build on; naming cleanup already tracked (audit AI-6) |
| `docs/design/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` active copy | Header says "Do not plan from this file"; archived copy exists | Archive the active duplicate (TD-CI-2) |
| v2.0 master plan | Superseded by v3.0 (architecture preserved by reference) | Already archived — consult read-only |

---

## 5. Recommended improvements beyond the spec

1. **Blueprint templates as the first code deliverable** (v3.0 1.4/D5): highest leverage — turns the certified solver into a board-compliant generator and gives acquisition (blueprints are Priority-A resources) an immediate consumer.
2. **Reuse the acquisition pipeline for the bank cold-start** (v3.0 1.8): the same OCR-first ingestion doctrine (D3) serves school-owned past papers — the legally-clean path to bank scale.
3. **Version columns on `subject_templates`** (+ `curriculum_version_id` pattern from v3.0 §8.2) before expanding it, so Part-15 continuous sync has something to sync against.
4. **Ship the dormant Phase-2 schema seed** (v3.0 §5.3: `edu_exam_paper_links`, `edu_student_item_responses`, trust columns) at the end of the code lane's first phase — data cannot be backfilled.
5. **Selection-reason logging** (spec Part 16 explainability) as a solver output field — cheap now, impossible to retrofit onto historical papers.
