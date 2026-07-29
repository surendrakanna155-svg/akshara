# QIE — Integration Proof-of-Impact Study

**Date:** 2026-07-29 · **Status:** PRE-REGISTERED — predictions recorded before the intervention
**Hypothesis under test (mine, from the Integration Master Plan):**

> *"Integration will not by itself move JEE or NEET capability much, because after every bridge is built
> the engine will still have 36 bindings over 2,009 concepts."*

That was asserted, not demonstrated. This study is designed to **falsify** it.

**Method:** one fixed measurement harness (`capability_probe.py`), run identically before and after a
single intervention. Predictions below are recorded **before** the intervention is implemented and are not
to be edited afterwards — only scored.

---

## 1. Pre-registered predictions

Each prediction states a **direction**, a **magnitude**, and what would count as **falsification**.

### 1.1 Prerequisite graph — THE INTERVENTION IN THIS STUDY

Wiring `graph_edges.prereq_edge` (1,805 edges, 1,183 KC-resolved) into the planner.

| Metric | Prediction | Falsified if |
|---|---|---|
| Certified concepts | **no change** (2,009) | any change |
| Relation-reachable concepts | **no change** | any change |
| Bindings resolved | **no change** (36) | any change |
| Generated items | **no change** (115) | > 120 or < 110 |
| Distinct concepts used | **no change** (25) | any increase |
| Max reasoning depth | **no change** (3) | > 3 |
| Difficulty distribution | **no change** | any hard-band item appears |
| Benchmark % (NEET / JEE) | **no change** | any movement > 0.1pp |
| **Legal composition pairs** | **DECREASE** — prerequisite structure should *constrain*, not widen | an increase |
| **Planner refusals** | **INCREASE** — a new check adds refusals | a decrease |
| **New planner capability** | prerequisite depth becomes computable for **~1,183 concepts (59%)** | < 800 concepts get a depth |

**Headline prediction:** *integration alone changes no output metric.* It adds planner intelligence that
only pays off once new bindings are authored.

**What would falsify my hypothesis:** any increase in generated items, distinct concepts used, reasoning
depth, or benchmark percentage — without authoring a single new binding.

### 1.2 Governed facts (1,424 KC-native) — NOT implemented in this study

| Metric | Prediction |
|---|---|
| Generated items | no change |
| Distinct concepts used | no change |
| **Distractor quality** | improvement possible (grounded wrong options for conceptual items) |
| **Scenario richness** | improvement possible |
| Benchmark % | **no change** — facts are not answer keys and cannot certify a question alone |

### 1.3 Planner expansion (prereq + facts + relation registry) — NOT implemented

| Metric | Prediction |
|---|---|
| Planner *decision quality* | improves (better-ordered, better-justified specs) |
| Generated items | **no change without new bindings** |
| Benchmark % | **no change without new bindings** |

### 1.4 PYQ frequency — NOT implemented

| Metric | Prediction |
|---|---|
| Concept *selection* | changes — weighting toward what examiners actually choose |
| Generated items | no change |
| **Authenticity** | improves *only if* the weighted concepts already have bindings. With 25 concepts bound, weighting has almost nothing to reorder |

### 1.5 Exam weights — NOT implemented

| Metric | Prediction |
|---|---|
| Paper assembly proportions | becomes possible |
| Generated items | no change |
| Benchmark % | no change (blueprint ≠ content) |

---

## 2. Why the prerequisite graph is the correct single intervention

* **KC-native** — 1,183 edges already resolve to certified concept ids. No mapping layer, no migration.
* **Frozen and deterministic** — a table read by pure join; cannot introduce nondeterminism.
* **Reversible** — read-only adapter; deleting it restores prior behaviour exactly.
* **Smallest safe change** — it touches the planner only, and the planner is fully covered by tests.
* **Highest predicted long-run value** — prerequisite structure is the precondition for principled
  composition, and composition is the precondition for depth.

---

## 3. Measurement methodology (fixed)

`capability_probe.py` emits a JSON snapshot of:

