# Curriculum Intelligence — Gap Analysis

**Compares:** [`MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md`](../spec/MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md) (Parts 01–16) **vs** the verified as-built system · **§6** adds the delta record for the [`ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md`](../spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md) (AIMS) owner drop.
**Date:** 2026-07-06 · Amendment A1 (AIMS sync) 2026-07-07 · Every verdict below is code-verified (see [`EXAM_ARCHITECTURE_AUDIT.md`](EXAM_ARCHITECTURE_AUDIT.md) for evidence).
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
| **D-7** 🟡 *proposed — owner-approved 2026-07-08; **ratification pending*** | **Certification granularity = Question *Family* level** (parameterized families): a CERTIFIED family's deterministic solver-verified instances inherit certification, so the engine mints unlimited per-student instances with **zero runtime AI (proposed invariant I9)**. Instance-level certification stays for static/singleton items | **Tracked as a pending planning proposal — [`../proposals/AMENDMENT_A2_PER_STUDENT_PRACTICE_GENERATION.md`](../proposals/AMENDMENT_A2_PER_STUDENT_PRACTICE_GENERATION.md)** (Amendment A2). **NOT yet merged**; D-3/D-6 unchanged until ratified. Reconciles with I1 (bank-first determinism, extended to certified families) and I3 (untouched — runtime is AI-free). Integrates onto CI-C10/C1/C3/C8 + v3.0 §13 post-pilot; **CI sequencing unchanged** |

> **Pending proposals** are tracked in [`../proposals/README.md`](../proposals/README.md) and merge
> into this D-register only on owner ratification. On ratification, **A2** adds D-7 above and
> invariant **I9** to [`BACKWARD_COMPATIBILITY_PLAN.md §1`](BACKWARD_COMPATIBILITY_PLAN.md).

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

---

## 6. AIMS delta record — Amendment A1 (2026-07-07)

**Source:** [`../spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md`](../spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md) (AIMS, Parts 1–12, owner canonical drop). AIMS states its own charter: *extend the Program Baseline, never replace it* (Part 1). Most of AIMS restates Baseline v1.0 law (three-layer model, D-5/D-6 gates, copyright rules, offline-AI/runtime split, config-over-hardcode, EOS, no parallel architectures) — restatements carry **no planning change** and are not listed. The table below records only the genuine deltas and where each was merged.

