# Curriculum Intelligence Program — Index

**Created:** 2026-07-06 · **Status:** 🟢 **APPROVED — 🔒 PROGRAM BASELINE v1.0 + Amendment A1 (owner spec drop, synchronized 2026-07-07).** This documentation set is frozen as the implementation baseline for Claude Opus 4.8; changes require owner approval. Zero production code written to date (verification engine = approved data-lane tooling). **A1** merges the canonical [`ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md`](spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md) into this package — delta record: [`audits/GAP_ANALYSIS.md`](audits/GAP_ANALYSIS.md) §6; no baseline wave re-sequenced.

## 🔒 Owner decision record (Baseline v1.0 — full text in [`audits/GAP_ANALYSIS.md`](audits/GAP_ANALYSIS.md) §3)

- **D-1** Integration approved: CI = parallel data platform; the certified engine remains the production paper-generation engine — never replaced or redesigned.
- **D-2** Workspace = root `curriculum/` outside the app source tree; binaries gitignored.
- **D-3** **Three-layer question model:** L1 Official Curriculum & Question Banks · L2 Previous Question Paper Intelligence (analysis/reference **only**) · L3 **Certified Question Bank** — production generation uses **L3 only** by default.
- **D-4** Board order: **CBSE → Andhra Pradesh → Telangana → CISCE**.
- **D-5** Mandatory **Repository Certification**: `Downloaded → Verified → Repository Certified → Knowledge Base`; KB never starts before certification.
- **D-6** **Question Trust Lifecycle:** `RAW → EXTRACTED → AI_VALIDATED → TEACHER_VALIDATED → CERTIFIED`; only CERTIFIED questions feed production generation by default (existing approved bank rows ≙ CERTIFIED; composes with the v3.0 evidence trust pipeline downstream).
- **D-7** 🟡 *proposed — owner-approved 2026-07-08, ratification pending:* **certification at the Question *Family* level** (parameterized families) so the deterministic engine mints unlimited per-student instances with **zero runtime AI (proposed invariant I9)**. Tracked in [`proposals/`](proposals/README.md) (Amendment **A2**); **not yet merged** into the frozen specs — sequencing unchanged.

## What this is

The Curriculum Intelligence Pipeline: build a verified official-curriculum repository (CBSE, AP SCERT, Telangana SCERT, CISCE — D-4 order · Classes 6–10 · English medium), extract structured knowledge from it, and complete Akshara's question-paper engine into a board-compliant, profile-aware, validated-generation platform — **extending, never replacing,** the live-certified Question Intelligence foundation (D-1).

## Governing authorities (in order)

1. [`docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`](../engineering/AKSHARA_ENGINEERING_CONSTITUTION.md) + EOS gate — engineering law.
2. 🔒 [`docs/Vision/design/Assessment-Intelligence-Platform.md`](../Vision/design/Assessment-Intelligence-Platform.md) (Master Plan v3.0, locked D1–D11) — the domain's forward architecture. **Where any program spec and v3.0 disagree, v3.0 governs unless the owner rules otherwise** (conflict register: [`audits/GAP_ANALYSIS.md`](audits/GAP_ANALYSIS.md) §2).
3. The canonical program specs (below): the MCIP (data pipeline) + the **AIMS** (assessment-intelligence layer, Amendment A1). AIMS declares itself an *extension* of the Program Baseline, never a replacement (its Part 1).

## Documents

### `proposals/` — tracked planning proposals (🟡 pending owner ratification; not merged)
- [`proposals/README.md`](proposals/README.md) — **Proposals Register** (the canonical index; a proposal is tracked here from draft → ratified/withdrawn).
- [`proposals/AMENDMENT_A2_PER_STUDENT_PRACTICE_GENERATION.md`](proposals/AMENDMENT_A2_PER_STUDENT_PRACTICE_GENERATION.md) — **Amendment A2** (🟡 Pending Owner Ratification; direction + D-7 + I9 + §12 owner-approved 2026-07-08): deterministic per-student practice & DPP generation engine (family-level certification, zero runtime AI). Integrates onto CI-C10/C1/C3/C8 + v3.0 §13; **no sequencing change until ratified.**

### Integration & handoff (2026-07-07 — read these first)
- [`INTEGRATION_AND_READINESS_REVIEW.md`](INTEGRATION_AND_READINESS_REVIEW.md) — repository-verified deliverable audit, consistency review, **roadmap integration (CI-DATA parallel track + P1-CI-0 pre-red-team wave + v3.0 Phase-1 mapping)**, Red-Team position, readiness assessment.
- [`OPUS_IMPLEMENTATION_HANDOFF.md`](OPUS_IMPLEMENTATION_HANDOFF.md) — the complete implementation handoff package (governing law, status, order, standards, recommendations).

### `spec/` — canonical specifications (owner drops; content unmodified)
- [`PROJECT_BOOTSTRAP.md`](spec/PROJECT_BOOTSTRAP.md) — the process contract (understand → audit → plan → **wait for approval**).
- [`MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md`](spec/MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md) — Parts 01–16 (curriculum data pipeline).
- [`DOWNLOAD_VERIFICATION_AND_RECOVERY_ENGINE.md`](spec/DOWNLOAD_VERIFICATION_AND_RECOVERY_ENGINE.md) — owner addendum (2026-07-07): checks V1–V11, recovery loop, health report, final repository audit. **⚙ Implemented** at `curriculum/scripts/verification/` (13/13 tests; AT-V1..V10).
- [`ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md`](spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md) — **AIMS, Parts 1–12** (owner drop 2026-07-07): concept graph, curriculum boundary engine, item models/question families, certified question bank intelligence, diagram intelligence, golden rules, data model, pipelines, service map, QA standards, design patterns + anti-patterns. Supersedes the earlier architectural enhancement notes; merged into this package as **Amendment A1** ([`audits/GAP_ANALYSIS.md`](audits/GAP_ANALYSIS.md) §6).

