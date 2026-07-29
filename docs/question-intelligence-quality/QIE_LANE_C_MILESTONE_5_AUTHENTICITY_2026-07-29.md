# QIE Lane C — Milestone 5: authenticity against the certified PYQ corpus

**Date:** 2026-07-29 · **Branch:** `feature/program-d-knowledge-bank-integration`
**Owner direction:** reproduce the DNA of real examination questions; do not optimise for depth score or
any internal metric. **Owner decisions:** run both tracks (archetypes now, extraction in parallel); treat
answer keys as permanently unavailable.
**Companion:** `QIE_PYQ_CORPUS_DNA_STUDY_2026-07-29.md`.

---

## 1. Verdict

The generator is now steered by measured corpus evidence rather than by an internal score. **99 of 99
generated items pass the full battery clean** (0 FATAL, 0 QUARANTINE), and the corpus has been made to
yield two DNA dimensions it previously could not.

| | M4 | M5 |
|---|---|---|
| Items passing / generated | 90 / 90 | **99 / 99** |
| Archetypes | 3 | **4** (+ match-the-columns) |
| Corpus concept linkage | 132 items (0.8%) | **569 items** via mined stems (**4.3×**) |
| Corpus stems recovered | 0 | **5,786 / 15,803 (36.6%)** |
| Regression | 1381 | **1397 passed, 0 failures, 0 errors** |

---

## 2. The premise, corrected

The brief assumed the certified PYQ corpus and Question DNA could serve as a quality benchmark. Measured:
**three of the fifteen named DNA dimensions are minable; twelve were not.** `concept_kc` was linked on
0.8% of items, difficulty is `structural_proxy` for 100% (the signal is literally `span_len` + type),
`exam_dna_v2` reports `insufficient_evidence` for both behavioural dimensions, `question_dna.solution_dna`
is empty, and 77% of `distractor_dna` is classified only as `other`.

Rather than assemble a benchmark and label it measured, this milestone used what is real and went after
what was missing.

---

## 3. Track A — the archetype gap the corpus exposed

### The finding

| Archetype | Lane C at M4 | NEET real | JEE-Adv real |
|---|---|---|---|
| numerical | **82%** | ~0% | 18.0% |
| assertion_reason | **18%** | 1.6% | — |
| conceptual MCQ | **0%** | **87.5%** | 74.3% |
| **match-the-columns** | **0%** | **11.0%** | 7.6% |

`match` is 1,661 real NEET items and we generated none of it. It is also the hardest *common* form on the
corpus's own proxy: **55% hard, 45% moderate, 0% easy**, against plain MCQ's 93% easy.

### What was built

`certgen/match_columns.py` — three grounded bindings (Class-10 electricity, Class-8 mechanics, Class-8
mensuration), **9/9 items clean**. Lane C's match share is now **9.1%** against NEET's 11.0%.

The key is a **permutation computed** from the certified pairings, never chosen. Each of the four pairs is
grounded in its **own** certified concept, and every wrong option names the specific pair it contradicts.

Two design rules taken from how the form actually behaves in real papers, not from a metric:

* **the identity permutation is refused** — `A-I, B-II, C-III, D-IV` is guessable without reading either
  column;
* **every distractor differs from the key by exactly one transposition**, so a candidate confident about a
  single pairing still cannot discard three options. Partial knowledge is not enough — which is the
  authentic difficulty of the form.

### A gate extended, not weakened

`composition_backed` accepted only *numeric* structural backing (≥2 distinct relations, or DAG depth ≥2),
so it quarantined all 9 match items for lacking arithmetic they never have. It now also accepts a
**checked** non-numeric backing: the declared `composition_components` must be ≥2 **distinct concept ids
that actually appear in the item's own `concept_ids`**. Not a bypass — the lane using it also faces the
FATAL `match_key_verified` gate. Pinned by
`test_nonnumeric_composition_backing_cannot_be_asserted_without_the_concepts`.

The resolver also **refused a binding I had mis-declared** — a Class-6 mensuration item containing a
Class-7 concept. The boundary rule caught my error, not a hypothetical one.

---

## 4. Track B — making the corpus yield DNA