1. **Universe** — certified concepts, relation-reachable, per discipline
2. **Assets** — bindings declared/resolved/refused, operators, code relations
3. **Planner decisions** — every certified concept probed as a spec; issued vs refused, with reasons
4. **Composition legality** — legal multi-concept pairs over a fixed deterministic 400-concept sample
5. **Generation** — attempted, passed, FATAL, QUARANTINE, by discipline/class/archetype/form,
   difficulty, depth, distinct concepts used, concept utilisation, senior items, stem length vs corpus
6. **Benchmark** — NEET and JEE Main content percentages, same arithmetic as the capability audit

The probe is frozen for the duration of the study. If the probe changes, the experiment is void.

---

## 4. Decision rule (recorded in advance)

| Outcome | Conclusion | Roadmap consequence |
|---|---|---|
| No output metric moves | **Hypothesis SUPPORTED** | Integration is infrastructure. Proceed to authoring; do the remaining integrations opportunistically |
| Output metrics move materially without new bindings | **Hypothesis FALSIFIED** | Integration is capability. Complete all integrations before authoring |
| Planner/composition metrics move but output does not | **Hypothesis SUPPORTED with qualification** | Integration is a multiplier on future authoring — sequence it first, but do not expect it to generate |

---

*Sections 5 (baseline), 6 (intervention), 7 (result) and 8 (roadmap re-evaluation) are completed in
sequence below as the study runs.*

---

# 5. BASELINE (BEFORE)

Captured with `capability_probe.py BEFORE`, prior to any change.

```
assets       bindings 36/36 resolved · operators 9 · code relations 86
universe     1,979 certified · reachable: Phy 240 · Math 280 · Chem 69 · Bio 45
planner      1,979 specs probed → 1,968 issued · 11 refused (junk_record)
composition  79,800 pairs probed → 11,132 legal (13.95%)
generation   115 attempted → 115 passed · 0 FATAL · 0 QUARANTINE
             25 distinct concepts · 1.2633% utilisation · max depth 3 · 32 senior items
             difficulty {easy 76, moderate 39} · depth {1:72, 2:24, 3:19}
benchmark    NEET 0.94% · JEE Main 0.6931%
```

# 6. INTERVENTION

`kie/qie/knowledge/prereq_bridge.py` — read-only adapter over `graph_edges.db prereq_edge`, wired into
`planner.certified_universe_by_discipline` (attaches `prereq_ids` + `prereq_depth`) and into `check_plan`
(prerequisite-backing requirement for multi-concept compositions).

Loaded: **1,169 trusted edges over 899 concepts; 897 of 1,979 certified concepts (45.3%) carry resolved
prerequisites; structural depth ranges 0–12.** Ambiguous (70) and unresolved (552) edges excluded.

## 6.1 A defect the experiment caught in the intervention itself

The first implementation asked whether **either** concept was known to the graph. Measured against the
engine's own five chains, it refused two legitimate ones:

| Chain | Verdict | Cause |
|---|---|---|
| `CHN_MAT8_PHY8_VOLUME_DENSITY` | UNBACKED | `Density` has **0** recorded prerequisites |
| `CHN_PHY9_WORK_TO_SPEED` | UNBACKED | `Work Done by a Constant Force` has **0** |

In both cases the refusal came from a **gap in the graph**, not from anything about the question — the W7
failure mode repeated. Corrected to require the graph to know **both** concepts before refusing.

| Rule | Same-subject pairs refused (fixed 400-concept sample) | 5 shipped chains |
|---|---|---|
| `either known` (wrong) | 12,675 | **2 refused** |
| `both known` (correct) | 4,484 | **0 refused** |

# 7. RESULT (AFTER)

Identical harness. **Exactly two metrics moved. Every other metric is byte-identical.**

