# QIE Lane C — Milestone 4: Assertion–Reason, coverage, and the two validator repairs

**Date:** 2026-07-29 · **Branch:** `feature/program-d-knowledge-bank-integration`
**Owner direction:** implement AR with computed keys · expand Chemistry, Biology and Class 12 · increase
genuine reasoning depth rather than artificially increasing difficulty · fix W7 and W10 **without weakening
the validation standards**.
**Predecessors:** architecture verification (W1–W9) · Lane C M2 · Lane C M3 (depth tier).

---

## 1. Verdict

All four objectives delivered. **90 of 90 generated items pass the full battery with zero FATAL and zero
QUARANTINE failures**, across all four subjects and classes 6–12.

| | M3 | M4 |
|---|---|---|
| Items passing / generated | 50 / 56 | **90 / 90** |
| FATAL / QUARANTINE | 0 / 6 | **0 / 0** |
| Archetypes | 2 | **3** (+ `assertion_reason`) |
| Subjects | Maths, Physics | **Maths, Physics, Chemistry, Biology** |
| Depth distribution | 1:36 · 2:11 · 3:3 | **1:60 · 2:11 · 3:19** |
| Difficulty | easy 36 · moderate 14 | **easy 60 · moderate 30** |
| Regression | 1363 | **1381 passed, 0 failures, 0 errors** |
| Grounded bindings | 14 | **20 + 5 chains + 4 AR** |

Coverage now reached: Mathematics 6, 7, 8, 10 · Physics 7, 8, 9, 10, 11, 12 · Chemistry 11, 12 ·
Biology 12.

---

## 2. W3 — Assertion–Reason with a computed key

`retired_families.py` banned this form under R3-8 because the frozen
`kie/qpgen/templates.py::_ar_family.build` returns `_AR_OPTS[0]` for **every** AR item — option (a),
regardless of the statements. The retirement stated its own lifting condition: *"the family stays
quarantined until the frozen engine is re-versioned with a computed key … it is not a claim that
assertion-reason is an inherently invalid form."*

`certgen/assertion_reason.py` supplies that key **without touching the frozen engine**, which stays banned
and unreachable. The four options differ only in three facts, and all three are derived:

| Fact | How it is established |
|---|---|
| `truth(A)` | A is a claim about how the certified relation BEHAVES ("at constant resistance, reducing the current to one third reduces the p.d. to one third"). The relation is solved at a working point and again with the quantity scaled; the actual ratio is compared with the claimed one. A false claim fails the same arithmetic. |
| `truth(R)` | R is either the concept's own certified relation (grounded in the index) or a deliberate corruption. A corruption is proved false by sympy: it must **not** be algebraically equivalent to the certified relation. |
| `explains(R, A)` | TRUE when A was derived *from* R. FALSE when R is a true relation from a **different** certified concept that cannot even mention both the scaled quantity and the target — checked, not assumed. |

**Measured result: keys distribute a/b/c/d = 4/4/4/4.** The defect that retired the family was that the key
was always (a); it is now never fixed at all.

Two AR-specific gates replace the numeric distractor proof, at the same FATAL severity:
`ar_options_verified` (every wrong option must be contradicted by a computed value — an unrefuted option
would be a second correct answer) and `ar_key_computed`.

**The retirement itself was amended, narrowly.** `is_retired_item` previously banned the archetype *label*,
so `qp_bridge` would have dropped Lane C's items too. It now exempts only items carrying positive evidence
of a computed key (`has_computed_key`: a full `truth_table` **and** a `key_derivation` note). A retired
**family id** is never exempt, even if it forges that evidence — pinned by
`test_computed_key_items_are_reachable_but_the_frozen_family_is_not`.

### Sample (Class 10, key (b) — the discriminating case)

> **Assertion (A):** At constant resistance, reducing the current through a conductor to one third of its
> value reduces the potential difference across it to one third.
> **Reason (R):** The power dissipated in a resistor carrying a steady current is the product of the square
> of the current and the resistance (P = I²R).

Both statements are true; R concerns Electric Power and does not mention both I and V, so it cannot account
for A. Key **(b)**. The solution tests each fact separately and names the trap: *two true statements need
not stand in an explanatory relation.*

---

## 3. W7 and W10 — repaired at the gate, and proven strengthening

Both were fixed **in `factory/gates.py`** so every lane benefits, not worked around at the caller. Each
repair is pinned by tests that assert the true positive still fires.

### W7 — bigram extraction over sentence-length boundary prose

The certified index writes exclusions as `<claim> - <rationale>`. Deriving adjacent-content bigrams from
the whole record produced eleven labels from one exclusion, including `flagged evidence`, `evidence
holding`, `holding constant` and `constant acceleration` — the last being a phrase the *same record* lists
in scope. A Class-11 kinematics item was quarantined for containing its own subject matter.

`_claim_clause` now derives tokens from the exclusion claim only, and `_boundary_checks` accepts **every**
concept title of a multi-concept item rather than one.

```
genuine exclusion still fires ....... 'integration by parts' → fires on an out-of-scope stem   ✅
rationale noise eliminated .......... 'flagged evidence', 'holding constant' no longer derived ✅
in-scope stem no longer flagged ..... 'a constant acceleration of 4 m/s^2' → not flagged       ✅
out-of-scope stem still caught ...... 'a body under variable acceleration' → flagged           ✅
```

### W10 — currency had no dimension, so money relations could not be checked at all

