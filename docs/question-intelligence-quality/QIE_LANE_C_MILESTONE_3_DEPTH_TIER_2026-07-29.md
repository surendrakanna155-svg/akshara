# QIE Lane C — Milestone 3: the depth tier

**Date:** 2026-07-29 · **Branch:** `feature/program-d-knowledge-bank-integration`
**Owner direction:** *"Do not stop at single-concept questions… bind the existing operator DAG and
composition engine to the certified knowledge so the engine can generate genuinely multi-concept,
deep-reasoning, IIT-quality questions."*
**Predecessors:** architecture verification (W1–W9) · Lane C Milestone 2.

---

## 1. Verdict

The depth tier is live. Lane C now generates **multi-concept, multi-step questions bound to certified
knowledge**, at earned reasoning depths of 2 and 3, and **every one of them passes the full 22-gate battery
with zero FATAL and zero QUARANTINE failures.**

| | Milestone 2 | Milestone 3 |
|---|---|---|
| Depth distribution | 1 only | **1 (36) · 2 (11) · 3 (3)** |
| Difficulty distribution | `easy` only | **easy 36 · moderate 14** |
| Archetypes | `single_step_numerical` | + **`multi_step_numerical`** |
| Concepts per question | 1 | **up to 3, each separately certified** |
| Depth-tier gate result | — | **15/15 pass, 0 FATAL, 0 QUARANTINE** |
| Regression | 1349 | **1363 passed, 0 failures, 0 errors** |

## 2. What a depth-tier question is

A `Chain` is an ordered DAG of certified relations wired output → input — exactly the shape
`factory.gates.replay_steps` already executes. The Class-10 electricity chain:

```
Q, t     --[Electric Current and Circuit   KC_f447c276f0d004 : I = Q/t   ]--> I
I, R     --[Ohm's Law                      KC_2816f176eab3b0 : V = I*R   ]--> V
V, I, t  --[Joule's Law of Heating         KC_4b01e0743f2482 : H = V*I*t ]--> H     earned depth 3
```

Every step names the certified concept that attests **its own** relation, and every one is grounded against
the frozen index by the Milestone-2 grounding rule. A three-step question is therefore three separately
certified claims, not one large assertion.

### The guarantee: two independently-derived routes must agree

Each chain also declares a `composed` relation written purely in the given symbols
(`H = (Q/t)**2 * R * t`). That yields two genuinely different ways to the key:

* **route A** — execute the DAG step by step (`gates.replay_steps`), which never sees the composed form;
* **route B** — solve the single composed relation (`gates.independent_solve`), which never sees an
  intermediate.

An item ships only if both, plus a round-trip substitution, produce the same number. A chain whose composed
relation is not actually the algebraic composition of its steps is refused rather than shipped — pinned by
`test_a_composed_relation_that_is_not_the_chain_is_refused`.

### The depth cannot be faked

`replay_steps` counts only steps sympy actually solved from values already in the environment. A flat DAG
whose steps all read the givens earns depth 1 no matter how many steps are listed — pinned by
`test_padding_the_step_list_cannot_inflate_depth`. `depth_agreement` (QUARANTINE) then refuses any item
whose claimed depth differs from the earned one, and `composition_backed` (QUARANTINE) refuses a `multi`
claim not backed by ≥2 distinct relations actually applied.

## 3. The five chains

| Chain | Class | Certified concepts combined | Depth |
|---|---|---|---|
| `CHN_MAT8_PHY8_VOLUME_DENSITY` | 8 | Volume of a Cuboid (Maths) → Density (Physics) | 2 |
| `CHN_PHY9_WORK_TO_SPEED` | 9 | Work Done by a Constant Force → Work-Energy Theorem | 2 |
| `CHN_PHY10_CHARGE_TO_HEAT` | 10 | Electric Current and Circuit → Ohm's Law → Joule's Law of Heating | **3** |
| `CHN_MAT10_AP_TERM_TO_SUM` | 10 | nth Term of an AP → Sum of First n Terms of an AP | 2 |
| `CHN_PHY11_KINEMATICS_TO_KE` | 11 | Kinematic Equations → Kinetic Energy | 2 |

The Class-8 chain is deliberately **cross-discipline** — a geometry result feeding a physical property —
which the certified index supports because both concepts are certified at class 8.

## 4. Sample output (Class 9, depth 2)

> A block of mass 4 kg rests on a frictionless surface. A constant force of 38 N moves it 19 m along the
> direction of the force. What is its final speed, in metres per second?
> **(a) 361  (b) 13.44  (c) 19  (d) 9.5**

