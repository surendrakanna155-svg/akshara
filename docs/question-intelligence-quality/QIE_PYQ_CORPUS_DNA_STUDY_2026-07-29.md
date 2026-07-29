# QIE — Study of the certified PYQ corpus as a DNA benchmark

**Date:** 2026-07-29 · **Purpose:** establish what the certified previous-year corpus and Question DNA can
actually supply as a difficulty/style benchmark, before evolving the generator against it.
**Method:** direct query of `pyq_corpus.db`, `qie.db question_dna`, `examdna.db`. Every number below is
reproducible.

---

## 1. Headline

**The corpus exists and is large. It is provenance-grade, not analysis-grade.** It can tell us *what forms
appear and in what proportion*. It cannot yet tell us *what makes a question hard*, because the fields that
would carry that are either unpopulated or explicitly recorded as proxies.

Of the fifteen DNA dimensions named in the brief, **three are measurable today, twelve are not.**

---

## 2. What is there

| | |
|---|---|
| `pyq_item` | **15,803** items |
| Years | **2011–2025** (15 years) |
| Distinct sittings (exam × year) | **26** |
| Exams | NEET 14,432 · JEE_ADVANCED 987 · JEE_MAIN 384 |
| `pyq_item_difficulty` | 15,803 (one per item) |
| `question_dna` | 2,996 |

The span and volume genuinely exceed "the last 10 years".

## 3. What is missing, and why it blocks DNA mining

| Field | State | Consequence |
|---|---|---|
| `pyq_item.concept_kc` | **132 / 15,803 = 0.8%** linked | **Concept selection and concept combinations cannot be mined.** 99.2% of real questions have no concept attached, so co-occurrence analysis is impossible. |
| `pyq_item.subject` | **955 / 15,803 = 6.0%** known | Subject-level style analysis is not supportable. |
| `pyq_item_difficulty.difficulty_basis` | **`structural_proxy` for 100%** | The stored "difficulty" signal is literally `{"span_len": N, "type": T}` — **longer = harder**. The schema comment says it explicitly: *"never 'measured' / 'pilot'"*. This is a length heuristic, not a difficulty model. |
| `exam_dna_v2` `question_type` | **`insufficient_evidence`** for all three exams | The behavioural DNA is not established. |
| `exam_dna_v2` `structural_difficulty` | **`insufficient_evidence`** for all three exams | Difficulty DNA is not established. |
| `exam_dna_v2` `subject_weight` | populated, but `provenance_class = published` | It is the board's own printed blueprint, not something measured from the corpus. |
| `n_sittings` | JEE_MAIN 6 · NEET 10 · JEE_ADVANCED 14 | All below the ≥30 independent-sittings bar the design set. |
| `question_dna.solution_dna` | **0 rows populated** | No key insights, no ordered reasoning steps, no common-mistake records. **Reasoning patterns cannot be mined.** |
| `question_dna.difficulty_drivers` | **0 rows populated** | No measured driver vectors. |
| `question_dna.distractor_dna` | 2,996 populated, but the vocabulary is `other` 77% · `half` 13% · `x2` 7% · `sign_flip` 4% | **Distractor design and misconception traps cannot be mined**: three-quarters of wrong options are classified only as "other". |
| Question text / options / answer keys | **not stored** | `pyq_item` holds span pointers into OCR chunks. Three different items resolve to the same chunk, and that chunk opens with exam instruction boilerplate. There are no answer keys (consistent with the W0 finding already on record). **Information hiding, elegance, originality, hidden constraints and case-study structure cannot be studied — the questions themselves are not readable as questions.** |

### Against the brief's fifteen dimensions

| Dimension | Minable today? |
|---|---|
| Concept selection | ❌ 0.8% concept linkage |
| Concept combinations | ❌ same |
| Hidden constraints | ❌ no readable stems |
| Misconception traps | ❌ 77% of distractor DNA is "other" |
| Distractor design | ❌ same |
| Reasoning patterns | ❌ `solution_dna` empty |
| Information hiding | ❌ no readable stems |
| Multi-step thinking | ❌ `solution_dna` empty |
| Data interpretation | ❌ no readable stems |
| Assertion–Reason logic | ⚠️ counts only (227 items), no content |
| Case-study structure | ❌ no readable stems |
| Graph / diagram usage | ❌ not captured |
| Numerical design | ⚠️ `construction` gives relation + answer, no parameter rationale |
| Time pressure | ❌ not captured |
| Elegance / originality | ❌ no readable stems |
| **Question-type mix** | ✅ **measured and reliable** |

---

## 4. What IS measurable — and it is immediately useful

