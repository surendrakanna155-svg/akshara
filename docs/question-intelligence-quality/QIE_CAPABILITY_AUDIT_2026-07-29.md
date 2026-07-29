# QIE — Comprehensive Capability Audit against JEE Main, JEE Advanced and NEET

**Date:** 2026-07-29 · **Branch:** `feature/program-d-knowledge-bank-integration`
**Purpose:** determine what is still required to build a production-grade JEE Main / JEE Advanced / NEET
question generation engine. **This is a master planning document, not a progress report.**
**Method:** every figure is a direct query or a direct read of the repository as it stands today. Nothing
planned, in progress, or "possible" is counted as capability.

---

## 0. Executive verdict

**The engine is a correct, well-governed generator of easy-to-moderate school-level questions. It is not a
JEE or NEET engine, and the distance is much larger than the milestone reports imply.**

Three numbers frame everything:

| | |
|---|---|
| Certifiable items the engine can produce today | **115** |
| Of those, inside the JEE/NEET syllabus (classes 11–12) | **32** |
| Distinct certified concepts any item touches | **25 of 1,979 (1.3%)** |

Senior **Mathematics — the whole of JEE Maths — contributes zero items.** There is no binding for
Mathematics at class 11 or 12.

What has been built well: the certification spine. Grounding, computed keys, falsification, the 22-gate
battery, provenance, deterministic solutions. That machinery is sound and should not be rebuilt. What is
almost entirely absent: **content volume, question-format breadth, and every subsystem that makes an
exam paper look like an exam paper.**

---

## 1. Current capability

### 1.1 What the engine can generate today

| Lane | Bindings | Items | Status |
|---|---|---|---|
| Numeric single-step | 20 | 60 | **production-shaped** |
| Numeric multi-step chain | 5 | 14 | **production-shaped** |
| Assertion–Reason | 4 | 16 | **production-shaped** |
| Match-the-columns (1↔1) | 3 | 9 | **production-shaped** |
| Conceptual MCQ | 4 | 16 | **production-shaped** |
| **Total** | **36** | **115** | |

"Production-shaped" means: computed key, grounded in certified evidence, complete solution, every wrong
option proven, passes the full 22-gate battery, 0 FATAL / 0 QUARANTINE, deterministic and reproducible.

### 1.2 The honest qualification

**Production-shaped is not production-ready.** Every lane is a *mechanism* demonstrated on a handful of
bindings. 36 bindings across a 1,979-concept certified universe is a proof of concept, not an engine.
At three items per binding, total addressable output today is roughly **115 questions** — against a single
NEET paper needing 180.

### 1.3 Distribution of what exists

```
by discipline   Physics 65 · Mathematics 35 · Chemistry 9 · Biology 6
by class        6:14  7:6  8:32  9:5  10:26  11:20  12:12
by difficulty   easy 76 · moderate 39 · hard 0
by depth        1:72  2:24  3:19  4+:0
senior (11-12)  32 total — Physics 17, Chemistry 9, Biology 6, Mathematics 0
```

**No item reaches the `hard` band. No item exceeds reasoning depth 3.** JEE Advanced is largely a hard-band
exam.

---

## 2. Coverage by subject

Certified concepts and how many are *deterministically reachable* (their certified evidence states a
relation; concepts without one are factual recall, which `factory/certify.py:14-16` establishes cannot be
auto-certified).

| Subject | Certified 6–12 | Reachable | Certified 11–12 | Reachable 11–12 | **Bindings** | **Concepts actually used** |
|---|---|---|---|---|---|---|
| Physics | 514 | 240 (46.7%) | 306 | **193 (63.1%)** | 17 | ~10 |
| Mathematics | 638 | 280 (43.9%) | 141 | **84 (59.6%)** | 11 | ~8 |
| Chemistry | 404 | 69 (17.1%) | 273 | **51 (18.7%)** | 5 | ~4 |
| Biology | 423 | 45 (10.6%) | 238 | **14 (5.9%)** | 3 | ~3 |

