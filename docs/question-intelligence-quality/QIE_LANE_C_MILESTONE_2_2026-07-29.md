# QIE Lane C — Milestone 2: the generator is now attached to the certified knowledge base

**Date:** 2026-07-29 · **Branch:** `feature/program-d-knowledge-bank-integration`
**Owner decisions in force:** Route 1 (deterministic Lane C, $0) · case-study + conceptual HOTS deferred and
reported honestly rather than approximated.
**Predecessor:** `QIE_ARCHITECTURE_VERIFICATION_2026-07-29.md` (defects W1–W9).

---

## 1. Verdict

**Lane C works, and it is genuinely bound to the certified knowledge base.** 36 of 42 generated items pass
the *unmodified* 22-gate battery — the same battery the factory lane faces, including the two FATAL solution
gates that the pre-existing deterministic lane could never have satisfied. **Zero items fail a FATAL gate.**

**It is not yet at the quality bar you set.** Every item today is single-concept, depth-1, difficulty *easy*,
and only Mathematics and Physics are covered. Assertion–Reason, Chemistry, Biology, Class 12 and any form of
HOTS are not yet generated. That is stated up front because the headline number (36/42) would otherwise
imply more than it should.

## 2. Evidence

| Check | Result | Command |
|---|---|---|
| Full KIE regression | **1349 passed, 0 failures, 0 errors**, 1 skipped | `python kie/tests/run_kie_suite.py` |
| New Lane C tests | **31 passed** | `python -m unittest kie.tests.test_certgen_lane_c` |
| Bindings resolving + grounded | **14 / 14**, 0 refused | `binding.resolve()` |
| Items passing the full battery | **36 / 42** | `engine.gate_items()` |
| FATAL gate failures | **0** | ditto |
| Blocking failures remaining | 6, all `dimensional` on currency | ditto |

Baseline before this work: 1318 tests; certified questions bound to a `KC_*` concept: **0**.

## 3. What was fixed

### W4 — the planner was blind to classes 6–10 Physics/Chemistry/Biology · FIXED

`certified_universe()` selects on the curriculum SOURCE subject, which is correct and unchanged — for
classes 6–10 NCERT prints one integrated *Science* book, and pretending otherwise would be inventing
curriculum. The discipline was already carried on the separately-audited `academic_discipline` column,
populated on **100% of all 2,009 certified concepts**, and no planning code read it.

Added `planner.certified_universe_by_discipline()`. Measured effect:

| Discipline | before (`subject`-keyed, 6–10) | after (discipline-keyed, 6–12) |
|---|---|---|
| Physics | **0** | **514** |
| Chemistry | **0** | **404** |
| Biology | **0** | **423** |
| Mathematics | 496 | 638 |

**1,979 of 2,009** certified concepts are now reachable across exactly the 6–12 × four-subject grid you
asked for (the remaining 30 are `Interdisciplinary`).

`check_plan()` gained a **discipline_mismatch** refusal. This is additive and fail-closed: a spec that
declares a discipline must match the certified value, so a Class-8 Physics spec can never be filled from a
Class-8 Biology concept. A spec that declares nothing behaves exactly as before. The gate can only *add* a
refusal, never remove one — pinned by `test_discipline_read_never_widens_the_certified_universe`.

### W1 — the generator was not bound to certified knowledge · FIXED

New package `kie/qie/certgen/`. The rule it enforces:

> A generator template may fire against a certified concept **only if that concept's own certified evidence
> attests the relation the template is about to use.**

This is deliberately stronger than a curated mapping, because a curated mapping is an assertion and the
architecture refuses assertions everywhere else. Each binding declares `grounding` strings that must appear
verbatim in the concept's frozen `sub_concepts` / `boundary.in_scope`. The claim *"Class 8 is taught
Volume = l × b × h"* is not something this code makes — `KC_771977581c488d` already made it, and the code
declines to generate unless it finds it there.

All 14 shipped bindings resolve to real `KC_*` ids and ground. Refusal is the safe direction, and the
refusals are informative:

* **Area of a Triangle (Class 6)** does not bind — its certified evidence teaches "half of an enclosing
  rectangle" and never prints a formula, so a `½bh` drill would be out of boundary at that class.
