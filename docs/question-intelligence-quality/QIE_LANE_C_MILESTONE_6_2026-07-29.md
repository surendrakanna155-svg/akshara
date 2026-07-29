# QIE Lane C — Milestone 6: Conceptual MCQ lane, and closing the information-density gap

**Date:** 2026-07-29 · **Branch:** `feature/program-d-knowledge-bank-integration`
**Scope:** two priorities only, no new forms. **Constraints:** deterministic certification · no LLM
generation · no fabricated knowledge · regression green.
**Companions:** `QIE_PYQ_CORPUS_DNA_STUDY_2026-07-29.md` · Milestone 5.

---

## 1. Verdict

Both priorities delivered and measured against the corpus. **115 of 115 generated items pass the full
battery clean** (0 FATAL, 0 QUARANTINE). Regression **1408 passed, 0 failures, 0 errors**.

| | M5 | M6 |
|---|---|---|
| Items passing / generated | 99 / 99 | **115 / 115** |
| Archetypes | 4 | **5** (+ conceptual MCQ) |
| Numerical stem length vs corpus | **0.47×** | **0.94×** |
| Conceptual MCQ share | 0% | **13.9%** |
| Regression | 1397 | **1408** |

---

## 2. Priority 1 — the deterministic Conceptual MCQ lane

`certgen/conceptual_mcq.py`, **16/16 clean**, two variants:

* **relation identification** — *"Which expression gives the power dissipated in a resistor carrying a
  steady current I through a resistance R?"* No numbers are supplied, so the item cannot be answered by
  calculating; it tests whether the relation is held.
* **proportionality** — *"If I is multiplied by 2 while R is unchanged, the quantity …"* Tests how the
  quantity *responds*, which a remembered formula alone does not answer.

### Falsification — two checks, not one

Every wrong option must fail **both**:

1. `relations_equivalent(certified, candidate, target)` is False — it is not a rearrangement of the
   certified relation wearing different symbols;
2. at a declared working point it computes a **different value** from the certified relation.

Check 1 catches a restatement; check 2 catches a gap in the equivalence checker itself. Pinned by
`test_a_rearrangement_of_the_certified_relation_is_refused`. The key is the only option surviving both —
computed, never chosen. A new FATAL gate `conceptual_key_verified` enforces it.

### The separation you asked for, measured

`classify_reachability()` draws the line over the whole certified index:

| | concepts | share |
|---|---|---|
| **relation-reachable** — evidence states a relation, Lane C **can** certify | **634** | **32.0%** |
| **factual-recall only** — no relation in evidence, **cannot** be certified | **1,345** | **68.0%** |

| discipline | reachable | factual-only | reachable % |
|---|---|---|---|
| Physics | 240 | 274 | **46.7%** |
| Mathematics | 280 | 358 | **43.9%** |
| Chemistry | 69 | 335 | 17.1% |
| Biology | 45 | 378 | **10.6%** |

A concept whose evidence states no relation is **refused** by the resolver with
`not_relation_reachable`, so this lane cannot drift into factual recall. `certify.py:14-16` is the reason:
factual recall has no independent re-derivation, and gates plus a same-family judge certify nothing.

### Corpus coverage after implementation

```
PYQ stems recovered                    5,786
stems linked to a certified concept      569
of those, concerning a relation-reachable concept   38%
```

**So the honest ceiling on this lane is roughly a third of the curriculum and 38% of linkable real
questions.** It does not close NEET's 87.5% — most of that is Biology factual recall (10.6% reachable),
which stays on the owned-source / maker-checker route. What it does close is the relation-reachable
portion, and that portion is now covered.

---

## 3. Priority 2 — closing the 0.47× information-density gap

### What was mined (5,786 recovered stems)

| Setup structure — how real stems open | | Conditions stated | | Sentences per stem | |
|---|---|---|---|---|---|
| "The …" | 18.7% | if … then | 8.0% | 1 | **0.1%** |
| "Which …" | 13.2% | when | 4.3% | 2 | **56.0%** |
| "A …" | 8.8% | uniform / constant | 4.1% | 3 | 21.3% |
| "In …" | 5.4% | respectively | 3.1% | 4 | 11.0% |
| "If …" | 2.7% | assume / taking | 2.2% | 5+ | 11.6% |

**99.9% of real stems run to two sentences or more.** Ours were single scenarios — which is exactly why
they measured 150 characters against the corpus median of 318.

### What was built

`solution.enrich_stem()` composes the **setup → condition → ask** order real setters use, and every
binding gained two authored fields: an `elaboration` (context) and a `condition` (the assumption the
certified relation depends on — *"The temperature of the conductor remains constant throughout the
reading."*, *"Combustion is complete, and all the carbon in the sample ends up in the carbon dioxide
collected."*).

**Nothing is copied.** The corpus supplied the *structure* — how many sentences, whether a condition is
stated, where the ask sits. Every sentence is authored against the binding's own certified concept.

### Result

| form | Lane C | corpus median | |
|---|---|---|---|
| **numerical** | **298** | 318 | **0.94× — MATCH** (was 0.47×) |
| mcq | 105 | 115 | 0.91× — match |
| assertion_reason | 310 | 386 | 0.80× — match |
| match | 377 | 261 | 1.44× — long (two printed columns; inherent to the form) |

---

## 4. Residuals, stated plainly

**Sentence count is now over-structured.** Ours: `{2: 13, 3: 2, 4: 51, 5: 8}` — 69% at four sentences,
against a corpus where four-sentence stems are 11% and the mode is two at 56%. Length matches; shape does
not. The cause is structural: a real two-sentence stem reaches 318 characters through a *richer single
setup sentence*, whereas we reach it by adding sentences. Matching both would mean rewriting each
binding's scenario sentence to carry more, not adding a fifth clause. Recorded rather than tuned, because
adjusting the sentence count alone would re-open the length gap.

**Mix is still far from NEET.**

| | Lane C | NEET | JEE-Adv |
|---|---|---|---|
| mcq | 13.9% | 87.5% | 74.3% |
| numerical | 64.3% | ~0% | 18.0% |
| match | 7.8% | 11.0% | 7.6% |
| assertion_reason | 13.9% | 1.6% | — |

`match` is close to authentic. The mcq shortfall is bounded by the 32%/68% reachability split, not by
effort — the remaining share would require certifying factual recall, which the architecture forbids.
Lane C's profile is currently closer to **JEE Advanced** (numerical-heavy) than to NEET, which is worth
saying out loud.

---

## 5. Constraints honoured

* **Deterministic certification** — every key computed; new FATAL gate `conceptual_key_verified`.
* **No LLM generation** — no model call anywhere in `certgen/`.
* **No fabricated knowledge** — every binding grounded in its concept's own certified evidence; the
  resolver refuses `not_relation_reachable`, `ungrounded_relation`, `falsification_fails`.
* **Regression green** — 1408 passed, 0 failures, 0 errors.

## 6. Next, in priority order

1. **Richer single setup sentences** for the numerical bindings — closes the sentence-shape residual
   without re-opening the length gap.
2. **More relation-reachable conceptual bindings** — 634 concepts are reachable and 4 are bound.
3. `hard` band via depth-4 chains; Maths 9/11/12 and Chemistry 6–10 coverage (unchanged from M4).