### Physics — the strongest subject
Best reachability (63.1% at senior level) and best binding coverage (classes 7–12, missing only 6).
**Weak areas:** no figure/circuit-diagram reasoning; no graph interpretation; nothing in optics, modern
physics, thermodynamics, waves or rotational mechanics is bound. 10 concepts used of 306.

### Mathematics — the largest hole
638 certified concepts and 280 reachable, yet **classes 9, 11 and 12 have no bindings at all**. JEE
Mathematics is entirely classes 11–12, so the engine's JEE Maths capability is **zero**. Calculus operator
machinery exists in `compositions.py` (9 operators) but was never bound to certified concepts.
Senior Maths also has only **141 certified concepts** — thin for a subject spanning calculus, algebra,
coordinate geometry, vectors, 3-D and probability.

### Chemistry — structurally weak
Only 18.7% of senior concepts are relation-reachable, because most of Chemistry is not relational:
inorganic descriptive chemistry, organic mechanisms, named reactions, periodic trends. The reachable
portion is physical chemistry (mole concept, colligative properties, estimation methods).
**No support whatsoever for chemical structures, equations, mechanisms, or reaction arrows.**

### Biology — effectively out of reach
**5.9% of senior Biology concepts are relation-reachable.** Biology is NEET's largest component (90 of 180
questions, 50% of the paper) and is almost entirely factual, taxonomic, structural and process-based
knowledge. The two working bindings (population growth, net primary productivity) are the rare numeric
exceptions. **This is the single most consequential coverage gap in the entire system.**

---

## 3. Question-type support

| # | Type | Status | Why |
|---|---|---|---|
| 1 | Single concept | **Supported** | 20 numeric + 4 conceptual bindings, all with computed keys |
| 2 | Multi concept | **Supported** | 5 chains at depth 2–3, two independently-derived routes must agree |
| 3 | Numerical (MCQ-form) | **Supported** | The most mature lane |
| 4 | **Integer / numerical-entry** | **Missing** | `QuestionType` has `NUMERICAL` but every generator emits 4 options. No integer-entry answer model, no tolerance/range spec. **JEE Main requires 5 of 25 per subject; JEE Advanced uses it heavily.** |
| 5 | **Matrix Match (1↔many, 4×4)** | **Missing** | Only 1↔1 matching exists. Matrix match allows multiple correct pairings per row and needs a different key model and marking scheme. |
| 6 | Assertion–Reason | **Supported** | Computed key from (truth A, truth R, explains) — R3-8 lifted with evidence |
| 7 | Match the Following (1↔1) | **Supported** | 3 bindings, key is a computed permutation |
| 8 | Conceptual MCQ | **Partial** | Works for relation-reachable concepts only — **32% of the curriculum**. Factual-recall MCQ (the bulk of NEET) is architecturally excluded. |
| 9 | **Statement-based (Statement I / II)** | **Missing** | JEE Main's current staple. Mechanically close to Assertion–Reason and probably the cheapest missing form to add. |
| 10 | **Graph / Figure based** | **Missing** | `figure_catalog.db` holds 113 captions and 87 assets, but `figure_element` and `figure_link` are **empty by design** ("FUTURE"). No figure can be reasoned about, generated, or referenced. |
| 11 | **Passage based** | **Missing** | No passage construction, no multi-question binding to shared stimulus. |
| 12 | **Multi-correct** | **Missing** | No representation anywhere in the repo. Requires a set-valued key, partial-credit marking, and distractor logic where several options are true. **Core JEE Advanced format.** |
| 13 | **Paragraph questions** | **Missing** | Same as 11 — needs 2–3 questions sharing one stimulus with dependency management. |
| 14 | **JEE Advanced style** | **Missing** | Depends on 4, 5, 11, 12, 13, plus hard-band difficulty and non-routine problem design. None exist. |
| 15 | NEET style | **Partial** | Format is right (single-correct MCQ). Content is not: 50% of the paper is Biology, of which 5.9% is reachable. |

**Scorecard: 5 supported · 2 partial · 8 missing.**

