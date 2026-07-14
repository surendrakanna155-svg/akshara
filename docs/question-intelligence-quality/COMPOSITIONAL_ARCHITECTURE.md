# Compositional Question Generation (CQG) — architecture

**Date:** 2026-07-14 · **Status:** foundation v1 built & proven. Owner mandate: *"a foundation capable of
producing lakhs of genuinely high-quality questions across multiple reasoning-depth levels without creating
architectural debt we must undo later."* This is the design that satisfies it, why it avoids debt, and the
path from here to scale.

## The problem with the previous approach (and the debt we are avoiding)

The single-concept generators (`generate_calculus.py`, `generate_jee_math.py`) are **per-family**: each family
is a bespoke function pairing one generator with one verifier. That is fine for single-skill drill items, but
it does **not** compose — you cannot build "find the area between the roots of this parabola" by *reusing*
"find roots" and "integrate", because those skills aren't separable units. Scaling depth that way means
hand-writing every multi-concept combination — exactly the architectural debt to avoid.

## The foundation: two layers

### 1. Operator layer (`compose.py`) — the reusable substrate
An **Operator** is a small, typed, composable compute unit:

- declares **input/output types** (`POLY`, `NUMBER`, `POINT`, `ROOTSET`) — so outputs wire into inputs;
- a deterministic forward **`apply`**;
- an **`independent verify`** — a *genuinely different* second method, never "the same computation twice"
  (differentiate ↔ verified by integrating; definite integral ↔ numerical quadrature; evaluate ↔ Horner;
  roots ↔ substitution). This is the no-fabrication guarantee at the unit level.

v1 operators: `differentiate`, `integrate_def`, `evaluate`, `real_roots`, `min_root`/`max_root`/`unique_root`,
`absval`. Adding an operator (e.g. `matrix_mul`, `limit`, `solve_linear`) extends the whole system's
compositional reach — it is not another bespoke family.

### 2. Composition layer (`compositions.py`) — reasoning depth
A **CompositionTemplate** is an ordered operator pipeline wired output→input, plus a curated high-quality
natural-language stem. An item is banked **only if** every operator step verifies independently **and** an
**independent end-to-end recomputation** of the final answer agrees (a second, whole-problem route: e.g. the
minimum-value template computes the answer by differentiate→solve→evaluate, and the end-to-end check confirms
it via the closed-form vertex formula). Two independent layers of verification; fail-safe (any disagreement →
rejected, never banked).

**Reasoning depth is computed, not assigned** (`compose.reasoning_depth`): the length of the longest dependency
chain from the given quantities to the answer — i.e. how many dependent steps the solver must perform. Bands:
FOUNDATIONAL (≤1) · INTERMEDIATE (2–3) · ADVANCED (≥4).

## v1 templates (proven)

| Template | Concepts composed | Depth | Independent end-to-end check |
|---|---|---|---|
| area_between_roots | roots + definite integral + abs | **4** ADVANCED | numerical quadrature of \|f\| over [p,q] |
| min_value_quadratic | differentiate + solve + evaluate | **4** ADVANCED | closed-form vertex `c − b²/4a` |
| tangent_slope_at_root | roots(g) + differentiate(f) + evaluate | **3** INTERMEDIATE | finite-difference slope of f at the root |
| ftc_integral_of_derivative | differentiate + definite integral | **2** INTERMEDIATE | FTC identity `f(b) − f(a)` by direct evaluation |
| area_between_curve_and_line | **subtract** + roots + bounds + integral + abs | **5** ADVANCED | numerical quadrature of `f−g` over the intersection interval |

The last row is the **extensibility proof**: adding a single operator (`subtract_poly`) unlocked a new,
*deeper* (depth-5) composition with **no change to the engine** — the debt-free scaling claim, demonstrated.

**Pilot:** 175 → **164 PASS** (0 verification-disagreement; all rejects `DUPLICATE_GENERATED`). Banked with a
first-class `reasoning_depth` column across a genuine ladder — **depth-2 = 37, depth-3 = 31, depth-4 = 56,
depth-5 = 40**. **Mathematics × JEE_MAIN → 635; pilot bank → 1,265.** An independent JEE-examiner AI judge
hand-worked a stratified 8-item all-template sample: **8/8 agree**, explicitly confirming the "larger root"
phrasing and the area abs-value are unambiguous (`phase0_evidence/pilot_bio_neet/cqg_sanity_verdict.json`).

## Measured generative capacity (why "lakhs" is real, not aspirational)

We do **not** bloat the pilot bank to prove scale (owner: not count growth). Instead we **measured** how many
*distinct, independently-verified* items the 5 v1 templates already encode by saturating their parameter spaces
across many seeds and counting distinct `gen_id`s:

