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

## Why this reaches lakhs without debt

- **Multiplicative capacity:** `templates × parametric operators × parameter ranges`, deduped by signature.
  Four templates already yield hundreds of distinct verified items; the substrate grows combinatorially as
  operators and templates are added — no per-item authoring.
- **Depth levels are structural**, so a curriculum can request items *by reasoning depth*, not just topic.
- **Single-concept = depth-1 compositions of the same operators**, so the earlier generators fold into this
  engine as the FOUNDATIONAL band rather than remaining a parallel system (planned convergence — see below).
- **The verification contract is uniform** (per-step independent + end-to-end independent), so every future
  template inherits the no-fabrication guarantee for free.

## Roadmap (on the same foundation — additive, no rewrites)

1. **More operators** (limits, matrix product/inverse, `solve_linear/quadratic`, `binomial_term`, `summation`)
   → immediately unlock many new compositions.
2. **More templates** at each depth band (area between two curves, monotonic intervals, definite integral by
   substitution, tangent/normal geometry, optimisation word-forms).
3. **Type-directed automatic composition:** because operators declare types, an auto-composer can *generate*
   valid pipelines by type-matching (output type → next input type), with depth as a target — turning depth
   levels into a dial. v1 keeps curated templates for phrasing quality; auto-composition is the scale lever and
   uses the *same* operator registry (no rework).
4. **Fold single-concept families in** as depth-1 operators/compositions, then retire the bespoke modules.

## Honesty / guarantees preserved
`kie.db`/`qpgen`/Certified Bank untouched; derived output only in the local gitignored `qie.db`. No AI per
item; every value produced by the forward path and confirmed by an independent second route. Type-checking is
declared and used for composition wiring; strict runtime type-enforcement is advisory in v1 (executor checks
arity + every step's independent verifier), to be tightened when auto-composition lands. Pilot bank stays
SEPARATE (owner: do not promote yet).