`kie/qpgen/models.py::QuestionType` models six types total (`mcq`, `numerical`, `short_answer`,
`long_answer`, `assertion_reason`, `match`). Multi-correct, integer-entry, matrix-match, paragraph and
statement-based are not in the platform's vocabulary at all — they are not merely unimplemented, they are
**unmodelled**.

---

## 4. Reasoning capability

| Capability | Status | Evidence |
|---|---|---|
| Direct questions | **Yes** | 72 of 115 items are depth 1 |
| Multi-step reasoning | **Yes, to depth 3** | `replay_steps` earns depth by execution; padding cannot inflate it |
| Distractors | **Yes, and strong** | Every wrong option is re-computed by sympy; a rounded option is refused |
| Misconception-based options | **Yes** | Named misconception per option, tiered conceptual/procedural, gate-proven |
| Hidden concepts | **No** | Every stem names its quantities explicitly. Nothing requires the candidate to *infer* which concept applies. |
| Indirect reasoning | **No** | No reverse questions ("given the answer, find the input"), no elimination-based items, no contradiction/proof-by-cases. |
| Twisted questions | **No** | No trap conditions, no redundant-data items, no special-case boundaries, no "none of these". Every item is a direct forward application. |

**This is the deepest capability gap after coverage.** JEE Advanced difficulty comes almost entirely from
indirection, hidden structure and non-routine framing — precisely the three the engine cannot do. Depth 3
of forward computation is not the same as difficulty, and the engine currently has no mechanism to make a
question *hard* rather than *long*.

---

## 5. Knowledge graph audit

| Asset | Count | Assessment |
|---|---|---|
| Certified concepts (6–12) | 1,979 | **Solid.** Audited, class-bound, boundary-carrying. |
| Relation-reachable concepts | 634 (32.0%) | **The hard ceiling on deterministic generation.** |
| Certified facts (`governed_fact`) | 2,041 | Largely unusable for generation: 617 have no concept binding, and the qualitative lane cannot certify |
| Relation library | **86** | `Physics 39 · Mathematics 34 · Chemistry 13` — **far too small.** JEE Physics alone needs several hundred. |
| Compose operators | **9** | `differentiate, integrate_def, evaluate, real_roots, min_root, max_root, unique_root, subtract_poly, absval` — polynomial calculus only. |
| Bindings | **36** | The true bottleneck. |
| Concepts actually reachable *and* bound | **25** | **1.3% of the certified universe.** |
| Composition chains | 5 | Depth 2–3 |
| Figure elements / links | **0 / 0** | Declared, empty, "FUTURE" |

### Bottlenecks, in order of severity

1. **Bindings (36).** Everything else is gated behind this. The certified knowledge exists; it is not
   wired. This is authoring work, and it does not parallelise into the existing machinery for free.
2. **Relation library (86).** Cannot express most of senior Physics/Chemistry.
3. **Operator registry (9, polynomial-only).** No trigonometry, no logarithms/exponentials, no vectors,
   no matrices, no probability, no limits, no differential equations. Senior Mathematics is unreachable
   with this set regardless of bindings.
4. **Reachability (32%).** Structural, not fixable by effort — factual knowledge has no re-derivation.
5. **`governed_fact` 617 unbound + OCR corruption** (e.g. `"Chemistry :: Biock Elements"`).

---

## 6. Architecture gaps — missing subsystems

