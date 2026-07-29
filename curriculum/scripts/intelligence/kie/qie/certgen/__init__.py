"""Lane C — certified-knowledge-bound deterministic question generation.

WHY THIS PACKAGE EXISTS (architecture verification 2026-07-29, defects W1/W2/W3).

The repo already held two generation lanes and they did not meet:

  * the FACTORY lane (`kie.qie.factory`) satisfies the full certification contract — class level, complete
    solution, per-distractor proven misconception, difficulty, provenance, 22 gates — but every run needs
    two live model stages including a cross-family judge, so under the standing $0 policy it has produced
    zero rows;
  * the DETERMINISTIC lane (`generate_numeric`, `compositions`, ...) runs free and its answers are provably
    correct, but it generates from a HARDCODED template library. Its "concepts" are strings like
    `REL_OHMS_LAW`; none of them is a `KC_*` id from the 2,009-concept certified index. It emits no
    solution, so `gates.solution_present` (FATAL) would reject 100% of it, and it therefore never entered
    the `candidate` table at all.

Lane C is the missing join, not a third architecture. It reuses every existing layer unchanged:
`knowledge.planner` for the certified universe, `relations`/`compose` for the maths, `knowledge.difficulty`
for the band, `factory.gates` for validation. What it adds is exactly the three things that were absent:

  1. `binding`   — a generator template may only fire against a CERTIFIED concept, and only when that
                   concept's OWN certified evidence attests the relation being used (W1).
  2. `solution`  — a deterministic worked solution and a NAMED, machine-checkable misconception for every
                   wrong option, rendered from the computation actually performed (W2).
  3. `assertion_reason` — an Assertion-Reason builder whose key is COMPUTED, which is the precondition
                   R3-8 set for lifting the retirement of that form (W3).

Nothing here proposes knowledge. Every answer is computed; every concept is certified; every binding is
grounded in the frozen index. No model is called at any point in this package.
"""
