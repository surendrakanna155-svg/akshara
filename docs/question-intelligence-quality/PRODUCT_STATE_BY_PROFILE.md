# Question Intelligence — Product State by Assessment Profile (measured)

**Date:** 2026-07-12 · **Status:** measurement checkpoint after the Phase-C architecture correction. Corrected
`(subject × profile × concept × archetype)` pipeline run over all reused B1–B10 evidence (12,219 items, no
re-OCR, no new data). Evidence: `phase0_evidence/capability_matrix_C.json`. Quality gates and the 15-gate
ladder are **unchanged**; no generation run; `qpgen`/Certified Bank untouched. **474 tests green.**

This report answers the eight product-state questions from measured data, then gives the honest
Subject×Profile matrix and the five readiness metrics. **There is no 4/4 gate here** — capability is reported
per profile.

> **UPDATE 2026-07-13 — bounded Tier-2 pass + subject-scope cleanup.** A governed two-judge Tier-2 pass over
> the 406 already-resolved Biology×NEET factual facts (verifier + adversarial refuter, isolated; verified only
> on agreement with no contradiction) moved **Biology×NEET MODERATE → STRONG**: certified models **1 → 25**,
> then a root-cause subject-scope fix removed **5 cross-domain resolver artifacts** (PHY_VISION,
> MAT_TEMPERATURE, …) → **20 certified models, all on genuine BIO_ canonical concepts** (0 cross-domain
> concepts in any Biology certified model). Facts: 365 PASS / 25 FAIL (wrong keys caught) / 16 INSUFFICIENT —
> a **measured 6.2% source-key error rate for this governed pass** (not an assumed inherent ceiling; its
> reducibility can be measured later). Biology×NEET is now **CERTIFIED_CAPABLE** for the
> factual_single_best_answer archetype. Evidence: `phase0_evidence/tier2_bio_neet/`.
>
> **UPDATE 2026-07-13 — certified→generation bridge proven (internal, NOT the pilot).** `qie/generate.py`
> connects the certified Biology×NEET factual models to new-question generation: authored stems +
> verified-evidence answers + governed distractors + independent 2-judge verification + full provenance.
> Internal sample **15 → 11 PASS / 4 REJECT / 0 QUARANTINE** (73% verified; 0 near-copies). See
> `GENERATION_BRIDGE_SLICE.md`.
>
> **UPDATE 2026-07-13 — both pre-pilot blockers closed + controlled pilot run.** In-loop automatic verification
> + plausible-distractor mechanism wired. Pilot: **97 attempted → 62 PASS / 34 REJECT / 1 QUARANTINE**; **62
> verified questions** in a SEPARATE `pilot_verified_item` bank (not the Certified Bank); inter-judge agreement
> 91.8%, distractor plausibility 92.8% family-tier, 16/19 concepts covered, 0 near-copies. **62 = honest
> certified-model capacity of one archetype (no gate-weakening).** See `GENERATION_PILOT_NEET_BIOLOGY.md`.
>
> **UPDATE 2026-07-13 — numeric expansion (Physics/Chemistry).** Extended the bridge to `single_step_numerical`
> from 10 certified NEET relations (V=IR, n=m/M, KE, M1V1=M2V2, …); template semantics independently validated
> 10/10; parametric instances **deterministically** verified (relation solver, no AI/item); originality vs 366
> source-param signatures (0 numbers copied). Then extended to the FOUNDATION physics pool (+8 relations,
> validated 8/8): **combined pilot bank now 630 verified** — Biology×NEET 62 (factual) · Chemistry×NEET 110 ·
> Physics×NEET 167 · Physics×FOUNDATION 291 (numeric). See `GENERATION_PILOT_NEET_NUMERIC.md`.
>
> **UPDATE 2026-07-13 — JEE build + depth profiling.** (1) Item-level **depth-based** profiling
> (`profiles.item_profile`) replaces source-identity classification — JEE_MAIN now surfaces genuine items
> (Physics 511, Chem 391, Math 85). (2) **JEE-Mathematics calculus blocker CLOSED:** `generate_calculus.py`
> generates + verifies calculus SYMBOLICALLY (sympy; integrals verified by differentiation, derivatives by
> integration — independent, deterministic, no AI); pilot 100→**64 PASS** (0 symbolic-disagreement; AI phrasing
> sanity 10/10). **Pilot bank now 694** (adds Mathematics×JEE_MAIN 64). JEE was a *classification* issue +
> calculus-verifier gap, not corpus-blocked. See `GENERATION_JEE_BUILD.md`.