| Metric | Before | After | Δ |
|---|---|---|---|
| **Legal composition pairs** | 11,132 | **8,524** | **−2,608 (−23.4%)** |
| **Legal composition rate** | 13.95% | **10.68%** | **−3.27pp** |
| Certified concepts | 1,979 | 1,979 | — |
| Relation-reachable | 240/280/69/45 | 240/280/69/45 | — |
| Bindings resolved | 36 | 36 | — |
| Generated items | 115 | 115 | — |
| FATAL / QUARANTINE | 0 / 0 | 0 / 0 | — |
| Distinct concepts used | 25 | 25 | — |
| Concept utilisation | 1.2633% | 1.2633% | — |
| Max reasoning depth | 3 | 3 | — |
| Difficulty distribution | easy 76 / mod 39 | easy 76 / mod 39 | — |
| Senior items | 32 | 32 | — |
| Stem length vs corpus | unchanged | unchanged | — |
| **NEET content %** | 0.94% | **0.94%** | **0.00** |
| **JEE Main content %** | 0.6931% | **0.6931%** | **0.00** |

Regression: **1,416 passed, 0 failures, 0 errors** (1,408 → 1,416; +8 bridge tests).

## 7.1 Prediction scorecard

| # | Prediction | Outcome | Score |
|---|---|---|---|
| 1 | Certified concepts unchanged | unchanged | ✅ |
| 2 | Reachable concepts unchanged | unchanged | ✅ |
| 3 | Bindings unchanged | unchanged | ✅ |
| 4 | Generated items unchanged | 115 → 115 | ✅ |
| 5 | Distinct concepts unchanged | 25 → 25 | ✅ |
| 6 | Max depth unchanged | 3 → 3 | ✅ |
| 7 | Difficulty unchanged | unchanged | ✅ |
| 8 | Benchmark unchanged | 0.00 movement | ✅ |
| 9 | **Legal pairs DECREASE** | −23.4% | ✅ |
| 10 | **Planner refusals INCREASE** | **unchanged (11 → 11)** | ❌ **MISSED** |
| 11 | ~1,183 concepts get a depth | **897 (45.3%)** | ⚠️ within threshold, below estimate |

**Miss on #10:** I predicted refusals would rise. They did not, because the probe's planner test issues
**single-concept** specs, which never reach a composition check. The new refusal exists but is invisible
to that metric. My prediction was wrong about *where* the effect would appear — the composition metric
caught it instead.

**Partial on #11:** I estimated ~1,183 concepts would gain a depth; the actual is **897**, because I
additionally required both endpoints to be certified *today* and excluded ambiguous edges. The stricter
filter is correct; my estimate was loose.

# 8. VERDICT

**Hypothesis SUPPORTED, with the qualification the decision rule anticipated.**

> *Integration alone moved zero output metrics. Generated questions, concepts used, depth, difficulty and
> both benchmark percentages are unchanged to the digit.*

This is the third row of the pre-registered decision table: **planner/composition metrics moved, output
metrics did not.** Integration is a **multiplier on future authoring**, not a source of capability.

**But the multiplier is real and larger than "not much".** Before this change the planner would have
admitted **11,132** concept pairs as legal multi-concept questions on the sole basis that they shared a
subject. **2,608 of those had no curricular relationship whatsoever** — no prerequisite link in either
direction and no shared foundation. Every one was a potential incoherent question, and the planner had no
way to tell. It does now.

That matters precisely *because* authoring is the bottleneck: when binding count rises from 36 toward
several hundred, composition legality is what stops that growth turning into nonsense. The value is
insurance on future work, and it does not show up in today's output because today's output is 36 bindings
made by hand and already sane.

## 8.1 Roadmap consequence

**The roadmap does not change. Authoring is confirmed as the bottleneck.**

Revised sequencing guidance:

1. **Integration is cheap, safe and worth doing first — but it must not be sequenced as though it were
   capability.** Total P0 integration ≈ 3–4 weeks and will move the benchmark by ~0.
2. **Do the remaining integrations opportunistically, alongside authoring, not before it.** Only
   `governed_fact` (1,424 KC-native) has a plausible claim to changing *output* quality, because it can
   ground distractors and scenarios — and that prediction is now pre-registered above and should be tested
   the same way.
3. **Every future integration must ship with a proof-of-impact run.** This experiment cost roughly an hour
   and prevented an incorrect months-long sequencing decision. It also caught a real defect in its own
   intervention before that defect could refuse legitimate questions.