| # | AIMS addition (Part) | Verdict vs Baseline v1.0 | Merged into |
|---|---|---|---|
| **A1-1** | **Concept Graph + permanent Concept IDs** (e.g. `SCI_G06_PHY_FORCE_001`); every question/diagram ultimately references Concept IDs; relationships incl. prerequisites, misconceptions, confused-concepts, teaching sequence (P2/P6) | 🟡 Extends the CI-B4 concept-seed proposal + v3.0 §8 canonical concepts; **activation timing unchanged** (concept tables land at CI-E1b; Phase-2 features stay Phase 2 per D11) | CI-B4 scope extended to the full Concept Graph dataset + ID scheme; CI-E1b seeds it |
| **A1-2** | **Curriculum Boundary Engine v2** — pre-generation validation beyond chapters: Bloom level, difficulty, learning outcome, competency, cognitive depth (P2) | 🟡 Extends `education_syllabus_boundary.ts` (invariant I2) — same module, more dimensions; never a second engine. New dimensions validate only where metadata exists (B13) | CI-C4 (outcome/competency fields) + CI-C5 (generated-content boundary check) + CI-C10 (generation-time) |
| **A1-3** | **Foundation depth-not-scope rule** — foundation profiles raise reasoning/Bloom/complexity, never curriculum scope, unless explicitly configured (P2/P5 Rule 6) | ❌ New validation rule | CI-C7 profile validation |
| **A1-4** | **Automatic Item Generation** — reusable Item Models (`edu_question_templates` entity, parameter variation) + offline batch question factory building the Certified Bank (P2/P6/P7 Pipeline 4) | ❌ New capability — no baseline wave existed | **New wave CI-C10** (Question Factory) |
| **A1-5** | **Question Families** — every question belongs to a family grouping its type-variants under one concept (P2/P6, Rule 15) | ❌ New grouping entity + metadata | CI-C10 schema (+ CI-C4 tagging columns) |
| **A1-6** | **Trust-lifecycle extension** — `GENERATED` entry state + post-CERTIFIED `ACTIVE → CONTINUOUS_REVIEW → RETIRED` (P3) | 🟡 Composes with D-6 + v3.0 §10.2 — mapping below; **no conflict** | D-6 mapping note (below); backcompat B5 |
| **A1-7** | **Evolving Quality Score + Teacher Feedback Intelligence** — multi-factor score updated by usage/teacher/student signals (P3, Pipelines 8/9) | 🟡 Score-at-validation = CI-C5 (already planned); the *evolution loop* needs the response spine → v3.0 Phase 2 (E1a seed) | CI-C5 persists the score columns; evolution deferred to Phase 2 (TD-CI-18) |
| **A1-8** | **Distractor Intelligence / Distractor Library** — distractors as first-class concept-linked assets with misconception categories + reuse (P3/P6) | ❌ New entity | CI-C10 schema; selection-rate analytics activate Phase 2 |
| **A1-9** | **Mandatory question-metadata completeness** — ~30-field set (concept, family, license, confidence, quality, origin, generation method, boundary status, estimated time…); incomplete ⇒ never certified (P3, Rule 8) | 🟡 Extends bank schema + adds a certification-entry gate; **legacy certified rows grandfathered** (TD-CI-17) | Additive columns across CI-C4/C5/C6/C10 + completeness gate in CI-C5 |
| **A1-10** | **Diagram Intelligence** — requirement detection → spec → programmatic SVG/vector generation → AI+teacher validation → **Certified Diagram Library**; vector-only, original-only (P3/P6/P7 Pipeline 5, Rule 14) | ❌ New module — baseline explicitly deferred diagram rendering (TD-CI-10) | **New wave CI-C11** (Diagram Intelligence) |
| **A1-11** | **Exam Profile config enrichment** — time allocation, reasoning depth, diagram requirements, question-family distribution per profile (P4/P6) | 🟡 Extends the CI-C7 profile entity's field set | CI-C7 scope |
| **A1-12** | **11-point production safeguard gate** (P4) + release-gate list + operational metrics (P9) | 🟡 Consolidates existing gates + adds boundary-status/metadata-complete/diagram-verified checks; subordinate to EOS (never a second gate) | ACCEPTANCE_TEST_PLAN §3/§4 |
| **A1-13** | **Canonical pipelines P1–P12 + pipeline standards** (checkpointing, metrics, audit, validation gates) (P7) | 🟡 P1–P3/P6/P7/P10/P12 map onto existing waves; P4/P5 are the new factories; P8/P9 are Phase 2 | MODULE_DEPENDENCY_GRAPH §5 mapping table |
| **A1-14** | **Logical service map — 13 services** (P8) | ✅ Mapping exercise only (AIMS: *"do not create these services immediately… first map every responsibility to the existing codebase"*); modular monolith stays | MODULE_DEPENDENCY_GRAPH §6 mapping table |
| **A1-15** | **Design patterns P1–P18 + anti-pattern catalogue** (P11/P12) | ✅ Binding implementation standards; fully consistent with I1–I8, D-6, D8 | OPUS handoff §7 standards |
| **A1-16** | **Future vision / evolution stages** (P10) | ✅ Strategic guidance only — AIMS itself forbids roadmap impact from P10 | No action |

**A1-6 lifecycle mapping (extends D-6, no conflict):** entry states — *ingested* items enter as `EXTRACTED` (D-6), *AI-authored* items (gap-fill, CI-C10 factory) enter as `GENERATED`; both then follow `AI_VALIDATED → TEACHER_VALIDATED → CERTIFIED`. Post-CERTIFIED: `ACTIVE` ≙ today's `status='active' ∧ review_status='approved'`; `CONTINUOUS_REVIEW` ≙ the v3.0 §10.2 evidence pipeline (probation→trusted→quarantined — Phase 2); `RETIRED` ≙ v3.0 retirement. Production selection remains CERTIFIED/ACTIVE-only by default — D-3/D-6 behaviour unchanged.

**New owner items surfaced by A1 (non-blocking, batch at the next boundary — standing rule):**

| # | Item | Default recorded in planning |
|---|---|---|
| A1-O1 | Timing of CI-C10/CI-C11 inside the post-pilot window | After CI-C5 + CI-E1b, at the v3.0 Phase-1→2 boundary; neither touches P1-CI-0 or the pre-P4 scope |
| A1-O2 | Diagram generation technology selection (SVG engine/libraries) | Decided at CI-C11 design gate; constraint fixed now: programmatic vector only, no raster, no image-model copying |
| A1-O3 | Mandatory-metadata subset for legacy-row backfill | Legacy certified rows grandfathered; completeness enforced for new certifications only (TD-CI-17 exit = CI-C4 tagging + Phase-2 concept mapping) |

*Spec-hygiene note:* the AIMS file has a formatting artifact around line 5957 — Part 12 (anti-patterns) begins mid-sentence inside Part 11's closing questions, and Part 11's final question list resumes after Part 12's content. Content treated as authoritative as-is; the owner spec file itself is left unmodified.
