# QIE — Final Mission Report

**Date:** 2026-07-29 · **Mode:** autonomous execution
**Contains:** Final Engineering Report · Final Capability Report · Final Production Readiness Report ·
Remaining Owner Actions

> **STOP CONDITION NOT MET.** Three of five criteria pass. Two cannot be truthfully certified. The reasons
> are measured, not estimated, and are stated in Part 3. I am reporting rather than continuing because the
> remaining work is authoring at a scale that no amount of further autonomous execution in one session can
> deliver, and certifying production readiness against the measured numbers below would be false.

| Stop criterion | State |
|---|---|
| Roadmap complete | ❌ Phase 1 complete · Phase 2 begun · Phases 3–4 largely open |
| Regression passes | ✅ **1,426 passed, 0 failures, 0 errors** |
| Independent re-audit passes | ✅ **8 adversarial checks, 0 failures** |
| Capability targets achieved | ❌ JEE Main 2.11% · NEET 0.94% · JEE Adv ~0.2% |
| Production readiness certified | ❌ **cannot be certified** |

---

# PART 1 — FINAL ENGINEERING REPORT

## 1.1 Delivered this mission

| Work | Before | After |
|---|---|---|
| **Operator registry** | 9 (polynomial only) | **77** |
| Senior-Maths operator coverage | 0 / 141 concepts | **141 / 141 (100%)** |
| Bindings | 36 | **43** |
| Certifiable items | 115 | **133** |
| Senior-Maths items | **0** | **18** |
| Distinct certified concepts used | 25 | **31** |
| Regression | 1,408 | **1,426** |

### Phase 1 — Operator framework (complete)

35 new operators in two passes, registering into the existing `compose.OPERATORS` so `run_pipeline`,
`reasoning_depth` and every consumer work unchanged.

* **General calculus** (differentiate/integrate/definite/evaluate/limit on any expression), **matrices &
  determinants**, **vectors & 3-D**, **complex numbers**, **sequences & combinatorics**, **probability &
  statistics**, **equation solving**
* Completion pass: **sets**, **relations & functions**, **inverse trigonometry**, **inequalities**,
  **differential equations**, **linear programming**

Every operator declares an **independent** verify — symbolic checked numerically, solving checked by
substitution, closed forms checked by direct summation, defining properties checked instead of
recomputation. Classified by exam: BOARD_6_10 **36** · BOARD_11_12 **77** · JEE Main **62** · JEE Advanced
**61** · NEET **38**, with matrices/complex/cross-product correctly excluded from NEET and Biology
operators excluded from JEE.

### Phase 2 — Bindings (begun)

7 senior-Mathematics bindings authored against the new operators: 3-D distance, perpendicular distance from
a line, nPr, latus rectum of an ellipse, statistical range, A.M.–G.M., second-order determinant. **Senior
Mathematics moved from zero to 18 generated items over 6 certified concepts.**

### Repository integration

`prereq_bridge` wired `graph_edges.db` (1,169 trusted edges, 897 concepts) into the planner — the first
repository integration, delivered with a pre-registered proof-of-impact experiment.

### Validator repairs

**W7** (bigram extraction over boundary prose) and **W10** (currency had no dimension) repaired *in
`factory/gates.py`*, each pinned by tests proving the repair catches **more** than before, not less.

## 1.2 Defects this mission found in its own work

| Defect | How found | Severity |
|---|---|---|
| `cross_product` accepted a **sign-flipped** result | adversarial operator probe | **High** — the commonest student error on that operator would have been certified correct. Fixed with a scalar-triple-product orientation check |
| Prerequisite backing refused 2 legitimate chains | proof-of-impact experiment | **High** — refused on a *gap in the graph*, the W7 failure mode repeated. Rule changed from `either known` to `both known` |
| `MAT12_DET2` symbols `a11`/`a12` read as stray quantities | gate battery | Medium — same class as the earlier `cm^3` defect. Symbols renamed to carry no digits |
| Bracketed matrix notation failed `stem_quality` | gate battery | Medium — rows described in words instead |
| Operator registry undocumented across 8 modules | classification test | Medium — 28 operators unclassified; `chain_step{k}` is runtime-synthesised, now modelled as a declared dynamic family |