| Subsystem | State | Consequence |
|---|---|---|
| **Scenario synthesis** | Missing | Stems come from hand-authored templates. Volume is bounded by authoring, not compute. **This is the scaling wall.** |
| **Figure / diagram generation** | Missing | No SVG synthesis, no ray diagrams, no circuits, no free-body diagrams, no graphs. `figure_element`/`figure_link` empty. |
| **Graph generation & interpretation** | Missing | No plot synthesis, no read-off-the-graph items. |
| **Chemistry structure engine** | Missing | No SMILES/molfile, no structure rendering, no reaction equations, no mechanism arrows. Organic chemistry is entirely unreachable. |
| **Biology diagram engine** | Missing | No labelled diagrams. Compounds the 5.9% reachability problem. |
| **Figure reasoning** | Missing | Cannot pose or verify a question about a figure. |
| **Passage / paragraph engine** | Missing | No shared-stimulus construction. |
| **Difficulty calibration** | **Present but weak** | `diff-v1` has 4 drivers; `misconception_pressure` is hardcoded 0; `calculation_load` is a lane constant. Effectively depth + concept count. **No item has ever reached `hard`.** |
| **Psychometrics** | **Absent entirely** | No IRT, no difficulty/discrimination parameters, no response data, no calibration loop. Difficulty labels are structural guesses, never validated against student performance. |
| **Paper assembly** | Partial | `qp_bridge` exists; no exam-authentic blueprint (section structure, marking scheme, negative marking, time budget). |
| **Answer explanation** | **Present and good** | Deterministic, rendered from the executed computation. |
| **Solution generation** | **Present and good** | Every intermediate printed; method marks awardable. |
| **Validation** | **Present and strong** | 22 gates + lane-specific FATAL proofs. The best-built part of the system. |
| **Reasoning engine (indirect/twisted)** | Missing | See §4. |
| **Multi-correct / integer key models** | Missing | Blocks JEE Advanced formats. |

---

## 7. Benchmark against the real exams

**Method.** Capability is scored on two independent axes, because they fail independently:
*format readiness* = fraction of the paper's question slots whose format the engine can emit;
*content readiness* = fraction of the paper's concept space with a working binding.
Overall ≈ format × content. The **ceiling** column is what the current architecture could reach if every
reachable concept were bound — i.e. the limit of the deterministic approach, not of effort.

### JEE Main — 75 questions (Physics 25, Chemistry 25, Maths 25; per subject 20 MCQ + 5 numerical-entry)

| Axis | Score | Basis |
|---|---|---|
| Format | **80%** | MCQ supported; the 5 numerical-entry slots per subject are not |
| Content | **~1%** | Physics ~2%, Chemistry ~1%, **Mathematics 0%** |
| **Overall** | **≈ 0.8%** | |
| Ceiling | ≈ 38% | if all reachable concepts were bound and integer-entry added |

### JEE Advanced — multi-correct, integer, paragraph, matching-list, hard band

| Axis | Score | Basis |
|---|---|---|
| Format | **~25%** | Only single-correct MCQ. Multi-correct, integer, paragraph, matrix-match all missing |
| Content | **~1%** | Plus: no item reaches `hard`; no indirect or twisted reasoning |
| **Overall** | **≈ 0.2%** | |
| Ceiling | ≈ 15% | Advanced difficulty is non-routine by design; deterministic templating has a low natural ceiling here |

### NEET — 180 questions (Physics 45, Chemistry 45, Biology 90), all single-correct MCQ

| Axis | Score | Basis |
|---|---|---|
| Format | **100%** | Single-correct MCQ is fully supported |
| Content | **~1.2%** | Physics ~2%, Chemistry ~1%, Biology ~0.8% (and Biology is half the paper) |
| **Overall** | **≈ 1.2%** | |
| Ceiling | ≈ 23% | Bounded by Biology's 5.9% reachability |

**NEET is the nearest target** — its format is already fully supported. **JEE Advanced is the furthest** and
would require the most new architecture. **JEE Main is blocked on senior Mathematics**, which is currently
at absolute zero.

---

## 8. Roadmap

### P0 — mandatory for any credible exam engine

| # | Item | Why it is P0 |
|---|---|---|
| P0-1 | **Senior Mathematics bindings (11–12)** | JEE Maths is 33% of JEE Main and currently **0%**. 84 reachable concepts exist, unbound. |
| P0-2 | **Expand the operator registry** — trigonometry, log/exp, vectors, matrices, probability, limits | Senior Maths is unreachable with 9 polynomial operators regardless of bindings. Blocks P0-1. |
| P0-3 | **Integer / numerical-entry question type** | Required by JEE Main (5/25 per subject) and JEE Advanced. Needs an answer model with tolerance, not options. |
| P0-4 | **Binding volume: 36 → several hundred** | 1.3% concept utilisation is the top-line bottleneck. Everything else is theoretical until this moves. |
| P0-5 | **Expand the relation library (86 → 300+)** | Blocks P0-4 for Physics and Chemistry. |
| P0-6 | **Statement-based (Statement I / II)** | JEE Main staple; mechanically close to the working AR lane — the cheapest missing format. |
| P0-7 | **A real strategy for Biology** | 50% of NEET at 5.9% reachability. Either accept deterministic Biology is out of scope and route it to maker-checker, or fund the human-certified path. **This is a decision, not an engineering task, and it should be taken explicitly.** |

