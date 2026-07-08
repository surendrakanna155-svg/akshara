# Curriculum Intelligence — Proposals Register

**Purpose:** the canonical index of **planning proposals / amendments** to the Curriculum
Intelligence program that are **not yet merged** into the frozen Baseline (spec + roadmap). A
proposal lives here — tracked, discoverable, traceable — from the moment it is drafted until the
owner ratifies it and its deltas are folded into the frozen documents. Nothing in this folder
changes the frozen `FINAL_EXECUTION_MASTER_ROADMAP.md`, the verbatim `spec/` drops, the owner
decisions D-1…D-6, the invariants I1–I8, or the CI wave sequencing until ratified.

**Lifecycle states:** `Drafting` → 🟡 `Pending Owner Ratification` → ✅ `Ratified (merged)` /
🗑 `Withdrawn`.

## Register

| ID | Title | State | Owner-approved? | Frozen-doc merge targets (on ratification) | Doc |
|---|---|---|---|---|---|
| **A1** | AIMS spec synchronization | ✅ **Ratified (merged 2026-07-07)** | ✅ | Merged — delta record in [`../audits/GAP_ANALYSIS.md`](../audits/GAP_ANALYSIS.md) §6 | (folded into Baseline v1.0) |
| **A2** | Deterministic Per-Student Practice & DPP Generation Engine | 🟡 **Pending Owner Ratification** | ✅ **Direction + D-7 + I9 + §12 approved (2026-07-08)** | `GAP_ANALYSIS.md` D-register (D-7) · `BACKWARD_COMPATIBILITY_PLAN.md §1` (I9) · MCIP/AIMS generation-mode + family-certification sections · wave scopes CI-C10/C1/C3/C8 · v3.0 §13 | [`AMENDMENT_A2_PER_STUDENT_PRACTICE_GENERATION.md`](AMENDMENT_A2_PER_STUDENT_PRACTICE_GENERATION.md) |

## A2 at a glance (Pending Owner Ratification)

- **What:** make the certified unit the **Question *Family*** (D-7), so the deterministic engine can
  mint **unlimited per-student parameterized instances** at runtime with **zero runtime AI (I9)** —
  enabling per-student-unique papers (100 students → 100 papers), N sets, daily DPPs, and unlimited
  practice, across every exam type (school / worksheet / homework / DPP / Foundation / Olympiad /
  IIT-JEE / NEET / scholarship).
- **Owner-approved (2026-07-08):** direction · **D-7** (family-level certification) · **I9**
  (zero-runtime-AI invariant) · six principles §12 (Repository-First, Adaptive deterministic engine,
  generation modes, generation controls, exam-agnostic architecture, large-repository vision).
- **Still-open parameters:** per-student non-repetition window *N*; answer-key-at-scale acceptance
  check.
- **Integrates onto (no new lane, no sequencing change):** CI-C10 (family certification) · CI-C1
  (runtime instantiation) · CI-C3 (modes) · CI-C8 (per-student non-repetition) · v3.0 §13 (DPP).
  Implements **post-pilot (v3.0 Phase 1+)** per the frozen Option A; content scale depends on the
  ⏳ owner/network-gated DATA lane (CI-A1…A6).
- **Does NOT:** modify the frozen master roadmap · change CI sequencing · merge into the verbatim
  specs · begin implementation.

## Rules for this register

- Every new proposal gets a row here **and** a back-link from at least: this register, the program
  [`../README.md`](../README.md), the relevant delta ledger (`../audits/GAP_ANALYSIS.md`), and the
  planning docs it would touch — so a proposal can never be orphaned.
- A proposal is refreshed here at every planning boundary until it is ratified or withdrawn.
- Ratification is an **owner** action; only then do its deltas merge into the frozen documents.
