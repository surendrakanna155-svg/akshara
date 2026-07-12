# Gold Benchmark Plan

**Date:** 2026-07-11 · **Status:** SPEC (proposal — not implemented)
**Purpose:** Define the success metric before building. The system is not "done" when the endpoint
returns a paper — it is validated when **independent teachers, reviewing blind samples, consistently judge
Akshara questions as educationally strong, correct, diverse, useful, and competitive** with high-quality
Indian assessment material.
**Non-negotiable:** do not scale generation to lakhs of items until a measured, blind-reviewed quality
lift over the current engine is proven.

---

## 1. Why the frozen 57-paper matrix is not enough

`qp_output_audit.py` measures coverage, fill, format-legality, label self-consistency, and repetition. It
is a good **constraint/coverage regression** and must be kept. But (from the docs audit) **every one of its
metrics can be passed by a weak-but-valid question**: a paper of trivial single-substitution MCQs with
arithmetic-noise distractors scores 100% clean. `d4_desc_printed_real_pct` counts a broken 12-word OCR
fragment as "real"; `gate_stem_artifacts` never inspects the answer key. The matrix cannot see educational
quality. The gold benchmark is the instrument that can.

The two are complementary: the matrix is **automated + broad + cheap** (runs every change); the benchmark
is **human + deep + expensive** (runs at milestones). Neither replaces the other.

---

## 2. Benchmark construction

### 2.1 Concept selection
Representative concepts across Mathematics, Physics, Chemistry, Biology/Science, spanning board (CBSE/state)
and foundation (JEE/NEET) profiles. For each concept, require coverage of **multiple archetypes** and
**multiple difficulty bands**, so the benchmark tests diversity and difficulty realism, not just
correctness on easy items.

### 2.2 Expert-reviewed reference set
For each (concept, archetype, difficulty), curate a small **gold reference set** of high-quality items
(from legally usable sources, analysis-only, per the licence ledger) that exemplifies the target bar. This
anchors reviewer calibration — reviewers see what "excellent" looks like for that cell.

### 2.3 Test items
Generate matched items from **both engines** for each cell:
- **Engine A (current):** the frozen qpgen path.
- **Engine B (redesigned):** the Item-Model path as it comes online.
Same concept, same archetype target, same difficulty target — so the comparison is like-for-like.

---

## 3. Blind review protocol

- **Blind:** reviewers do not know which engine produced an item, and items from A/B (and gold references)
  are interleaved in randomized order.
- **Independent:** reviewers are practicing teachers/subject experts, not the build team.
- **Multiple reviewers per item** with an inter-rater agreement measure; disputed items adjudicated.
- **Rubric-scored**, not thumbs-up/down.

### 3.1 Scoring dimensions (each 1-5, with anchors)
```
correctness            — is the answer right and unambiguous?
syllabus_alignment     — in-scope for the stated profile/class?
concept_precision      — tests the intended concept, not a neighbor?
cognitive_depth        — genuine reasoning vs trivial recall/plug-in?
difficulty_accuracy    — does the felt difficulty match the label?
distractor_quality     — are wrong options plausible, misconception-based (MCQ)?
ambiguity              — is there exactly one defensible answer? (reverse-scored)
originality            — fresh, not a recognizable copy/paraphrase?
diversity              — (paper-level) archetype/cognitive/context spread
solution_quality       — is the 4-5 step solution clear, correct, teacher-usable?
teacher_usability      — would you put this on a real paper as-is?
```

### 3.2 Paper-level review
In addition to per-item, reviewers score whole papers for diversity, difficulty distribution, coverage,
and "would you use this paper" — because paper quality is not the average of item quality.

---

## 4. Success criteria (the gate to scale)

The redesigned engine is cleared to scale a given archetype/subject only when, on blind review:
- Engine B's median rubric scores **exceed Engine A's** on cognitive_depth, distractor_quality,
  difficulty_accuracy, diversity, and solution_quality (the dimensions A structurally cannot do), **with
  no regression** on correctness, syllabus_alignment, or ambiguity;
- Engine B reaches an **absolute bar** (e.g. median ≥4/5 on correctness, syllabus, concept_precision,
  ambiguity) — competitiveness is absolute, not merely "better than a weak baseline";
- inter-rater agreement is acceptable (so the scores are trustworthy).

Exact thresholds are set with the reviewers during calibration and recorded before scoring begins (no
moving goalposts).

---

## 5. Cadence

- **Milestone gate:** every roadmap phase that adds an archetype or an Item-Model batch runs a benchmark
  round for the affected cells before that batch is allowed to scale.
- **Regression:** the frozen matrix runs on every change; the benchmark runs at milestones.
- **Drift:** once empirical data exists (Phase 2), benchmark difficulty labels are checked against observed
  difficulty to catch reviewer/engine drift.

---

## 6. Honesty rules

- Report the honest denominator: how many benchmark cells the engine can actually fill vs total.
- Never report a quality claim without the blind-review evidence behind it.
- Preserve all reviewer scores and disagreements; do not cherry-pick.
- A phase that fails its benchmark round does **not** scale — it goes back to Item-Model improvement.

---

## 7. Acceptance criteria

- A calibrated rubric + reference set + reviewer pool exist before any scale decision.
- Blind A/B/gold comparison is run per archetype/subject cell at each milestone.
- Scale decisions are gated on the §4 criteria and recorded with evidence.
- The benchmark and the frozen matrix are both green before a batch is declared production-quality.

---

## Reconciliation Amendment (2026-07-12, post-Fable-5) — measurable acceptance

Governed by `OPUS_FABLE_RECONCILIATION_RECORD.md`. The plan had the right skeleton but was not yet a
measurement instrument. Required before Phase A exit and pre-registered in a committed file **before** any
test items are generated (no moving goalposts):

- **Sample size:** ≥ **30 items per engine per cell-group** under review (fewer ⇒ medians are noise).
- **Reviewers:** ≥ **3 independent** practicing teachers per item; calibrated against the gold reference set
  before scoring; independence + payment declared.
- **Agreement statistic:** Krippendorff's α (or quadratic-weighted κ); a dimension is trustworthy only at
  **α ≥ 0.6**. Below that, re-anchor the rubric — do **not** average low-agreement scores.
- **Statistical test:** paired per-cell **Wilcoxon signed-rank**, declared α = 0.05; "median exceeds"
  without a test is not evidence.
- **Correctness is machine-gated (GATE 4) BEFORE review** — teachers do not certify correctness by opinion;
  they adjudicate only genuinely contested items.
- **Absolute bar is primary:** clear a cell only when Engine-B reaches median ≥ **4/5** on correctness,
  syllabus, concept_precision, ambiguity **against gold anchors**; beat-Engine-A is a **secondary** check
  (Engine-A's style is recognizable, so beating a 0/57 engine is a floor, not a target).
- **Difficulty-accuracy** stays **advisory** until Phase-2 empirical data exists (teacher-felt difficulty is
  a weak estimator).
- **Biology non-numeric cells are mandatory** in every benchmark round that gates a Biology-touching batch —
  Biology is the make-or-break lane (Record §7 Hypothesis B).

This is distinct from the AIP §11 "eval harness" (a golden-set regression harness for model swaps); both must
be satisfied so the D7 model-change obligation is not assumed covered by milestone benchmarks.