### P1 — high value

| # | Item |
|---|---|
| P1-1 | **Multi-correct question type** (set-valued key, partial credit) — JEE Advanced core |
| P1-2 | **Matrix Match (4×4, 1↔many)** — extends the working match lane |
| P1-3 | **Passage / paragraph engine** — shared stimulus, dependent sub-questions |
| P1-4 | **Indirect & twisted reasoning** — reverse questions, hidden concepts, trap conditions, redundant data. The mechanism that makes items *hard* rather than *long* |
| P1-5 | **Depth-4+ chains** to reach the `hard` band honestly |
| P1-6 | **Scenario synthesis** — break the hand-authored-template scaling wall |
| P1-7 | **Difficulty calibration v2** — populate `misconception_pressure`; validate bands against something real |
| P1-8 | **Exam-authentic paper assembly** — blueprint, marking scheme, negative marking, time budget |
| P1-9 | **Graph generation + interpretation** — synthesise the plot, then ask about it |

### P2 — future

| # | Item |
|---|---|
| P2-1 | **Chemistry structure engine** (SMILES, rendering, reactions, mechanisms) — unlocks organic chemistry |
| P2-2 | **Figure/diagram synthesis** (ray diagrams, circuits, free-body) — populate `figure_element`/`figure_link` |
| P2-3 | **Biology diagram engine** |
| P2-4 | **Psychometrics** — IRT calibration from real student responses; the only way difficulty stops being a guess |
| P2-5 | **Figure reasoning** — pose and verify questions about a diagram |
| P2-6 | **Adaptive/personalised selection** |

---

## 9. Brutally honest summary

**What is genuinely good.** The certification architecture. Grounding against frozen certified evidence,
computed keys, two-route verification, falsification proofs, the 22-gate battery, deterministic solutions
with printed intermediates, honest provenance, 1,408 green tests. Where the engine produces a question,
that question is correct, in-syllabus, fully explained and reproducible. **Very few question banks can
make that claim, and it should not be rebuilt.**

**What is being over-stated by the milestone reports.** "115/115 passing" measures the *gate pass rate of
what was attempted*, not coverage. Attempting 115 questions against a 1,979-concept universe and passing
all of them is a statement about discipline, not about capability. I should have foregrounded the
denominator earlier.

**The four hard truths.**

1. **Content, not machinery, is the bottleneck.** 36 bindings, 25 concepts, 1.3% utilisation. The
   remaining work is overwhelmingly *authoring*, and authoring does not accelerate the way code does.
2. **Senior Mathematics is at zero.** The most valuable JEE subject has no bindings, and the operator
   registry cannot support it if it did.
3. **Biology is structurally out of reach.** 5.9% reachability against 50% of the NEET paper. No amount
   of engineering fixes this — factual knowledge has no independent re-derivation. It needs an owner
   decision.
4. **The engine cannot yet make a question hard.** It makes questions *longer* (depth 3) but not
   *harder*. No hard-band item has ever been produced. JEE Advanced is, in essence, an exam of indirection
   — and indirection is unimplemented.

**Honest capability today: NEET ≈ 1.2%, JEE Main ≈ 0.8%, JEE Advanced ≈ 0.2%.**
**Honest ceiling of the current deterministic architecture: NEET ≈ 23%, JEE Main ≈ 38%, JEE Advanced ≈ 15%.**

Reaching those ceilings is a large, mostly-authoring programme. Exceeding them requires either a
human maker–checker workforce for the factual majority, or the model-assisted factory lane that already
exists and is dormant under the $0 policy — and that is an owner decision, not an engineering one.