Solution renders **every intermediate** (`W = 722 J`, then `v = 19 m/s`), so a student can see which link
broke and a teacher can award method marks per step. Distractors are chain-break errors, each re-computed
by sympy: *forgot the square root* `v = 2Fs/m`; *omitted the factor of 2* `v = sqrt(Fs/m)`; *divided by the
mass twice* `v = sqrt(2Fs/m²)`.

**This exact item was then rejected on quality**, see §6.

## 5. Defects found and fixed in this milestone

1. **Multi-root ambiguity.** The work-energy step written as `W = m*v**2/2` and solved for `v` returns
   ±19; `independent_solve` correctly reports `ambiguous`, and the whole chain silently produced zero
   items. A question may not have two keys. Rewritten in the direction it is applied,
   `v = sqrt(2*W/m)` — physically the non-negative root.

2. **`curriculum_boundary` false positives — the W7 defect, seen close up.** The Class-11 item was
   quarantined for *"above-class terms present: ['constant acceleration', 'kinetic energy']"* — its own
   subject matter. Two causes, both fixed at the caller:
   * a chain has several concepts but the spec can name only one, so the gate's existing
     "drop the concept's own topic words" guard protected only the first. Now every chain concept is
     protected.
   * `gates._boundary_checks` reduces boundary prose to **sliding bigrams**. Fed the record
     *"non-uniform (variable) acceleration - these equations are derived for uniformly accelerated motion
     only, and the average-velocity form … is flagged … as holding for constant acceleration only"*, it
     emits **eleven** labels including `flagged evidence`, `holding constant`, `confines itself` — and
     `constant acceleration`, which is the phrase the *same record* lists in scope. The certified index
     writes exclusions as `<claim> - <rationale>`; Lane C now passes the **claim** only. The gate receives
     *more* precise evidence (`non-uniform (variable) acceleration`), which would still fire on a stem that
     genuinely used variable acceleration.

   This is a **workaround at the caller, not a repair**. The underlying bigram defect lives in
   `factory/gates.py`, which the factory lane also depends on, so fixing it there remains a separate
   change (W7, still open).

3. **The key equalled a given (quality, not correctness).** The work-energy item above had key
   `19 m/s` against a given displacement of `19 m`. Arithmetically impeccable, and a poor item: the answer
   is sitting in the stem, rewarding a guesser and leaving a correct solver unsure whether they have
   confirmed their work or hit a coincidence. `key_collides_with_a_given` now rejects such samples in both
   tiers. Measured after the fix: **0 collisions across all 50 passing items.**

## 6. Evidence

```
Depth tier:   15/15 passed · FATAL [] · QUARANTINE []
Single tier:  36/42 passed · FATAL [] · QUARANTINE [dimensional × 6]   (W10 currency, unchanged)
Combined:     50 passing · difficulty {easy 36, moderate 14} · depth {1:36, 2:11, 3:3}
              key-equals-a-given collisions: 0
Lane C tests: 45 passed
Full suite:   ran=1363 failures=0 errors=0 skipped=1
```

## 7. Still open

| Item | Status |
|---|---|
| **Assertion–Reason (W3)** | **next** — still retired under R3-8; needs a computed key |
| Chemistry bindings | not started |
| Biology | needs the qualitative route (`kvs_assertion`, 3,759 rows), not a relation chain |
| Class 12 | not started |
| `hard` difficulty band | not reached — needs depth 4–5 chains, or misconception pressure (hardcoded 0 until QDI v2) |
| W10 currency dimension | unchanged — Simple/Compound Interest still quarantine |
| W7 bigram boundary extraction | worked around at the caller; the gate defect itself is untouched |
| Case-study / conceptual HOTS | deferred by owner decision (needs a model) |

**Note on `hard`.** With `misconception_pressure` fixed at 0 and `calculation_load` a lane constant,
`difficulty.predict` needs depth 4+ at 2 concepts, or depth 3 at 3+ concepts, to cross the 0.60 threshold.
The depth-3 chain scores 0.475. Reaching `hard` honestly means deeper chains, not a re-weighted model.

---

**Bottom line.** The engine is no longer a single-formula drill generator. It composes certified concepts
into multi-step problems, earns its depth by execution rather than assertion, cross-checks every key by two
independently-derived routes, and explains each wrong option as a specific break in the chain. The
remaining quality ceiling is depth 3 and the `moderate` band — real, and addressable by authoring deeper
chains rather than by changing any gate.
