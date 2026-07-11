# KIE Question Intelligence Audit — Why the JEE/NEET Corpus Isn't Becoming Questions

**Date:** 2026-07-11
**Type:** Deep READ-ONLY audit. No code changed. QP engine frozen.
**Core question:** Why can't the system turn the existing 33,870 problem-oriented JEE/NEET chunks
into strong, original, deterministic, copyright-safe competitive-exam questions?

---

## Answer, up front

**Yes — we are massively underusing the corpus, and the cause is architectural, not a shortage of
definitions.** The chunks contain **~5,224 clean, English, computational, complete MCQs** (each with
a stem, four options = the correct answer + three *real human-authored distractors*, and implicit
formulas/parameters) plus **776 English assertion-reason** problems and **8,612 chunks carrying
explicit equations**. Almost none of this structure ever leaves the `chunks` table.

The intelligence pipeline loses the problem structure at **Phase 7 (Question Intelligence)**, which is
**"analysis-only" by design**: it reduces every one of the ~14,000 detected PYQ problems to a
`(concept, question_type, bloom, difficulty)` **frequency tuple** and a **metadata-only "skeleton"**
string, then **DELETES the `distractors` and `question_templates` tables and never repopulates them**.
The real problems — formulas, variables, numeric values, options/distractors, reasoning, answers —
are discarded. Generation (`qpgen`) then builds only from **94 hand-authored formula templates** +
grounded definitions. **The template mechanism (parameterize → solver-verify → render original) is the
correct architecture — it is simply fed by hand-authored families instead of families LEARNED from the
5,000+ corpus problems.** That missing "learn a parametric family from a source problem" stage is the
whole gap.

**So definitions are NOT the JEE/NEET bottleneck. Structural learning from the existing problems is.**

---

## Evidence for the 18 audit points

| # | Audit point | Finding (measured) |
|---|---|---|
| 1 | question_patterns extraction quality | 4,853 rows but only **164 distinct skeletons**; 4,848 are <60 chars. Every "skeleton" is a metadata string like `mcq\|bloom=understand\|difficulty=hard\|options=4`. **No problem structure.** |
| 2 | Math/problem structures from chunks | **Not extracted.** Chunks: 1,046 "calculate", 1,934 "find the", 2,103 "value of", 8,376 " = ". ~5,224 clean computational MCQs exist; 0 structurally abstracted. |
| 3 | Formula / variable-relationship extraction | `formulas` = **281 rows, all bare named-law tokens** ("Bernoulli's principle"), **0 contain `=`** or variables. 8,612 chunks carry equations; relationships never captured. (`phase5_concept.py` mines only the *name*.) |
| 4 | Numerical parameter binding | **None from the corpus.** Only the 94 hand-authored templates carry parameters; source problems' numbers are discarded. |
| 5 | Multi-step reasoning extraction | **Not extracted.** Only a crude bloom label survives; the reasoning chain is dropped. |
| 6 | Concept-combination patterns | **Not captured.** `concept_edges` has 1,482 `related` edges but they aren't used to model multi-concept problems; patterns aggregate per single concept. |
| 7 | PYQ structural abstraction | **The core gap.** `phase7_questions.py` is analysis-only: it counts frequency per tuple and stores a metadata skeleton. Real abstraction was deferred to the *gated Phase-8 AI*, which is OFF — so it does not exist deterministically. |
| 8 | Difficulty-driving factors | Heuristic only (`len(text)>600` or a "hard" verb ⇒ hard). Result: `difficulty=hard` dominates virtually every pattern. No real driver analysis (multi-step, combination, trap). |
| 9 | Misconception / trap extraction | **0.** `common_misconceptions` empty; `distractors` table deleted+empty. The ~15,000 real wrong options across 5,224 MCQs (i.e., real traps) are never mined. |
| 10 | Distractor strategy extraction | **0 from corpus.** Distractors are only hand-authored numeric near-misses in `templates.py`. |
| 11 | Assertion-Reason patterns | 378 AR patterns (metadata only); **776 English AR chunks** with real structure exist, unabstracted. |
| 12 | Statement-based MCQ patterns | Not distinguished — folded into generic `mcq`. |
| 13 | Integer / numerical-answer patterns | 537 `numerical` patterns (metadata); 123 integer-answer chunks; structure not extracted. |
| 14 | Multiple-correct patterns | **Not even detected.** `classify_type` has no `multiple_correct`; count in KIE = **0**. |
| 15 | Graph/diagram-dependent patterns | **Not detected or flagged.** Diagram-dependent problems can't be regenerated deterministically and aren't identified/excluded. |
| 16 | JEE Advanced composition | **Invisible.** `question_patterns.exam` is hard-coded `"foundation"` for all 4,853 rows; multiple-correct / paragraph / matrix-match / integer types = 0. Advanced-specific composition is lost. |
| 17 | Is Phase 7 reused by qpgen? | **Only as a metadata index.** `pool.py` reads `question_patterns` for bloom/difficulty/frequency/years to set slot metadata. It never reads `stem_skeleton` (metadata anyway). The **2,015 draft `question_families` are referenced by qpgen ZERO times.** |
| 18 | Stranded evidence | **Massive.** ~5,224 clean computational MCQs + 776 AR + 8,612 formula-bearing chunks + ~15,000 real distractors — all sit in `chunks`, none reach generation. Problem structure never leaves the chunks table. |