`qie/pyq/stem_dna.py` recovers per-question stems from chunk spans and links them to certified concepts.

```
items scanned              15,803
stems recovered             5,786   (36.6%)
stems with a certified concept 569   (was 132 — a 4.3x improvement)
```

### Concept-selection DNA — what real examiners actually chose

`Electric Field` 85 · `Electric Dipole` 41 · `Surface Tension` 40 · `Refractive Index` 24 ·
`Atomic Mass` 24 · `Simple Harmonic Motion` 23 · `Kinetic Energy` 20 · `Carnot Engine` 19 ·
`Hydrogen Bonding` 18 · `Krebs' Cycle` 18

### Concept-combination DNA — what they paired inside one question

`Electric Dipole + Electric Field` 18 · `Covalent Bonding + Hydrogen Bonding` 17 ·
`Blood Groups + Incomplete Dominance` 4 · `Blood Groups + Polygenic Inheritance` 4

These are canonical JEE/NEET pairings, recovered rather than assumed. **One is a false positive**:
`Circumference of a Circle + Angular Acceleration` (18) is almost certainly the word "circumference"
appearing in rotational-motion stems. Recorded rather than quietly dropped — it marks the precision limit
of name-based linking.

### The structural DNA that turned out to matter most

| form | median stem length (real corpus) |
|---|---|
| mcq | 115 chars |
| match | 261 |
| numerical | 318 |
| assertion_reason | 386 |

This both explains the corpus's difficulty proxy (which is length-based) and gives a concrete authenticity
target. Measured against Lane C:

| form | Lane C | corpus | verdict |
|---|---|---|---|
| numerical | 150 | 318 | **TOO SHORT — 0.47×** |
| match | 377 | 261 | too long — 1.44× |
| assertion_reason | 310 | 386 | match — 0.80× |

**Our numerical questions are less than half the length of real ones.** Real NEET/JEE numericals carry
substantially more setup, condition and constraint than our terse templates — which is precisely the
"information hiding / hidden constraints" DNA the brief asked about, surfacing as a measurable signal. No
internal metric would ever have shown this.

### What the miner deliberately does not do

* **No answer keys.** None exist, and per the owner decision they are permanently unavailable. Nothing
  infers, reconstructs or guesses one — pinned by `test_the_miner_never_produces_an_answer_key`.
* **No distractor DNA.** Verified by inspection: real option text OCRs as `1+b / a+f / (2)2b-1 / co)`.
  Building a misconception taxonomy on that would be building it on noise.
* **Strict concept linking.** A concept links only on its full canonical name with ≥2 significant words.
  "Ray" and "Series" are refused outright — matching them would fire on any stem containing those words.
  Low recall is recoverable; high-confidence wrong links would corrupt every figure built on them.

---

## 5. Still open

| Item | Status |
|---|---|
| **Conceptual MCQ** | **the largest remaining gap — 87.5% of NEET, still 0% in Lane C** |
| Numerical stem length | 0.47× the real median — needs richer scenario construction |
| Stem recovery | 36.6%; the other 63% could not be segmented from their chunk span |
| Concept linkage | 569 of 5,786 recovered stems (9.8%) — aliases and sub-concepts would raise it |
| Distractor / reasoning / case-study DNA | unminable — OCR damage and empty `solution_dna` |
| `hard` band | still not reached; needs depth-4 chains |
| Maths 9/11/12, Chemistry 6–10 | no bindings yet |

**On conceptual MCQ.** It is the dominant real form and the right next target. Much of NEET's 87.5% is
Biology factual recall, which the architecture's own rule (`certify.py:14-16`) says cannot be
auto-certified. The deterministically reachable portion is relation-identification ("which expression
correctly gives X?") with provably-false alternatives — the same falsification technique the AR lane
already uses. That would close part of the gap honestly, and I would report which part it does **not**
close.

---

**Bottom line.** The generator is now corrected by evidence from real papers rather than by a score: it
writes the form the corpus uses heavily and we had ignored, its match items behave the way real ones do,
and the corpus itself now yields concept-selection and concept-combination DNA it could not before. The
most valuable output of this milestone is an uncomfortable measurement — our numerical questions are half
the length of real ones — which is exactly the kind of finding the brief was asking for.
