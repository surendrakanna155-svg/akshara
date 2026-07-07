# Curriculum Intelligence — Milestone Tracker

**Date created:** 2026-07-06 · **Living document** — the program's "where are we" pointer (refreshed at every wave boundary, same discipline as the master roadmap's NEXT_ACTIVE_WAVE/dashboard pair).
**Legend:** ✅ done · 🔵 in progress · ⚪ pending · ⏸ blocked/owner-gated

---

## Program status

| Field | Value |
|---|---|
| **Program state** | 🟢 **APPROVED — 🔒 PROGRAM BASELINE v1.0 (owner, 2026-07-07)**. Implementation authorized per [`../OPUS_IMPLEMENTATION_HANDOFF.md`](../OPUS_IMPLEMENTATION_HANDOFF.md); Claude Opus 4.8 executes from this baseline. Baseline changes require owner approval |
| **Current milestone** | **M0 ✅ complete** → next: **M1** (CI-A0 remainder + CI-A1 CBSE acquisition) ∥ schedule **P1-CI-0** before P4-RT-0 |
| **Owner decisions** | ✅ **D-1..D-6 resolved 2026-07-07** — decision record: [`../audits/GAP_ANALYSIS.md`](../audits/GAP_ANALYSIS.md) §3 (integration · `curriculum/` location · three-layer question model, production = Certified Bank only · board order CBSE→AP→TS→CISCE · Repository Certification stage · Question Trust Lifecycle RAW→…→CERTIFIED) |
| **Last update** | 2026-07-07 — **Amendment A1 (AIMS sync)** merged across the planning suite: delta record [`../audits/GAP_ANALYSIS.md`](../audits/GAP_ANALYSIS.md) §6; new waves CI-C10/C11 appended post-E1b; scope extensions to CI-B4/C4/C5/C7; no re-sequencing of baseline waves |

## Milestones

| # | Milestone | Waves | Exit evidence | Status |
|---|---|---|---|---|
| **M0** | Foundation: spec relocated, audits + planning suite delivered, decisions surfaced | CI-P0 | This doc set; owner approval | 🔵 (docs ✅ · approval ⏸) |
| **M1** | Curriculum workspace live + first board (CBSE) Priority-A complete | CI-A0, CI-A1 | Coverage report; integrity green | ⚪ |
| **M2** | Board-compliant generation live (**goal line G1**): governed blueprint templates + upgraded solver + multi-set/PDF v2 | CI-C1, CI-C3 (+CI-B3 seed) | EOS PASSes; extended live-cert green; 100% template-conformant papers | ⚪ |
| **M3** | All four boards acquired; repository closed out | CI-A2..A6 | Priority-A 100%/documented ×4; quality score; `READY_FOR_KNOWLEDGE_BASE_GENERATION` | ⚪ |
| **M4** | Curriculum catalogue expanded in-app (classes 6–10, all boards) + versioning | CI-B1, CI-C2 | Wizard/boundary regression; expansion migration live | ⚪ |
| **M5** | Bank growth engines live: cold-start ingestion + moderation completion + AI Validation Engine | CI-C6, CI-C5 | ≥80% auto-extraction; eval harness v0; EOS PASSes | ⚪ |
| **M6** | Exam Profile Engine + capability gating + outcome/competency tagging | CI-C7, CI-C4 (+CI-B2) | Profile validation tests; gating default-allow proof | ⚪ |
| **M7** | Knowledge close-out: PYQ/pattern store, knowledge objects, concept seed; paper↔exam link + explainability | CI-B4, CI-C8 | Reviewed concept seed; link live; selection reasons on papers | ⚪ |
| **M8** | Continuous sync v1 + dormant Phase-2 schema seed → **handoff to v3.0 Phase 2** | CI-C9, CI-E1 | Seeded-change proof; dormant migrations applied; handoff note | ⚪ |
| **M9** *(A1)* | Asset factories: Question Factory (Item Models/families/distractors) + Certified Diagram Library | CI-C10, CI-C11 | AT-C10/AT-C11 green; EOS PASSes; scoped red-team re-run | ⚪ (owner-timed A1-O1, v3.0 Phase-1→2 boundary) |

## Wave ledger (append a row per completed wave)

| Wave | Gate | Commit / evidence | Date | Notes |
|---|---|---|---|---|
| CI-A0 (partial) | Data-tooling tests 13/13 + CLI smoke + audit-gate proof | `curriculum/scripts/verification/` · [`ACCEPTANCE_TEST_PLAN.md`](ACCEPTANCE_TEST_PLAN.md) §0 AT-V1..V10 | 2026-07-07 | **Download Verification & Recovery Engine** delivered under direct owner instruction (pre-approval exception; data-lane tooling only, zero app surface) |
| M0 close | Owner approval | **🔒 Program Baseline v1.0** — D-1..D-6 recorded ([`../audits/GAP_ANALYSIS.md`](../audits/GAP_ANALYSIS.md) §3) and applied across the planning suite | 2026-07-07 | Program approved; implementation handed to Opus 4.8 via [`../OPUS_IMPLEMENTATION_HANDOFF.md`](../OPUS_IMPLEMENTATION_HANDOFF.md) |
| **Amendment A1** | Planning-package sync (no gate — doc-only) | AIMS ([`../spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md`](../spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md)) merged; delta record §6 of the gap analysis; waves CI-C10/C11 + milestone M9 appended; B11–B14, R15/R16, TD-CI-17/18, AT-C10/C11 added | 2026-07-07 | Baseline waves, G1/G2, P1-CI-0 scope and red-team position unchanged; new owner items A1-O1..O3 batched (non-blocking) |

## Update rules

1. Refresh this file at **every** wave boundary (and only then) — status, ledger row, next-wave pointer.
2. A wave enters the ledger only with its gate evidence (EOS verdict line or data-gate report path).
3. Milestone completion additionally updates the initiative [`README`](../README.md) and, if owner-visible, `docs/README.md`.
4. Drift between this tracker and reality = halt and reconcile (same rule as the master execution dashboard).
