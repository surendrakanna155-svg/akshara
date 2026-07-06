# Curriculum Intelligence — Implementation Phases

**Date:** 2026-07-06 · Wave detail in [`IMPLEMENTATION_SEQUENCE.md`](IMPLEMENTATION_SEQUENCE.md); calendar mapping in [`SPRINT_PLAN.md`](SPRINT_PLAN.md).
**Phase naming:** `CI-P#` to avoid collision with the frozen master roadmap's `P0–P8`.

---

## CI-P0 — Foundation & Approval (this deliverable)

Spec docs relocated + indexed · audits + gap analysis + backcompat plan · full planning suite · owner decision batch D-1..D-4 surfaced. **Exit:** owner approval of scope, sequencing, and decisions. *No code, no downloads.*

## CI-P1 — Curriculum Acquisition (data lane; spec Parts 02–08)

Waves CI-A0 → CI-A6. Build the curriculum workspace and acquire the official corpus in owner order **CBSE → AP SCERT → TS SCERT → CISCE** (D-4; classes 6–10, English medium), with full metadata/index/coverage discipline.

- **Deliverables:** organized repository, per-resource metadata + SHA-256, master/secondary/search indexes, coverage + quality + license + missing-resource reports, PM files.
- **Exit:** spec Part 07 targets (Priority-A 100% or documented; Priority-B ≥95%); **Repository Certification granted (D-5)** — `Downloaded → Verified → Repository Certified` proven by audit PASS + certification evidence; **CI-P2 may never start before certification**.
- **Character:** long-lead, externally-bounded, resumable (checkpointed); zero app risk.

## CI-P2 — Knowledge Engineering (data lane; spec Part 09 + data half of 10)

Waves CI-B1 → CI-B4 (pipelined behind CI-P1 per board). Convert the corpus into structured datasets: chapter/topic trees, learning outcomes, competencies, blueprint-template transcriptions, PYQ pattern store, canonical-concept seed proposal.

- **Exit:** datasets validated + source-traced; blueprint templates cross-checked against official specimen papers; concept seed reviewed.
- **Constraint:** verbatim extraction only — never invent (spec Part 16 golden rule).

## CI-P3 — Engine Completion (code lane; spec Parts 12–14 ∩ v3.0 Phase 1)

Waves CI-C1 → CI-C8 (EOS-gated). The certified engine becomes a board-compliant, profile-aware, validated-generation platform:

1. CI-C1 blueprint templates + constraint solver upgrade (flagship)
2. CI-C2 curriculum catalogue expansion (all boards 6–10) + versioning
3. CI-C3 multi-set + PDF v2 + exports
4. CI-C4 outcome/competency schema + tagging
5. CI-C5 AI Validation Engine (blind-solve, quality scoring, revisions — the AI_VALIDATED gate of the D-6 lifecycle)
6. CI-C6 bank cold-start ingestion (school-owned papers, OCR-first; **after CI-C5** per D-6 — full `RAW → … → CERTIFIED` lifecycle)
7. CI-C7 Exam Profile Engine + capability gating
8. CI-C8 paper↔exam link + exposure/rotation + explainability

- **Exit:** every generated paper conforms to a governed template (v3.0 §18 Phase-1 KPI = 100%); live-cert extended and green; all certified invariants intact.

## CI-P4 — Synchronization & Handoff (spec Part 15 + v3.0 §5.3)

Waves CI-C9 + CI-E1. Continuous-sync v1 over the repository; dormant Phase-2 schema seed (response spine, trust status, item statistics, canonical concepts).

- **Exit:** change-detection proven end-to-end; dormant migrations applied; program hands off to 🔒 v3.0 **Phase 2** (marks-grid, item statistics, trust pipeline) which remains owner-scheduled outside this program.

---

## Phase-boundary rules

- Data-lane phases gate on **data-quality criteria** (spec Parts 07/08); code-lane waves gate on **EOS FEATURE PASS** per commit (Constitution — no exceptions).
- CI-P1/P2 (data) and CI-P3 (code) may overlap under owner decision D-1; CI-C1 may start on a hand-transcribed template subset before CI-P1 completes.
- No phase may begin work reserved to a later v3.0 phase (D11): no response collection, no trust-pipeline activation, no mastery/adaptive features — CI-E1 seeds schema only, dormant.
- Every phase ends by updating [`MILESTONE_TRACKER.md`](MILESTONE_TRACKER.md) and the initiative README.
