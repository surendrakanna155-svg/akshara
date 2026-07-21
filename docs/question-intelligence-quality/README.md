# Question Intelligence Engine (QIE) — lane index

> **Landing page for the QIE documentation lane.** This directory holds a fast-moving design/
> decision/evidence trail (45 docs + `phase0_evidence/`). It is **QIE knowledge — never deleted.**
> Read top-to-bottom: *Current* first; treat everything below "Superseded" as history, not instructions.
>
> _Added 2026-07-20 (Repository Hygiene & IA review). Classification per the IA review; see
> [`../engineering/REPOSITORY_HYGIENE_AND_IA_PLAN.md`](../engineering/REPOSITORY_HYGIENE_AND_IA_PLAN.md) §3d._

## Where the lane stands

The current direction is **Owner Decision C — the split-lane Question Planning Layer (QPL)** on the
frozen v1.4 knowledge foundation (AI proposes; deterministic/sympy certifies). The earlier
item-model/quality-gate SPECs (Jul 11) and the Phase A/B yield-mining + generation-pilot snapshots
(Jul 12–15) are **preserved history**, reoriented by that pivot.

## 1. Current — read these first (ACTIVE)

- [`QUESTION_PLANNING_LAYER_ROADMAP.md`](QUESTION_PLANNING_LAYER_ROADMAP.md) — **the authoritative design gate for QPL (2026-07-20).**
- [`CERTIFIED_KNOWLEDGE_INDEX_AND_QDI.md`](CERTIFIED_KNOWLEDGE_INDEX_AND_QDI.md) — the Decision-C redefinition (certified-knowledge index + QDI).
- [`QIE_SCALE_STRATEGY_TRIAL.md`](QIE_SCALE_STRATEGY_TRIAL.md) — the evidence behind Decision C.
- [`QP_INTEGRATION.md`](QP_INTEGRATION.md) — integration point into the QP path.
- [`QIE_SESSION_HANDOFF.md`](QIE_SESSION_HANDOFF.md) — fresh-session resume point (⏭ *partially superseded* — reflects Decisions A/B; the banner points to the QPL roadmap above).

## 2. Decision & reconciliation records (REFERENCE — permanent)

- [`DECISION_B_CONCEPT_GRANULARITY.md`](DECISION_B_CONCEPT_GRANULARITY.md) — ✅ resolved owner decision.
- [`OPUS_FABLE_RECONCILIATION_RECORD.md`](OPUS_FABLE_RECONCILIATION_RECORD.md) · [`EVIDENCE_RECONCILIATION.md`](EVIDENCE_RECONCILIATION.md)

## 3. Capability & architecture analysis (REFERENCE)

- [`COMPOSITIONAL_ARCHITECTURE.md`](COMPOSITIONAL_ARCHITECTURE.md) · [`CURRENT_VS_REQUIRED_ARCHITECTURE.md`](CURRENT_VS_REQUIRED_ARCHITECTURE.md) · [`QUESTION_INTELLIGENCE_CAPABILITY_RECONCILIATION.md`](QUESTION_INTELLIGENCE_CAPABILITY_RECONCILIATION.md) · [`BIOLOGY_COMPOSITION_MODEL.md`](BIOLOGY_COMPOSITION_MODEL.md) · [`NOTATION_RECOVERY_CAPABILITY.md`](NOTATION_RECOVERY_CAPABILITY.md)

## 4. Audit & red-team records (REFERENCE)

- [`QUESTION_QUALITY_ROOT_CAUSE_AUDIT.md`](QUESTION_QUALITY_ROOT_CAUSE_AUDIT.md) · [`FABLE5_INDEPENDENT_RED_TEAM_REVIEW.md`](FABLE5_INDEPENDENT_RED_TEAM_REVIEW.md) · [`JEE_MULTISTEP_EVIDENCE_CHECK.md`](JEE_MULTISTEP_EVIDENCE_CHECK.md)

## 5. Superseded design specifications (REFERENCE — "SPEC, not implemented"; reoriented by the QPL pivot)

