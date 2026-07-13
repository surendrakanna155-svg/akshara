# JEE build — depth-based profiling + symbolic JEE-Mathematics calculus generation

**Date:** 2026-07-13 · **Status:** DONE (autonomous). Delivers the two things the reconciliation identified:
(1) **item-level depth-based profile differentiation** (not source identity), and (2) the **JEE-Mathematics
build** — symbolic calculus generation with independent symbolic verification. Pilot verified bank now **694**
(adds Mathematics×JEE_MAIN 64). `kie.db`/`qpgen`/Certified Bank untouched; derived output only in the local
`qie.db` pilot bank. **508 tests green.** Evidence: `phase0_evidence/pilot_bio_neet/`.

## 1. Item-level depth-based profiling (`profiles.item_profile`)

Per owner directive — a source is no longer classified wholesale. `item_profile(subject, stem, answer,
distinct_given, single_relation, source_profile)` decides from **content depth**:
- Biology → **NEET** (medical-entrance domain);
- calculus markers (real ∫ / d/dx / derivative / integral / maxima-minima; no bare-`dx` false positives) →
  **JEE_MAIN**;
- single-relation numeric → **FOUNDATION** (shared JEE/NEET foundation);
- multi-quantity numeric with no single-relation solution → **JEE_MAIN** (multi-step depth);
- else → the (weak) source profile.

Re-measured by depth, **JEE_MAIN is no longer empty**: Physics **511**, Chemistry **391**, Mathematics **85**
(calculus + multi-quantity) surface as genuine JEE-level items that source-labelling had hidden; single-step
physics correctly stays FOUNDATION (3,310). This confirms JEE was a **classification** issue, not corpus-blocked.

## 2. JEE-Mathematics symbolic calculus generation (`generate_calculus.py`)

Calculus is the JEE-distinctive Math construct the school relation library cannot verify. It is now generated
**and verified SYMBOLICALLY** with sympy 1.14.0, using the **inverse operation** as an independent,
deterministic check:
- **Integrals:** build integrand `f`, answer `F = ∫f dx`; **verify `dF/dx == f`**.
- **Derivatives:** build `f`, answer `g = df/dx`; **verify `∫g dx == f`**.
- Families: polynomial integral / polynomial derivative / trig derivative / exponential integral.
- **Distractors** are common-error symbolic perturbations (forgot ÷(n+1), wrong power, differentiated instead
  of integrated, dropped constant), each checked to **genuinely fail** the inverse-op verification (no second
  correct answer). Nothing fabricated — every value is a sympy result. **No AI needed per item.**

**JEE-Math calculus pilot:** 100 attempted → **64 PASS / 36 REJECT** (all duplicate-generated from limited
parameter ranges; **0 symbolic-disagreement**). PASS by family: poly_integral 25 · poly_derivative 24 ·
trig_derivative 10 · exp_integral 5. Persisted 64 to the bank as **Mathematics × JEE_MAIN**. Independent
JEE-Math judge phrasing sanity-check on a sample: see `calc_sanity_verdict.json`.

## Pilot verified bank — now 694

| Subject × Profile | Count | Modality / verification |
|---|---|---|
| Biology × NEET | 62 | factual — AI 2-judge |
| Chemistry × NEET | 110 | single-step numeric — deterministic relation solver |
| Physics × NEET | 167 | single-step numeric — deterministic relation solver |
| Physics × FOUNDATION | 291 | single-step numeric — deterministic relation solver |
| **Mathematics × JEE_MAIN** | **64** | **calculus — deterministic symbolic (inverse-op)** |
| **Total** | **694** | |

## Remaining measured work (JEE/NEET-first)

- **JEE multi-step Physics/Chemistry** (the depth-classified 511/391 multi-quantity items) — needs a
  multi-step numeric generator + verifier (a distinct build; the "multi-quantity" heuristic also contains OCR
  noise, so evidence quality must be measured first).
- **More calculus breadth** (definite integrals, product/quotient/chain-rule derivatives, limits) — extends
  JEE-Math capacity cleanly on the same symbolic-verification substrate.
- **NEET non-factual archetypes** (classification / cause_effect / assertion) — archetype-specific generation.
- **Promotion of the pilot bank → real Question Bank — owner decision.**

Continuing autonomously on the unblocked items (calculus breadth, multi-step after an evidence-quality check).
Pilot bank stays separate until owner approval to promote.