`normalize_unit("Rs")` returned `"Rs"`, `parse_unit` could not read it, and `check_relation` reported
*"unparseable LHS unit"* → QUARANTINE. Commercial mathematics — simple interest (Class 7) and compound
interest (Class 8), both core syllabus — was uncertifiable by **any** lane.

Currency now maps to `"1"`, exactly as the already-ratified `%`, `ratio` and `count` mappings do, because
money carries no SI base dimension.

```
A = P(1+R/100)^n  (money = money × dimensionless) .... now CHECKED and passes   ✅
I = P × s         (money vs length)   .................. now FAILS, "dimensions differ" ✅
                                        (previously: unparseable → never compared)
cm/kg/N/ohm/J unaffected ............................... still map to their bases ✅
```

**Stated plainly:** this cannot distinguish rupees from a bare ratio, because neither has an SI dimension —
the same limitation the existing dimensionless mappings carry. It is a strictly larger set of checks than
refusing to check at all. 6 previously-blocked items now pass.

---

## 4. Coverage — Chemistry, Biology, Class 12

Six new bindings, each grounded in its concept's own certified evidence:

| Binding | Class | Certified concept | Grounded on |
|---|---|---|---|
| `CHM11_COMBUSTION_CARBON` | 11 | Estimation of Carbon and Hydrogen (Combustion Method) | `%C = 12 x mass(CO2) x 100 / (44 x mass sample)` |
| `CHM11_CARIUS_SULPHUR` | 11 | Estimation of Sulphur (Carius Method) | `%sulphur = 32 x mass(BaSO4) x 100 / (233 x mass sample)` |
| `CHM12_FREEZING_POINT` | 12 | Depression of Freezing Point | `delta Tf = Kf x molality` |
| `BIO12_POPULATION_GROWTH` | 12 | Population Growth | `N(t+1) = N(t) + [(B+I) - (D+E)]` |
| `BIO12_NET_PRODUCTIVITY` | 12 | Productivity | `GPP - R = NPP` |
| `PHY12_FORCE_ON_CHARGE` | 12 | Electric Field | `Force on a test charge: F = qE` |

**On Biology.** Biology is largely qualitative, and the architecture's own standing rule
(`factory/certify.py:14-16`) is that qualitative claims have no independent re-derivation and therefore
cannot be auto-certified. Rather than fabricate coverage, Lane C takes the Biology that **is** computable —
population dynamics and ecosystem productivity, both of which the certified index prints as equations.
Qualitative Biology (structure–function, taxonomy, process sequence) remains on the owned-source /
maker-checker route and is **not** delivered here.

---

## 5. Quality defects found and fixed this milestone

1. **AR near-duplicates.** Keys (a), (b) and (c) all need a true assertion, and reusing one sentence made
   three items that differed only in the Reason line — `near_duplicate` quarantined 3 of 16. Each binding
   now carries **three distinct true claims**, probing different quantities of the same relation.
2. **The false assertion was a one-word variant of the true one** ("doubling the current doubles / halves
   the p.d."), which still read as a near-duplicate. False claims now probe a **different quantity**
   entirely.
3. **The dimensionless marker printed literally.** `"1"` is a unit for the dimensional gate's benefit, not
   a reader's, and solutions were ending *"the population at the end of the year is 1005 1"*. Machine
   output in a document meant for a class. Suppressed; 0 stray occurrences across all 90 items.

## 6. On depth, honestly

AR items are recorded at **depth 3**, and this deserves the scrutiny the owner's instruction implies. It is
not the band being talked upwards. It is the *same* longest-dependency-chain rule
(`compose.reasoning_depth`: `depth[out] = 1 + max(depth[inputs])`) applied to the judgements the form
actually requires:

```
truth(A)      = 1                    from the stem
truth(R)      = 1                    from the stem, independent of truth(A)
explains(R,A) = 1 + max(1,1) = 2     only askable once BOTH truths are settled
option        = 1 + max(1,1,2) = 3
```

`calculation_load` stays at 0.2 for AR precisely because the work is reasoning, not arithmetic — the driver
that rises is depth, which is the honest one.

**`hard` is still not reached.** With `misconception_pressure` hardcoded at 0 until QDI v2, crossing 0.60
needs depth 4+. The deepest item today is depth 3. Reaching `hard` means authoring 4-step chains, not
re-weighting `diff-v1`.

## 7. Still open

| Item | Status |
|---|---|
| `hard` difficulty band | not reached — needs depth-4+ chains |
| Mathematics classes 9, 11, 12 | no bindings yet (11/12 calculus exists in `compositions.py`, not yet certified-bound) |
| Chemistry classes 6–10 | no bindings yet |
| Biology classes 6–11 | computable Biology is thin; qualitative Biology cannot be auto-certified |
| Qualitative HOTS, case-study | deferred by owner decision (needs a model) |
| Graph / table / diagram interpretation | declared archetypes with no generator in any lane |
| W5 / W6 (from M1) | unchanged — 377 concepts rest on the keyword matcher; 617 facts carry no concept binding |

---

**Bottom line.** The engine now generates three archetypes across four subjects and classes 6–12, with
every key computed, every wrong option proven, every concept certified and grounded, and every item through
the same battery the factory lane faces — 90 for 90, clean. Assertion–Reason is no longer a hard-coded (a).
The two validator defects are repaired in the validator itself, with tests proving each repair catches more
than it did before, not less.
