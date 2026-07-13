# NEET Physics/Chemistry Numeric Generation — pilot expansion (certified relations)

**Date:** 2026-07-13 · **Status:** DONE. Autonomous continuation of the JEE/NEET-first program: expanded the
certified→generate→verify bridge from Biology-factual to **Physics/Chemistry numeric** (`single_step_numerical`).
**277 verified numeric questions** added to the SEPARATE pilot verified bank; combined bank now **339 verified
questions** (Biology 62 factual + Chemistry 110 + Physics 167 numeric). No gate-weakening; kie.db untouched
(read-only); derived output persisted only to the local `qie.db` pilot bank (never the Certified Bank). **498
tests green.** Evidence: `phase0_evidence/pilot_bio_neet/` (`numeric_pilot_metrics.json`,
`numtemplate_validation.json`, `pilot_verified_bank.json`).

## Why numeric expands capacity honestly

The Biology-factual pilot ceilinged at 62 (one item per exclusive verified fact). Numeric generation is
**parametric** — one certified relation yields unlimited distinct instances (new numbers) — and its
verification is **deterministic** (the relation solver), so the in-loop check costs no AI per item. This is the
scalable path, and it crosses the 300 target legitimately.

## Method

- **Certified capability = relation-solver-verified NEET relations** with ≥5-doc support (measured): V=IR (83),
  n=m/M (73), R=V/I (60), KE=½mv² (44), M1V1=M2V2 (37), m=nM (36), P=I²R (33), W=mg (33), Rseries (32),
  n=V/22.4 (24) — 10 templated.
- **Authored template per relation**, stem semantically matching the relation (never source wording).
- **Two-layer verification:** (1) template semantics validated ONCE by an **independent NEET Physics/Chemistry
  judge** — **10/10 agree, 0 flagged** (judge recomputed every answer); (2) each generated instance is
  **deterministically** verified — `relations.verify` (whole-library second solver) must reproduce the stated
  answer from the params via the certified relation, and the key must be unique among options.
- **Distractors:** governed learner-error transforms of the correct value (×2, ½, +10%) — never random,
  never fabricated.
- **Originality:** every generated parameter tuple is checked against **366 source-parameter signatures** from
  the NEET Physics/Chem corpus; source matches are rejected (0 copied numbers). Generated instances deduped.

## Metrics

| Metric | Value |
|---|---|
| Templates (certified relations) | 10 · **independently validated 10/10** |
| Total attempted | **300** |
| PASS | **277** |
| REJECT | **23** (17 duplicate-generated · 5 solver-disagreement · 1 near-copy-of-source-params) |
| QUARANTINE | 0 |
| Numeric verified added to bank | **277** |
| **Pilot verified bank total** | **339** (Biology 62 · Chemistry 110 · Physics 167) |
| Per-instance verification | **deterministic** (relation solver) — no AI cost |
| Originality | 366 source-param signatures indexed; **0 source numbers reproduced** |
| PASS by relation | V=IR 28 · R=V/I 30 · KE 28 · P=I²R 29 · W=mg 22 · Rseries 30 · n=m/M 29 · m=nM 29 · M1V1=M2V2 27 · n=V/22.4 25 |
| Operational issues | none |

The 5 SOLVER_DISAGREEMENT rejections confirm the deterministic verifier is not a rubber stamp — it rejected
instances whose stored key did not reproduce within tolerance (rounding/edge cases).

## Program status (JEE/NEET-first) — CORRECTED 2026-07-13

**Modalities proven (not "the whole NEET vertical"):** only **factual_single_best_answer** (Biology, AI-verified)
and **single_step_numerical** (Physics/Chemistry, deterministically verified) are built. NEET has many
*unbuilt* archetypes — multi-step numeric, classification, cause_effect, structure_function, assertion,
process_sequence, data/graph. So NEET is **partially** covered, not complete.

**JEE blocker reconciliation (corrected).** JEE is **NOT corpus/evidence-blocked** — the earlier "JEE evidence
= 23 items" was a **profile-mapping artifact**. Two source→profile maps disagreed: the early ad-hoc matrix put
`physicsaholics_dpps` → JEE (~2,937 physics questions); the canonical `profiles.py` puts `physicsaholics_dpps`
→ **FOUNDATION**. Measured under the canonical map:
- **FOUNDATION Physics: 3,012 items · 767 numeric-relation-verified · 15 relations ≥5-doc** (V=IR 152, R=V/I
  105, KE 59, P=V²/R 50, v=u+at 46, P=I²R 41, Rseries 38, a=(v-u)/t 30, W=mg 25, f=1/T 22, KE_from_p 16,
  efficiency 16, Rparallel 14, PE 12, gravitation 6) — a large pool of *shared JEE/NEET-foundation physics*,
  currently label-routed to FOUNDATION and **unused for generation**.
- **JEE_MAIN/ADVANCED profiles: ~19 Chem items, 0 numeric-verified** — thin only because the bulk physics
  (physicsaholics) is labeled FOUNDATION, and the JEE-specific sources are mathongo (Math/calculus) + the
  jeeadv archive.

**Corrected classification of the JEE situation:**
- ✅ **Physics/Chemistry single-step content: NOT blocked** — abundant FOUNDATION evidence (767 verified);
  usable now (this doc's expansion begins here).
- ⚠ **Profile differentiation** (JEE_MAIN vs FOUNDATION vs NEET) is coarse because the corpus labels
  foundation-physics as FOUNDATION, not per-exam — a **classification/mapping** limitation, not missing corpus.
- ❌ **JEE Mathematics (calculus) genuinely blocked** — 0 school-library-verifiable; needs a symbolic verifier
  (a distinct build).
- ❌ **JEE-Advanced multi-step depth** — needs multi-step numeric generation (a distinct build).

**Autonomous next step (unblocked):** extend numeric generation across the FOUNDATION Physics/Chemistry pool
(the 15 relations above), materially growing the verified bank — DONE below. Owner decisions remaining:
promote the pilot bank into a real Question Bank; fund the JEE Math symbolic-verifier / multi-step build; and
(optionally) re-differentiate the FOUNDATION↔JEE_MAIN profile mapping.

## FOUNDATION Physics numeric expansion (executed) — proves JEE is not corpus-blocked

Authored + **independently validated (8/8 agree)** templates for 8 additional certified FOUNDATION relations
(P=V²/R, v=u+at, a=(v−u)/t, f=1/T, KE_from_p, efficiency_pct, Rparallel, PE_g10) — the physicsaholics-backed
pool the JEE-thin diagnosis had hidden. Same two-layer verification (independent template validation +
deterministic per-instance relation-solver); originality vs **981** source-param signatures.

| Metric | Value |
|---|---|
| Templates (validated) | 8/8 |
| Attempted | **320** |
| PASS | **291** |
| REJECT | 29 (all duplicate-generated; **0 solver-disagreement, 0 source near-copies**) |
| **Pilot verified bank TOTAL** | **630** |

**Bank composition (630):** Biology×NEET **62** (factual, AI-verified) · Chemistry×NEET **110** · Physics×NEET
**167** · Physics×FOUNDATION **291** (numeric, deterministically verified). This directly demonstrates the
reconciliation: the shared JEE/NEET foundation-physics evidence is abundant and generatable — the corpus is
**not** evidence-blocked; only JEE-Mathematics (calculus) and JEE-Advanced multi-step remain genuine build
blockers.