- [`ITEM_MODEL_SPECIFICATION.md`](ITEM_MODEL_SPECIFICATION.md) · [`QUALITY_GATE_SPECIFICATION.md`](QUALITY_GATE_SPECIFICATION.md) · [`QUESTION_DNA_SPECIFICATION.md`](QUESTION_DNA_SPECIFICATION.md) · [`PSYCHOMETRIC_CALIBRATION_SPECIFICATION.md`](PSYCHOMETRIC_CALIBRATION_SPECIFICATION.md) · [`MODEL_ROUTING_AND_COST_PLAN.md`](MODEL_ROUTING_AND_COST_PLAN.md) · [`MULTIMODAL_INGESTION_ARCHITECTURE.md`](MULTIMODAL_INGESTION_ARCHITECTURE.md) · [`VISUAL_INTELLIGENCE_SPECIFICATION.md`](VISUAL_INTELLIGENCE_SPECIFICATION.md) · [`GOLD_BENCHMARK_PLAN.md`](GOLD_BENCHMARK_PLAN.md) · [`QUALITY_FIRST_IMPLEMENTATION_ROADMAP.md`](QUALITY_FIRST_IMPLEMENTATION_ROADMAP.md) (proposal — never owner-approved)

## 6. Phase snapshots — DONE (REFERENCE / point-in-time history)

> These are closed-status checkpoints. IA-review recommendation: relocate into a `phase-history/`
> subfolder (Tier 2 — **not yet done**; needs the accompanying link-repoint). Listed here so the
> live docs above stay uncluttered.

- Phase 0 / A: [`PHASE0_PREREGISTRATION.md`](PHASE0_PREREGISTRATION.md) · [`PHASE0_EVIDENCE_REPORT.md`](PHASE0_EVIDENCE_REPORT.md) · [`PHASE_A_CHARTER.md`](PHASE_A_CHARTER.md)
- Phase B yield mining (vs the now-retired ≥8/subject yield gate): [`PHASE_B_YIELD_REPORT.md`](PHASE_B_YIELD_REPORT.md) · [`PHASE_B1_YIELD_REPORT.md`](PHASE_B1_YIELD_REPORT.md) · [`PHASE_B6_YIELD_REPORT.md`](PHASE_B6_YIELD_REPORT.md) · [`PHASE_B7_YIELD_REPORT.md`](PHASE_B7_YIELD_REPORT.md) · [`PHASE_B8_YIELD_REPORT.md`](PHASE_B8_YIELD_REPORT.md) · [`PHASE_B9_CORPUS_DISCOVERY_AUDIT.md`](PHASE_B9_CORPUS_DISCOVERY_AUDIT.md) · [`PHASE_B10_BIOLOGY_MATH_SUBSTRATE.md`](PHASE_B10_BIOLOGY_MATH_SUBSTRATE.md)
- Generation pilots (DONE): [`GENERATION_BRIDGE_SLICE.md`](GENERATION_BRIDGE_SLICE.md) · [`GENERATION_JEE_BUILD.md`](GENERATION_JEE_BUILD.md) · [`GENERATION_PILOT_NEET_BIOLOGY.md`](GENERATION_PILOT_NEET_BIOLOGY.md) · [`GENERATION_PILOT_NEET_NUMERIC.md`](GENERATION_PILOT_NEET_NUMERIC.md) · [`GENERATION_READINESS_CHECK.md`](GENERATION_READINESS_CHECK.md)
- Governed conversion checkpoints: [`GOVERNED_CONVERSION_CHECKPOINT.md`](GOVERNED_CONVERSION_CHECKPOINT.md) · [`GOVERNED_CONVERSION_BATCH1_AND_STORAGE_GOVERNANCE.md`](GOVERNED_CONVERSION_BATCH1_AND_STORAGE_GOVERNANCE.md) · [`GOVERNED_CONVERSION_BATCH2_AND_NOTATION_FINDING.md`](GOVERNED_CONVERSION_BATCH2_AND_NOTATION_FINDING.md)
- Measurement checkpoints: [`BALANCED_PAPER_COVERAGE_GAP.md`](BALANCED_PAPER_COVERAGE_GAP.md) · [`PRODUCT_STATE_BY_PROFILE.md`](PRODUCT_STATE_BY_PROFILE.md)

## 7. Evidence artifacts (GENERATED / REFERENCE)

- [`phase0_evidence/`](phase0_evidence/) — 88 pre-registered experiment outputs, generation verdicts, capability matrices, and generated paper samples. Reproducible evidence base; never hand-edit.