### `audits/` — code-verified audit (read first)
- [`EXAM_ARCHITECTURE_AUDIT.md`](audits/EXAM_ARCHITECTURE_AUDIT.md) — what exists (certified engine inventory), missing features M1–M15, architecture gaps, duplicate logic, risks.
- [`GAP_ANALYSIS.md`](audits/GAP_ANALYSIS.md) — part-by-part spec verdicts · **⚠️ conflicts C1–C7 with locked decisions** · **👤 owner decisions D-1..D-4** · deprecations.
- [`BACKWARD_COMPATIBILITY_PLAN.md`](audits/BACKWARD_COMPATIBILITY_PLAN.md) — invariants I1–I8, risk register B1–B10, additive-only migration strategy, non-goals.

### `planning/` — engineering roadmap (wave IDs defined in the sequence doc)
| Doc | Concern |
|---|---|
| [`IMPLEMENTATION_SEQUENCE.md`](planning/IMPLEMENTATION_SEQUENCE.md) | **Master ordering** — two-lane model, waves CI-A0..E1 |
| [`CONTENT_DEPENDENCY_MAP.md`](planning/CONTENT_DEPENDENCY_MAP.md) | **🟢 Runnable-now vs 🔴 content-blocked** (owner 2026-07-08) — only acquisition is network-gated; the deterministic engine/schema/APIs/tests/docs run now on fixtures |
| [`MODULE_DEPENDENCY_GRAPH.md`](planning/MODULE_DEPENDENCY_GRAPH.md) | Layer + wave dependency graphs; reused-module matrix |
| [`IMPLEMENTATION_PHASES.md`](planning/IMPLEMENTATION_PHASES.md) | Phases CI-P0..P4 + boundary rules |
| [`CRITICAL_PATH_ANALYSIS.md`](planning/CRITICAL_PATH_ANALYSIS.md) | Goal lines G1/G2, critical paths, slack |
| [`PARALLEL_EXECUTION_PLAN.md`](planning/PARALLEL_EXECUTION_PLAN.md) | What may run concurrently (file-ownership rule) |
| [`SPRINT_PLAN.md`](planning/SPRINT_PLAN.md) | S0–S9 execution blocks + effort totals |
| [`AGENT_ASSIGNMENT_PLAN.md`](planning/AGENT_ASSIGNMENT_PLAN.md) | Agent roles, territories, wave matrix |
| [`IMPLEMENTATION_CHECKLIST.md`](planning/IMPLEMENTATION_CHECKLIST.md) | Per-wave done-criteria checkboxes |
| [`MILESTONE_TRACKER.md`](planning/MILESTONE_TRACKER.md) | **Living status pointer** (M0–M8 + wave ledger) |
| [`ACCEPTANCE_TEST_PLAN.md`](planning/ACCEPTANCE_TEST_PLAN.md) | Proof obligations per wave (AT-*) |
| [`ROLLBACK_PLAN.md`](planning/ROLLBACK_PLAN.md) | Per-wave rollback levers; additive-only doctrine |
| [`RISK_REGISTER.md`](planning/RISK_REGISTER.md) | R1–R14 with mitigations |
| [`TECHNICAL_DEBT_REGISTER.md`](planning/TECHNICAL_DEBT_REGISTER.md) | Found debt TD-CI-1..10 + taken debt TD-CI-11..16 |

## Executive assessment (2026-07-06)

- **Readiness:** the generation engine core is ~**60% of the spec's Parts 12/14/16** already live-certified (solver, governance, syllabus boundary, AI gap-fill, Bloom/track metadata). The curriculum **data platform (Parts 02–08) is 0%** — entirely greenfield. Intelligence layers (Parts 09–11, 13) ≈ **15%** (taxonomy + provenance primitives exist; no extraction, no competency/concept/template/profile entities).
- **Fastest value (G1):** one hand-transcribed CBSE template → CI-C1 (templates + solver) → CI-C3 ≈ **15–19 code dev-days** to 100% board-compliant papers.
- **Full program (G2):** ~72–106 dev-days across both lanes; the four-board data lane is the long pole and runs risk-free in parallel.
- **Next milestone (approved):** M1 — CI-A0 remainder + CBSE acquisition; **P1-CI-0** (golden pinning + paper↔exam link + dormant E1a seed) scheduled before P4-RT-0.
- **First coding task:** CI-C1 step 1 — golden-test pinning of `education_blueprint_solver.ts` current behaviour (inside P1-CI-0).
- **Blocked on:** nothing — D-1..D-6 resolved 2026-07-07; Baseline v1.0 in force.

## Standing rules for this program

- Certified invariants I1–I8 are inviolable; every code wave is one EOS-gated commit.
- Locked v3.0 decisions (esp. **D2** no answer-sheet OMR, **D8** original-content-first) bound every wave; the spec's Part-10 extraction runs under the D-3 two-lane ruling.
- Data lane never touches app trees; binaries never enter git.
- *(A1)* AIMS golden rules (Part 5) + anti-patterns (Part 12) bind every wave: concept-first once the graph is live, generate→validate→certify with no shortcut, offline AI / deterministic runtime, complete metadata, original vector diagrams only, teacher authority final.
- This README + `planning/MILESTONE_TRACKER.md` are refreshed at every wave boundary.
