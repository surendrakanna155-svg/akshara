# Governed math-capable notation recovery — capability built (owner decision A)

**Date:** 2026-07-15 · Continues `20e7e228`. The owner chose **Option A**: build the math-capable notation
recovery over our already-owned source PDFs/page-images rather than curate formulas or leave the numeric lane
closed. This is that capability — a **reusable evidence-processing layer**, not a fix for a fixed formula list.
`qpgen` internals frozen; `kie.db` read-only; bank not promoted.

## Why this was required
Every existing text representation of our owned STEM sources has **destroyed the math**. NCERT's Coulomb's law
(Class XII Physics, ch.1 p.8, Eq. 1.2) text-extracts as:

```
0 \n 1 \n 2 \n 2 \n 1 \n 4 \n q q \n F \n r \n ε \n = \n π \n (1.2)
```

Subscripts, superscripts and spatial structure are gone. The previous checkpoint proved that inducing relations
arithmetically from that damage is **~90% false positives** and admitted nothing. So recovery must return to the
rendered page — the owner's rule: *when notation is damaged, return to the actual source PDF/page/image*.

## The layer (`kie.qie.convert.notation`)
| module | role | deterministic? |
|---|---|---|
| `sources` | resolve + render ANY owned source page (plain PDF **or a chapter PDF inside a textbook .zip**), cached; `math_damage_score` flags flattened-math pages | yes |
| `targets` | pick the pages worth re-reading: math-damage score + **chapter SUMMARY / POINTS-TO-PONDER pages** (they restate every relation of the chapter → highest recovery-per-read) | yes |
| *(vision transcription)* | reads the rendered image and **proposes** the exact equation, symbols, meanings, units, sub/superscripts, constants, constraints | **model — proposes only** |
| `dimensions` | unit→SI quantity parsing + **base-dimension reduction** (`A·ohm == V`) | yes (sympy) |
| `verify` | the **locked hierarchy** | yes (sympy) |
| `register` | admission: certify → `governed_relation` with provenance + per-gate evidence | yes |
| `relation_compose` | fresh numeric items from CERTIFIED relations → engine → qpgen | yes |

### The locked hierarchy (mandatory gates)
`PROVENANCE` (read from a real owned page) · `SYMBOLIC` (parses; **no undeclared symbol**) · `DIMENSIONAL`
(LHS/RHS base dimensions identical under declared units) · `DOMAIN` (subject-gated) · `ROUND-TRIP` (solvable
and re-substitutes). **ANSWER-KEY is corroboration only — never sufficient.**

## Proof it certifies truth and rejects damage
Recovery batch 1 (Class XI/XII Physics summary pages + the Coulomb page) with **deliberate adversarial
controls**:

| relation | verdict |
|---|---|
| Work-energy theorem `W_net = K_f − K_i` | **certified** |
| Grav. PE near surface `V = m g x` | **certified** |
| Spring PE `V = ½ k x²` | **certified** |
| Elastic collision (equal masses) `v₁ᵢ² = v₁f² + v₂f²` | **certified** |
| Grav. PE of two particles `V = −G m₁ m₂ / r` | **certified** |
| Kepler's third law `T² = K_S R³` | **certified** |
| Coulomb's law `F = (1/4πε₀) q₁q₂ / r²` | **certified** |
| **[CONTROL]** Coulomb with OCR-lost exponent (`/r`) | **rejected — dimensional** |
| **[CONTROL]** spring PE with lost square (`½kx`) | **rejected — dimensional** |

**The decisive result:** the damaged spring-PE control scored **answer-key corroboration 5/15** — real exam
questions arithmetically "confirmed" a *wrong* relation — and the dimensional gate overruled it. That is
precisely the false-positive trap that made blind induction unsafe, caught. It is pinned by a test
(`test_answer_key_alone_cannot_certify`).

## Two verifier defects found and fixed (a gate that rejects truth is also a defect)
1. **Like-unit cancellation** — substituting units into `W = K_f − K_i` gave `joule − joule = 0`, losing the
   dimension and falsely rejecting a correct relation. Fixed by scaling each symbol's unit by a distinct
   coefficient (a scalar cannot change a dimension).
2. **Sign assumption** — symbols were declared `positive=True`, so the legitimately *negative*
   `V = −G m₁ m₂ / r` was unsolvable and falsely rejected. Fixed to `real=True`.

## Generation + measured impact (real QIE → qpgen, seed 7)
Items are authored from the relation's **recovered meanings** (never printing the formula — that would make the
item a trivial substitution), answers computed by sympy and **independently recomputed** before banking, with
exam-realistic instance magnitudes (µC charges, planetary masses) via `value_ranges` — noting that the
*certified knowledge is the relation*; ranges only choose sensible instance values.

> *Given first point charge q1 = 1.000e-06 C; second point charge q2 = 3.000e-06 C; separation r = 0.2 m.
> The electrostatic force between two point charges (in N) is:* → **0.6741** (distractors ×2, ÷2, sign-flip)

| exam | before notation lane | **after** | Physics | boundary |
|---|---|---|---|---|
| NEET | 26 | **29** | 6 → **9** | ok, 0 rejected |
| JEE Main | 17 | **20** | 6 → **9** | ok, 0 rejected |
| JEE Advanced | 17 | **17** | 6 | ok, 0 rejected |

**The numeric blocker is broken:** JEE Main moved for the first time since the programme began. 585 tests green.
The `EVIDENCE_REGISTRY` lifecycle state **`4_recovered_notation` is now reached** (previously unreachable), with
a new `NOTATION_PAGES` store.

## Remaining (scale, not capability)
7 certified relations is a *seed*, not the ceiling. Each chapter SUMMARY page yields ~5–8 relations and the
layer is re-runnable over every owned source in the registry: NCERT Physics (14 chapters × 2 books), Chemistry,
and Maths remain. JEE Advanced needs Maths/multi-concept relations to move. Nothing here is one-off: adding a
chapter is `targets.select(...)` → render → transcribe → certify.