* **pH Scale (Class 10)** does not bind to `pH = −log₁₀[H⁺]` — the Class-10 record describes a 0–14 scale and
  a universal indicator, and puts the logarithm nowhere. That belongs to the Class-11 record.

**A loophole I introduced and then closed.** My first grounding pass let `PHY11_KINETIC_ENERGY` ground on
the string `"kinetic energy"` — which is merely the concept's *own name*. A title proves nothing about a
relation, so that binding was "self-certifying". `evidence_blob()` now excludes `canonical_name` and
`section_heading` entirely and matches only against audited content claims; the binding was re-grounded on
the real evidence string `(1/2) m v^2`. Pinned by
`test_grounding_cannot_be_satisfied_by_the_concept_name_alone`.

### W2 — no deterministic solution existed · FIXED

`certgen/solution.py` renders the worked solution **from the computation actually performed** — the
certified relation, the substitution, the arithmetic and the unit are all in hand before the question is
printed, so nothing is authored and no model is called. `solution_present` and `solution_matches_key` are
FATAL gates; Lane C now passes both.

**`qp_bridge` mislabel fixed.** [qp_bridge.py:327](curriculum/scripts/intelligence/kie/qie/qp_bridge.py#L327)
read `solution_steps=item["provenance"].get("concepts")` — it wrote the item's *concept list* into the field
a reader takes to be the worked solution, alongside `solution=None`. Now reads the real rendered steps, and
is `None` when there genuinely is no solution. An absent solution is honest; a mislabelled one is not.

### Relation grounding — repaired without weakening the gate

29 of the first 32 items were quarantined as `relation_grounded` failures. The cause was not invented
physics: `qie.db governed_relation` holds 49 rows mined from **senior-physics** evidence and has nothing to
say about `Area = length × width`. The repair gives the gate a **second certified source** rather than
lowering its bar — `binding_relation_registry()` admits a relation only after `binding.resolve()` has proved
a certified concept attests it, so an ungrounded relation can never reach the registry. The frozen stores
are untouched; the registry is assembled in memory and passed through `ctx`, the same channel `validate_run`
already uses.

## 4. Defects the gates caught in my own work

Worth recording, because they are the argument for running Lane C through the real battery rather than a
private check:

1. **A distractor printed as `0.12` while its named misconception computes `0.125`.** `verify_distractors`
   re-solved the mistake and refused the item — correctly, because the option a student reads was not what
   the misconception produces. Rounding an option is not a display choice; it silently changes the claim.
   Fixed by `solution.fmt_exact()`, which adds precision until the printed text round-trips, and returns
   `None` (dropping the option) when it cannot.
2. **`cm^3` written in stem prose was read as a stray given quantity** by `stem_binding_stem` — the
   exponent looks like a number. Units are now spelled out in prose ("cubic centimetres"), which reads
   better anyway.
3. **Pythagoras written as `c**2 = a**2 + b**2` failed `dimensional`** — the gate compares the target's unit
   against the RHS and saw a length against an area. Rewritten as `c = sqrt(a**2 + b**2)`. Sampling was also
   switched to **Pythagorean triples only**: arbitrary integer legs give an irrational hypotenuse, which is
   out of boundary at Class 8 and would have been silently rounded into a wrong key.
4. **`fmt_exact` would print a tiny nonzero value as `"0"`**, because the tolerance is relative. Caught by a
   test I wrote to assert the opposite. A nonzero quantity printed as zero is a different claim, not a
   rounding.

## 5. The quality problem I found, and fixed

Passing every gate is not the same as being a good question. The first clean run produced, for
*"a cyclist travels at 6 m/s for 5 s"*:

```
(a) 0.83   (b) 1.2   (c) 11   (d) 30        key = (d) 30
```

Every option was a gate-proven student error and the item passed the whole battery. It is still a poor
question: a pupil who knows only that a distance should exceed the given numbers picks 30 without computing
anything. **Options eliminable on magnitude alone do not test the concept.**

Misconceptions are now tiered — `conceptual` (wrong relation: diagnostically valuable, often an order of
magnitude away) and `procedural` (right relation, slipped: off-by-one, dropped factor — these sit close and
force the arithmetic). Selection keeps one conceptual trap and fills the rest with the nearest-value errors.

| | before | after |
|---|---|---|
| Median option spread (max/min) | up to **36×** | **4.2×** |
| Key sits at an extreme of the option range | almost always | **< 75%** (test-enforced) |

Same item after the fix — `21.82, 24, 26, 34` with the key at 26, third of four.

## 6. Coverage delivered — and not delivered

Passing items by class and discipline:

| | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|
| Mathematics | 6 | — | 6 | — | 3 | — | — |
| Physics | — | 3 | 6 | 3 | 6 | 3 | — |
| Chemistry | — | — | — | — | — | — | — |
| Biology | — | — | — | — | — | — | — |

**Against your original request, NOT yet delivered:**

| Requested | Status |
|---|---|
| Chemistry (all classes) | **not delivered** — no bindings authored yet |
| Biology (all classes) | **not delivered** — biology is qualitative; needs the AR / KVS route, not a relation |
| Class 12 | **not delivered** |
| Assertion–Reason | **not delivered** — W3 open; still retired under R3-8 |
| Multi-concept questions | **not delivered** — every item is single-concept, depth 1 |
| HOTS | **not delivered** — every item is difficulty *easy* |
| Application-based | partial — real-world scenarios, but single-step |
| Numerical problems | **delivered** |
| Single-concept questions | **delivered** |
| Case-study | **deferred by owner decision** (needs a model) |

## 7. Open defects

### W10 (new) — the dimensional gate cannot model currency · 6 items blocked
Simple Interest (Class 7) and Compound Interest (Class 8) are core syllabus and generate correctly, but
`normalize_unit` cannot parse `Rs`, so `check_relation` returns *"unparseable LHS unit"* and the items
quarantine. Commercial mathematics is therefore unreachable for the whole lane.
**Proposed fix (NOT applied):** add a currency dimension to the unit normalizer in `factory/gates.py`. This
would be *additive* — it makes a currently-unverifiable check verifiable — but it edits a validator the
factory lane also depends on, so it should be an explicit, separately-reviewed change rather than something
folded into this build.

### W7 (from M1) — `curriculum_boundary` still advisory-fails on 9 items
Lane C now feeds the gate real, per-concept `boundary.out_of_scope` evidence, which is a genuine improvement
over the measured 0-hits-in-684 baseline. But 9 items bind concepts whose certified record carries an empty
`out_of_scope`, so the gate still reports "checked 0 curriculum-evidenced forbidden terms". The gate is
right to refuse to call that a pass.

### Advisory noise — `archetype_agreement` fires on 100% of items
`run_gates` calls the classifier with `relation_verified=False`, so it returns the catch-all
`factual_single_best_answer` for every numeric item. The signal is uninformative for this lane. Advisory
only; no action taken.

### W5 / W6 (from M1) — unchanged
377 of the 1,739 "certified concepts" rest on the keyword matcher the reconciliation itself distrusts, and
617 facts carry no concept binding at all (including OCR-corrupted candidates such as
`"Chemistry :: Biock Elements"`). Lane C sidesteps both by binding directly to `ki_concept`, so neither
blocks this lane — but both still stand against the 86.6% headline.

## 8. Next

1. **W3 — computed-key Assertion–Reason.** The precondition R3-8 set for lifting the retirement is a key
   that is *computed*, not hard-coded to option (a). Buildable deterministically from certified
   causal facts, and it unlocks a form you explicitly asked for.
2. **Chemistry + Class 12 bindings** — mole concept, concentration, and the senior relations.
3. **Biology** — needs the qualitative route (`kvs_assertion`, 3,759 rows), not a relation binding.
4. **Multi-concept / HOTS tier** — `compositions.py` already computes reasoning depth from an operator DAG
   and reaches depth 5. Binding those pipelines to certified concepts is the route to depth > 1, and it is
   the single biggest quality gap.

---

**Bottom line.** The join that did not exist now exists: certified concept → grounded binding → computed
answer → three independent re-derivations → proven distractors → rendered solution → the real 22-gate
battery. It is correct, it is honest about what it cannot do, and it is $0. It is not yet world-class,
because everything it makes today is an easy single-step question.