### The mechanism, in code
`phase7_questions.run()` (lines 92-150): for each question chunk it computes `qtype/bloom/diff/opts`,
maps concepts, and aggregates `agg[(concept,qtype,bloom,diff)] = {freq, years, opts}`. It writes
`skeleton = f"{qtype}|bloom={bloom}|difficulty={diff}|options={opts}"` — "structure only, no source
text" — and at the top of the transaction runs `DELETE FROM distractors, question_templates,
question_families, question_patterns`, repopulating only the last two (patterns=metadata,
families=empty drafts). The problem itself is never parsed for variables, values, formula, options, or
answer.

---

## How much of the corpus can support the structural-learning approach

Measured on the real corpus (complete MCQ = stem + all four options present):

- **7,746** complete `(1)(2)(3)(4)` MCQ chunks · **6,312 (81%)** predominantly English · **5,325 (68%)**
  English + numeric/units (computational) · **5,224 (67%)** English + numeric + word-rich = **cleanly
  abstractable computational problems**.
- **776** English assertion-reason problems · **714** matching-column chunks · **123** integer-answer chunks.
- Each computational MCQ already carries its **3 real distractors** (a ready-made, human-validated
  misconception strategy) and its **correct answer** (a ready-made solver check).

Caveats (honest): the math-dense regions have OCR noise, and ~19% of complete-MCQ chunks are in regional
scripts (Hindi/Bengali) — those are excluded above. Diagram-dependent and novel multi-step problems
won't parameterize cleanly and should be flagged, not forced. Realistically a meaningful fraction of the
~5,200 (those matching a recognizable formula relationship) are directly convertible — already **1-2
orders of magnitude more than the 94 hand-authored families.**

---

## Smallest architecture-compatible plan (proposal only — no code changed)

The existing template path is exactly the target flow and is FROZEN-friendly: `templates.REGISTRY`
(param → solver-verify → original) is fed via the sanctioned `kie.curate.templates_ext` hook. The
missing stage is learning families from the corpus instead of hand-writing them. Proposed pipeline —
`source problem → abstract pattern → variable/constraint schema → deterministic parameterization →
solver verification → original question` — realized as a deterministic content-lane miner:

1. **Parse** each clean English computational MCQ chunk into `{quantities+units, numeric values,
   4 options, correct option}` (deterministic; the answer is recoverable because the correct value is
   one of the four options).
2. **Recognize by solver-verification, not guessing.** Match the parsed quantities against a formula
   library (start from the 94 families' formulas + a curated physics/chem/math relation set) and keep
   only matches where the formula, fed the stem's own numbers, **reproduces the correct option**. This
   confirms the structure with zero fabrication and zero copying.
3. **Abstract → schema:** the matched formula's variables + observed value ranges become the family's
   parameter schema (grounded in real PYQ ranges, not guessed).
4. **Learn the distractor strategy:** diff the 3 wrong options against the correct value to recover the
   real transforms (e.g., "dropped sin²", "used g=10 not 9.8", "×2") — a grounded distractor generator.
5. **Register** the learned family into `templates.REGISTRY` via the existing `templates_ext` hook,
   bound to the mentioned concept(s). Generation then runs the **unchanged** frozen path
   (materialize → validate → assemble), producing original, solver-verified questions with realistic
   parameters and real-derived distractors.

Properties: no engine change; no AI; no copied source text (output is a fresh parameterization; only the
*structure* is learned, and each instance is solver-checked); it scales with the ~5,200 problems, not
with hand-authoring. Extensions in the same shape cover AR (776), integer/numerical, and — with an
`exam` field fix in Phase 7 — JEE-Advanced multiple-correct/paragraph composition. Diagram-dependent
problems are detected and excluded (deterministic generation can't own diagrams).

**Batch-0 to prove it:** run the miner over the ~5,224 computational MCQs, report how many solver-verify
against the seed formula library, and measure the resulting objective fill-rate lift on the frozen
audit matrix — before investing further.

---

## Bottom line

The 33,870-chunk JEE/NEET corpus is rich with exactly the material the flagship needs — thousands of
complete, solvable, distractor-bearing competitive-exam problems. The pipeline throws that structure
away at Phase 7 (frequency/metadata only; distractor & template tables wiped), and generation falls
back to 94 hand-authored formula families. **We are underusing the corpus badly.** The fix is not more
definitions and not AI — it is a deterministic *structure-mining* stage that learns solver-verified
parametric families (with real distractor strategies) from the existing problems and registers them
through the template hook the engine already supports. That is the smallest architecture-compatible
path to strong, original, deterministic JEE/NEET-quality questions.
