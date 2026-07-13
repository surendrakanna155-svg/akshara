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

## Program status (JEE/NEET-first)

- **NEET Biology factual — pilot done** (62 verified, AI-verified).
- **NEET Physics/Chemistry numeric — pilot done** (277 verified, deterministically verified). **Bank ≥ 300.**
- **Remaining measured blockers** (not started; genuine build work, not owner decisions):
  - NEET Biology non-factual archetypes (cause_effect / classification) — need archetype-specific frames.
  - **JEE Main/Advanced** — 0 certified models (readiness check); needs the certified→verify pass on JEE
    evidence first (JEE Math is calculus — needs a symbolic verifier).
  - Difficulty-driver calibration + visual pipeline remain unbuilt (cross-cutting, owner-gated).
  - Promotion of the pilot bank into a real Question Bank — **owner decision**, not started.

Continuing the expansion (more relations, NEET Biology archetypes, then JEE) closes only measured blockers.
The pilot bank stays separate until owner approval to promote.