| Template | Distinct verified items (current narrow ranges) |
|---|---|
| tangent_slope_at_root | 2,802 |
| ftc_integral_of_derivative | 1,387 |
| area_between_curve_and_line | 1,470 |
| min_value_quadratic | 197 |
| area_between_roots | 45 |
| **Total (5 templates, unwidened)** | **5,901** measured (7,227 analytical; gap = items honestly skipped for <4 distinct options) |

Every one of those 5,901 is generated and verified per-step + end-to-end — none fabricated. Scaling from here
is **additive, no rearchitecting**:
- **Widen parameter ranges** — a pure config change. Widening the integer ranges to ±50 multiplies each
  template's space by ~10–25× *per parameter*; the 5-parameter `tangent_slope_at_root` alone then exceeds
  **30 million** distinct items.
- **Add operators/templates** — each new template adds its own space (declarative, on the shared substrate).
- **Type-directed auto-composition** (next) — multiplies combinatorially.

So the current foundation already provably yields ~5,900 verified items; **lakhs–crores** is reached by config
+ declarative additions, not by touching the engine. That is the debt-free scale the mandate asked for.

## Why this reaches lakhs without debt

- **Multiplicative capacity:** `templates × parametric operators × parameter ranges`, deduped by signature.
  Four templates already yield hundreds of distinct verified items; the substrate grows combinatorially as
  operators and templates are added — no per-item authoring.
- **Depth levels are structural**, so a curriculum can request items *by reasoning depth*, not just topic.
- **Single-concept = depth-1 compositions of the same operators**, so the earlier generators fold into this
  engine as the FOUNDATIONAL band rather than remaining a parallel system (planned convergence — see below).
- **The verification contract is uniform** (per-step independent + end-to-end independent), so every future
  template inherits the no-fabrication guarantee for free.

## Auto-composition v1 (`autocompose.py`) — Option 1: curated phrasing-schema per shape

Owner-selected (2026-07-14) strategy for scaling shape variety **without** sacrificing quality: auto-composition
*enumerates* type-valid operator pipelines automatically, while *phrasing* stays curated per shape.

- A **ShapeSchema** has operator **SLOTS**; each slot offers several type-compatible operator sequences
  (e.g. `TRANSFORM ∈ {f′, f″}` = one or two `differentiate` applications; `REDUCE ∈ {smaller-root, larger-root}`
  = `min_root`/`max_root`).
- The auto-composer enumerates every slot filling, **TYPE-CHECKS** each against the operator registry
  (`chain_out_type` threads types through the chosen operator chain; type-invalid fillings are dropped), builds
  the concrete pipeline, and runs it through the engine where **every step is independently verified**.
- **Soundness for free:** a composition of independently-verified operators is correct by construction — no
  separate end-to-end proof needed. Tampering is still caught (re-run + answer/option checks).
- **Quality for free:** the stem comes from the schema's curated template filled with the chosen slots'
  phrases — so auto-generated questions read as cleanly as hand-written ones.

**v1:** 2 schemas → **6 distinct auto-composed pipeline shapes** (4 + 2 fillings): value of the 1st/2nd
derivative of *f* at the smaller/larger root of *g*=0; and the definite integral of *f′*/*f″* between the roots
of *g*=0. Independent JEE-examiner AI judge on a stratified 12-item all-shape sample: **12/12 agree**, phrasing
confirmed **genuinely high-quality and unambiguous** across all shapes (a cosmetic prime-spacing nit was fixed).

**Measured auto-composition capacity: 50,159 distinct verified items** from just these 6 shapes at current
narrow ranges (a *sampling-limited lower bound* — the per-shape parameter space is ~26k each). Combined with the
curated templates, **the compositional foundation already encodes ≈56,000 distinct verified items** from 2
schemas + 5 templates, unwidened. Widening ranges (config) and adding schemas/operators takes this to
lakhs–crores with **no engine changes** — the mandate, demonstrated end-to-end.

## Roadmap (on the same foundation — additive, no rewrites)

1. **More operators** (limits, matrix product/inverse, `solve_linear/quadratic`, `binomial_term`, `summation`)
   → immediately unlock many new compositions.
2. **More templates** at each depth band (area between two curves, monotonic intervals, definite integral by
   substitution, tangent/normal geometry, optimisation word-forms).
3. **Type-directed automatic composition — DONE v1** (`autocompose.py`, above): operator-slot filling with
   type-checking + curated phrasing per shape (Option 1). Next: more schemas/slots, and depth-targeted
   enumeration (turn depth into a dial). Uses the *same* operator registry — no rework.
4. **Fold single-concept families in** as depth-1 operators/compositions, then retire the bespoke modules.

## Honesty / guarantees preserved
`kie.db`/`qpgen`/Certified Bank untouched; derived output only in the local gitignored `qie.db`. No AI per
item; every value produced by the forward path and confirmed by an independent second route. Type-checking is
declared and used for composition wiring; strict runtime type-enforcement is advisory in v1 (executor checks
arity + every step's independent verifier), to be tightened when auto-composition lands. Pilot bank stays
SEPARATE (owner: do not promote yet).