## Measured Subject × Profile ratings

| Subject | Profile | Rating | Certifiable models | Genuine (resolved) | Evidence-ready concepts |
|---|---|---|---|---|---|
| Physics | FOUNDATION | MODERATE | **17** | 47 | 29 |
| Physics | NEET | **STRONG** | **13** | 27 | 24 |
| Chemistry | NEET | **STRONG** | **5** | 15 | 43 |
| Biology | NEET | **STRONG** | **20** (all genuine BIO_) | 27 | **35** |
| Chemistry | NEET_FOUNDATION | THIN | 0 | 1 | 1 |
| Mathematics | NEET\* | THIN | 0 | 0 | 4 |
| Mathematics | FOUNDATION | THIN | 0 | 0 | — |
| **all subjects** | **CBSE/AP-SCERT/TS-SCERT/ICSE/BOARD_6_10** | **ABSENT** | 0 | 0 | 0 |

\*Math×NEET is `guess_subject` physics-noise misattribution, not real math. Certifiable = verified + genuine
(canonical concept, ≥5 distinct stems) + profile-valid archetype.

## The eight questions, answered from measured data

**1. What can Akshara generate well today?**
Verified, canonical-concept, diverse Item Models exist for:
- **Physics numeric (`single_step_numerical`)** — 27 certifiable models across FOUNDATION (17) + NEET (10),
  each independently **solver-verified** (relation-match). This is the strongest capability.
- **Chemistry NEET** — 5 certifiable (3 factual + 2 numeric).
- **Biology × NEET factual recall** — **now CERTIFIED** (bounded Tier-2 pass + subject-scope cleanup,
  2026-07-13): **20 genuine BIO_ canonical-concept certified models** (0 cross-domain artifacts) across the
  core NEET chapters
  (photosynthesis, reproduction, proteins, respiration, excretory, endocrine, neural, circulatory,
  respiratory, molecular basis, mitochondria, ecosystem, immunity, plasma, evolution, biodiversity, cell
  membrane, populations, cancer), each with 5–27 distinct stems from ≥2 docs.
- **Physics/Chemistry NEET factual recall** — a few certified; broad evidence.
These are ready to *scale-test* behind the gold benchmark (quality) + qpgen paper-feasibility (paper), per
profile — not yet to ship.

**2. What can it generate experimentally?**
- **Physics × NEET `experiment_inference`** (1 model) — a real non-numeric archetype beginning to appear.
- **Non-factual Biology archetypes** (cause_effect, classification, assertion_reason) — only 1 certified so
  far; broadening archetype coverage beyond factual recall is the next Biology step.
- *(Biology × NEET factual recall is no longer merely experimental — it is CERTIFIED, see Q1.)*

**3. Which profiles are blocked by missing assessment evidence?**
- **Every board/school profile — BOARD_6_10, CBSE_6_10, AP_SCERT_6_10, TS_SCERT_6_10, ICSE_6_10 — is
  ABSENT**: 0 recovered assessment items (those sources are textbooks → concepts, not question papers).
- **JEE_MAIN / JEE_ADVANCED** are THIN (evidence sparse and calculus-heavy).
- **Any school-Mathematics profile** is effectively blocked (genuine school-math ≈ 0; corpus is JEE calculus).
These profiles require **assessment-evidence acquisition**, not more mining of the current corpus.