## 1.3 Final validation battery

| # | Check | Result |
|---|---|---|
| 1 | Full regression suite | ✅ **1,426 passed, 0 failures, 0 errors**, 1 skipped |
| 2 | End-to-end benchmark | ✅ **133/133 items pass the 22-gate battery — 0 FATAL, 0 QUARANTINE** |
| 3 | Capability benchmark | ✅ measured (Part 2) |
| 4 | Repository integrity | ✅ all 31 concept ids certified today; all bindings resolve and ground |
| 5 | Deterministic verification | ✅ **3 independent runs, byte-identical** (`sha256 29b8be41…`) |
| 6 | Fresh independent audit | ✅ **8 adversarial checks, 0 failures** |

Fresh audit detail — every check re-derived, no prior conclusion reused:

```
A1 concept certification       31 ids,  0 not certified
A2 option structure             0 malformed
A3 solution == key              0 mismatched
A4 duplicate normalised stems   0
A5 wrong options refuted        0 unrefuted
A6 no above-class concept       0 violations
A7 independent re-solve         0 unreproducible
A8 provenance complete          0 incomplete
```

---

# PART 2 — FINAL CAPABILITY REPORT

## 2.1 Measured movement (same harness, session start → now)

| Metric | Start | Now | Δ |
|---|---|---|---|
| Bindings resolved | 36 | 43 | +19% |
| Items passed | 115 | 133 | +16% |
| Distinct concepts used | 25 | 31 | +24% |
| Concept utilisation | 1.2633% | **1.5664%** | +24% |
| Senior items | 32 | **50** | +56% |
| **JEE Main content %** | 0.6931% | **2.1115%** | **+205%** |
| NEET content % | 0.94% | 0.94% | **0.00** |
| Legal composition pairs | 11,132 | 8,524 | −23.4% |
| Max reasoning depth | 3 | 3 | — |

**JEE Main tripled**, entirely because senior Mathematics went from 0 to 6 bound concepts. NEET did not
move because no senior Physics/Chemistry/Biology bindings were added this mission.

*Probe note:* the frozen harness reports `operators: 9` because it imports `compose` only, not
`operators_ext`. The registry is 77. The probe is deliberately not edited — a measurement instrument
changed mid-experiment invalidates the comparison.

## 2.2 Capability against the three examinations

| Exam | Format readiness | Content readiness | Overall | Architecture ceiling |
|---|---|---|---|---|
| **NEET** | 100% | ~0.94% | **~0.9%** | ~23% |
| **JEE Main** | 80% | ~2.1% | **~1.7%** | ~38% |
| **JEE Advanced** | ~25% | ~1% | **~0.2%** | ~15% |

## 2.3 Question-type support

**Supported (5):** single-concept · multi-concept · numerical (MCQ form) · Assertion–Reason · Match the
Following · Conceptual MCQ *(partial — relation-reachable concepts only)*

**Missing (8):** integer/numerical-entry · multi-correct · matrix match · statement-based · paragraph ·
case study · graph/figure · diagram-based. Five of these are **unmodelled** in `QuestionType`.

## 2.4 Coverage

| Subject | Certified 11–12 | Relation-reachable | Bound concepts |
|---|---|---|---|
| Physics | 306 | 193 (63.1%) | 3 |
| Mathematics | 141 | 84 (59.6%) | **6** (was 0) |
| Chemistry | 273 | 51 (18.7%) | 3 |
| Biology | 238 | **14 (5.9%)** | 2 |

---

# PART 3 — FINAL PRODUCTION READINESS REPORT

## Verdict: **NOT PRODUCTION READY.** Not certifiable for CBSE, AP, TS, ICSE, JEE Main, JEE Advanced or NEET.

### What *is* production quality

The **certification machinery**. Every question the engine emits is correct, in-syllabus, fully explained,
deterministically reproducible, grounded in frozen certified evidence, and carries a computed key with every
wrong option proven. 133 of 133 pass a 22-gate battery with zero FATAL and zero QUARANTINE. Three
independent runs are byte-identical. A fresh 8-check adversarial audit found nothing.

