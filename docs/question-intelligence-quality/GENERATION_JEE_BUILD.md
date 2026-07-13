# JEE build — depth-based profiling + symbolic JEE-Mathematics calculus generation

**Date:** 2026-07-13 · **Status:** DONE (autonomous). Delivers the two things the reconciliation identified:
(1) **item-level depth-based profile differentiation** (not source identity), and (2) the **JEE-Mathematics
build** — symbolic calculus generation with independent symbolic verification, then a **breadth expansion**
(9 calculus families). Pilot verified bank now **851** (adds Mathematics×JEE_MAIN **221**). `kie.db`/`qpgen`/
Certified Bank untouched; derived output only in the local `qie.db` pilot bank. **507 tests green.** Evidence:
`phase0_evidence/pilot_bio_neet/`.

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
- **Integrals:** build integrand `f`, answer `F = ∫f dx`; **verify `dF/dx == f`** (exactly).
- **Derivatives:** build `f`, answer `g = df/dx`; **verify `∫g dx − f` is a constant** (i.e. `d/dx(∫g − f)==0`)
  — the mathematically correct independent check even when `f` carries a constant term (e.g. an expanded
  `(ax+b)ⁿ`).
- **Distractors** are common-error symbolic perturbations (forgot ÷(n+1), wrong power, differentiated instead
  of integrated, dropped constant), each checked to **genuinely fail** the inverse-op verification (no second
  correct answer). Nothing fabricated — every value is a sympy result. **No AI needed per item.**

**Breadth (9 families).** Initial 4 (poly integral/derivative, trig derivative, exp integral) then +5 on the
same substrate: **trig integral · exp derivative · log derivative (a·ln x → a/x) · chain-poly integral
`∫(ax+b)ⁿ` · chain-poly derivative**. All verified by the uniform inverse-operation check.

**JEE-Math calculus pilot:** first run 100 → 64 PASS (0 symbolic-disagreement; independent AI phrasing
sanity **10/10** — `calc_sanity_verdict.json`). Breadth run 360 attempted → **182 PASS / 178 REJECT** (every
REJECT is `DUPLICATE_GENERATED` from saturating small integer parameter ranges — an honest capacity ceiling,
**0 symbolic-disagreement**). After dedup on the deterministic `gen_id` (family+integrand), the bank holds
**221 distinct verified calculus items** as **Mathematics × JEE_MAIN**, by family: poly_integral 58 ·
poly_derivative 59 · chain_poly_integral 34 · chain_poly_derivative 31 · trig_derivative 11 · trig_integral 10 ·
log_derivative 8 · exp_integral 5 · exp_derivative 5.

## Pilot verified bank — now 851

| Subject × Profile | Count | Modality / verification |
|---|---|---|
| Biology × NEET | 62 | factual — AI 2-judge |
| Chemistry × NEET | 110 | single-step numeric — deterministic relation solver |
| Physics × NEET | 167 | single-step numeric — deterministic relation solver |
| Physics × FOUNDATION | 291 | single-step numeric — deterministic relation solver |
| **Mathematics × JEE_MAIN** | **221** | **calculus (9 families) — deterministic symbolic (inverse-op)** |
| **Total** | **851** | |

## Remaining measured work (JEE/NEET-first)

- **JEE multi-step Physics/Chemistry** (the depth-classified 511/391 multi-quantity items) — needs a
  multi-step numeric generator + verifier (a distinct build; the "multi-quantity" heuristic also contains OCR
  noise, so evidence quality must be measured first).
- **More calculus breadth** (definite integrals, product/quotient rule, limits) — extends JEE-Math capacity
  cleanly on the same symbolic-verification substrate (9 families done; chain-rule + log/trig/exp added).
- **NEET non-factual archetypes** (classification / cause_effect / assertion) — archetype-specific generation.
- **Promotion of the pilot bank → real Question Bank — owner decision.**

Continuing autonomously on the unblocked items (calculus breadth, multi-step after an evidence-quality check).
Pilot bank stays separate until owner approval to promote.