**4. Which archetypes are strong?**
- `single_step_numerical` (Physics/Chemistry) — strongest; deterministic solver verification.
- `factual_single_best_answer` (Biology/Chemistry/Physics × NEET) — strong *evidence*, verification-limited.

**5. Which archetypes are absent (uncertified)?**
`multi_step_numerical`, `reverse_numerical`, `missing_variable_inference` (the classifier does not yet
separate these from single-step — a known next step), `graph_interpretation`, `table_interpretation`,
`diagram_interpretation` (visual/data — 0 certified), `constraint_reasoning`, `multi_concept_integration`,
`case_interpretation`, `error_analysis`, `property_application` (0 certified), `assertion_reason` (present in
DNA, few certified). All higher-order and visual/data archetypes are currently absent from certified output.

**6. Where is verification strong / weak?**
- **Strong:** numeric (`relation_solver`) — deterministic, ~40 certified numeric models.
- **Strengthened (2026-07-13):** conceptual verification (KVS multi-source + Tier-2) coverage grew from 46 to
  **411 verified facts** after the bounded Biology×NEET Tier-2 pass — certifying 20 Biology concepts. The
  pass also **caught 25 wrong source keys** (6.2%), proving the lane verifies rather than rubber-stamps.
  Remaining gap: other subjects/profiles' conceptual facts are still thinly verified, and figure-dependent
  facts (16 INSUFFICIENT here) need the visual pipeline.

**7. Where is difficulty control weak?**
**Everywhere** — `difficulty_driver_support.measured = false` in every cell. The pipeline computes no measured
difficulty-driver vectors yet (that is the psychometric/difficulty-driver spec, not built). Difficulty labels
are currently unvalidated across all subjects/profiles — a cross-cutting gap that no amount of yield fixes.

**8. Where are visuals available but not generation-ready?**
qcorpus preserved **70,541 visual assets + 91,878 equation candidates**, but the corrected DNA is text-only and
`visual_support.measured = false` in every cell. The `DIAGRAM_VISUAL` / `DATA_INTERPRETATION` archetypes have
real *evidence potential* (assets exist) but **0 generation-ready models** — those lanes are Phase-E and not
wired. Diagram/graph/table interpretation is blocked on the visual pipeline, not on evidence.

## Five readiness metrics (separate; measured where possible)

1. **Capability coverage (per profile):** NEET **2/9 core archetypes** certified (factual_single_best_answer
   + cause_effect, after the 2026-07-13 Tier-2 pass); FOUNDATION **1/7** (single_step_numerical). Still
   verification-coverage-limited for the remaining archetypes.
2. **Evidence readiness (resolved concepts ≥5-DNA/≥2-res):** Chemistry/NEET **43**, Biology/NEET **35**,
   Physics/FOUNDATION **29**, Physics/NEET **24**, Math/NEET 4. *Strong and real.*
3. **Quality readiness:** gold benchmark — Phase-0 Hyp-B substance **PASSED** (absolute bar/agreement/
   Biology-specific); per-profile benchmark **PENDING** (not re-run here).
4. **Scale readiness:** 36 certifiable models, median **8** distinct stems — a proxy for non-clone parameter
   diversity; adequate for the certified numeric models, thin elsewhere.
5. **Paper readiness:** **not measured** — requires a target blueprint per profile via qpgen feasibility;
   next step, not this slice.

## Honest bottom line

The corrected model shows Akshara's real state: **it can genuinely generate verified NEET/Foundation numeric
Physics/Chemistry AND (as of 2026-07-13) verified NEET Biology factual recall (20 certified concepts), and has
essentially no board-profile or school-Mathematics assessment capability because that evidence was never
acquired.** The remaining per-profile, evidence-driven steps — broadening Biology archetype coverage beyond
factual recall; difficulty drivers; the visual pipeline; and assessment-evidence acquisition for board
profiles — **none of which is the historical 4/4 gate.**

**STOP for owner approval.** No large-scale generation; no production families; Certified Question Bank
untouched; no market-quality claim; quality gates unchanged; `qpgen`/`kie.db` untouched.