### 4.1 Authentic archetype mix (measured over 15,803 items)

| Exam | n | mix |
|---|---|---|
| NEET | 14,432 | **mcq 87.5% · match 11.0% · assertion_reason 1.6%** |
| JEE_ADVANCED | 987 | **mcq 74.3% · numerical 18.0% · match 7.6%** |
| JEE_MAIN | 384 | **mcq 98.4% · match 0.8% · numerical 0.5% · assertion_reason 0.3%** |

### 4.2 Difficulty by form (structural proxy — treat as indicative, not measured)

| Form | easy | moderate | hard |
|---|---|---|---|
| `mcq` | 93% | 7% | — |
| `numerical` | 51% | 33% | 16% |
| `match` | — | 45% | **55%** |
| `assertion_reason` | — | — | **100%** |

Even discounted as a length proxy, the ordering is informative: **match-the-columns and assertion–reason
are the structurally heaviest forms in the real corpus, and plain MCQ is the lightest.**

### 4.3 The authenticity gap in Lane C, stated against the corpus

| Archetype | Lane C today (90 items) | NEET real | JEE_ADV real |
|---|---|---|---|
| single/multi-step numerical | **82%** | ~0% | 18.0% |
| assertion_reason | **18%** | 1.6% | — |
| mcq (single-best-answer, non-numerical) | **0%** | **87.5%** | 74.3% |
| **match (match-the-columns)** | **0%** | **11.0%** | 7.6% |

Two findings follow, and neither comes from an internal metric:

1. **Lane C over-produces numerical questions by roughly 4× relative to NEET, and produces none of the
   dominant form.** NEET is overwhelmingly conceptual single-best-answer; Lane C is overwhelmingly
   arithmetic. On mix alone, our output would not pass for NEET material.
2. **`match` is 11% of NEET — 1,661 real items — and Lane C generates zero of it.** It is also the hardest
   common form in the corpus (55% hard, 0% easy). It is deterministically constructible: a match item is a
   set of certified pairs with a computed key, and every wrong option is a specific mispairing that can be
   proved wrong. This is the single largest authentic gap that is also within reach of a $0 lane.

---

## 5. Honest conclusion

The instruction — *reproduce the DNA of real examination questions rather than chase internal metrics* — is
the right instruction, and I am not able to follow it fully with the data as it stands. Saying otherwise
would mean inventing a benchmark and calling it measured, which is the failure mode this whole architecture
exists to prevent.

What can be done now, driven by the corpus rather than by a depth score:

* **rebalance the archetype mix toward the measured distribution**, which immediately makes output more
  exam-like;
* **build the `match` archetype**, the largest authentic gap and a genuinely hard form;
* **stop treating depth as the target**, per the brief.

What would make the remaining twelve dimensions minable is a defined body of work on the corpus itself, not
on the generator:

1. **per-question segmentation** — split chunk spans into individual stems with their options (today three
   items can resolve to one chunk that begins with instruction boilerplate);
2. **answer keys** — currently absent for the whole corpus; this is the standing W0 blocker and is
   owner/data-gated, not an engineering choice;
3. **concept linking** — 0.8% → usable coverage, which is what unlocks concept selection and combination
   DNA;
4. **`solution_dna` population** — the field exists and is empty; filling it is what unlocks reasoning
   patterns and multi-step DNA;
5. **a real misconception taxonomy** to replace `other` at 77%.

Until at least (1) and (3) exist, "reproduce the DNA" can be honoured for **question-type mix and form
difficulty ordering**, and for nothing else.

---

## 6. Reproduction

```sql
-- corpus scale and span
SELECT COUNT(*), MIN(year), MAX(year) FROM pyq_item;
SELECT COUNT(*) FROM (SELECT DISTINCT exam, year FROM pyq_item WHERE year IS NOT NULL);

-- the blockers
SELECT COUNT(*) FROM pyq_item WHERE concept_kc IS NOT NULL AND concept_kc <> '';   -- 132
SELECT difficulty_basis, COUNT(*) FROM pyq_item_difficulty GROUP BY 1;             -- structural_proxy 15803
SELECT dimension, provenance_class, n_sittings FROM exam_dna_v2;                   -- insufficient_evidence
SELECT SUM(solution_dna IS NOT NULL AND solution_dna <> '') FROM question_dna;     -- 0

-- what is usable
SELECT exam, question_type, COUNT(*) FROM pyq_item GROUP BY 1, 2;
SELECT i.question_type, d.difficulty_label, COUNT(*) FROM pyq_item i
  JOIN pyq_item_difficulty d USING(item_id) GROUP BY 1, 2;
```