**That is a genuinely strong foundation and should not be rebuilt.**

### What blocks production

| # | Blocker | Evidence |
|---|---|---|
| **1** | **Volume.** 43 bindings over 1,979 certified concepts = **1.57% utilisation**. A single NEET paper needs 180 questions; total addressable output is ~133. | measured |
| **2** | **Format.** 8 of 15 question types missing; 5 unmodelled. JEE Main *requires* integer-entry (5 of 25 per subject); JEE Advanced requires multi-correct, paragraph and matrix match — none exist. | measured |
| **3** | **Difficulty.** **No item has ever reached the `hard` band.** Max reasoning depth is 3. JEE Advanced is largely a hard-band exam. | measured |
| **4** | **Reasoning.** No indirect, hidden-concept or twisted questions. The engine makes questions *longer*, not *harder*. | measured |
| **5** | **Biology.** 5.9% of senior Biology is relation-reachable, against 50% of the NEET paper. **Not an engineering problem** — factual knowledge has no independent re-derivation (`certify.py:14-16`). | measured |
| **6** | **No write-back.** Generated items are never persisted. No cross-session dedup, no cumulative bank. | verified: zero `INSERT`/`commit()` in `certgen/` |
| **7** | **No psychometrics.** Difficulty labels are structural; never validated against student response data. | measured |

### Why I stopped rather than continued

The mission instruction was to continue until production ready. The measured evidence says that endpoint is
not reachable by continued execution of this kind:

* Closing blocker 1 to even the **architecture ceiling** requires roughly **100× the current binding
  count** — that is authoring, and authoring does not accelerate the way code does.
* Blocker 5 is **structural**. No engineering effort changes Biology's 5.9% reachability.
* Blockers 2–4 are genuine subsystems (integer/multi-correct key models, a reasoning engine for
  indirection), each a multi-week build in its own right.

Continuing silently would have produced marginal binding additions while the four criteria above stayed
false. Certifying production readiness against these numbers would have been false. Reporting is the
correct action.

---

# PART 4 — REMAINING OWNER ACTIONS

| # | Action | Why it needs you |
|---|---|---|
| **1** | **Decide the Biology strategy** | 50% of NEET at 5.9% deterministic reachability. Either fund a human maker–checker workforce for factual Biology, or accept that NEET capability is capped near 25%. **This is a resourcing decision, not an engineering one.** |
| **2** | **Decide on the dormant factory lane** | `factory_corpus.db` holds a complete, tested model-assisted lane (1,000 candidates, 7,649 gate results) idle under the standing $0 / no-live-call policy. It is the only route to certifying qualitative content at scale. Reversing that policy is yours alone. |
| **3** | **Authorise sustained authoring capacity** | Bindings are the bottleneck and the work is authoring. Decide whether this is one engineer for months, or a team. |
| **4** | **Approve the question-type build order** | I recommend integer-entry → statement-based → multi-correct → paragraph → matrix match. Integer-entry is cheapest and JEE Main requires it. |
| **5** | **Decide on psychometrics** | Difficulty cannot be validated without student response data. That needs a pilot deployment. |
| **6** | **Commit or discard this work** | Nothing has been committed. The branch holds the operator framework, senior-Maths bindings, prereq integration and gate repairs. |

## Recommended next sequence

1. Senior **Physics** bindings (193 reachable, best ratio) → moves NEET, which did not move this mission
2. **Integer-entry** question type → unblocks 20% of JEE Main's format
3. Senior **Chemistry** bindings (51 reachable)
4. Depth-4+ chains using the new operators → first honest `hard`-band items
5. Write-back → makes all subsequent authoring cumulative

---

**Final statement.** The engine is a correct, well-governed, fully deterministic generator with an
exceptional certification spine and a now-complete operator framework. It is not yet an exam engine.
The gap is not quality — it is volume, format breadth, and difficulty range. Every number in this report is
reproducible from the repository as it stands.
