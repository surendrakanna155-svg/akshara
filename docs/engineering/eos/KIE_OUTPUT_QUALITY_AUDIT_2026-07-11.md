# KIE Question-Paper Output Quality Audit — AI OFF

**Date:** 2026-07-11
**Scope:** Real generated papers from the *improved* KIE (post 5 quality phases), engine **frozen**, **AI disabled** (`KIE_AI_AUTHORIZED` unset, no `--allow-ai-fill`).
**Method:** Independent, output-first. Generated a 57-paper matrix (19 configs × 3 seeds), measured the actual student/teacher-facing text, and read raw papers by hand. **Previous certifications and internal test counts were not trusted** — every number below comes from the generated papers themselves.
**Constraint honoured:** No code was modified during this audit.

---

## The one question, answered honestly

> **"If a real teacher generates a paper today with AI OFF, is the output genuinely ready to print and give to students without manually rewriting questions or answer keys?"**

**No.** Not for any of the 57 papers, and not close.

- **0 of 57 papers** were fully print-ready.
- **3.2%** of all questions (56 / 1747) are genuinely answerable by a student *and* carry a real answer key.
- **97.7%** of objective items (1207 / 1236) are printed as **AI-authoring specifications**, e.g. *"[SPEC · author via approved AI] mcq on 'Refraction' … requires 4 options, exactly one correct, 3 plausible distractors."* A student cannot answer that; a teacher must write the entire question and key.
- **93.7%** of the descriptive answers (402 / 429 filled) are the **generic placeholder** *"[Marking guideline — award full marks for a correct, in-syllabus explanation … teacher to confirm key points.]"* — i.e. no model answer.

The engine is **honest** about this (it labels specs and refuses to fabricate — that is the correct design intent), but honesty about being empty is not the same as being usable. With AI off, the current output is a **blueprint scaffold with the questions missing**, not a paper.

---

## Matrix generated

| Axis | Values |
|---|---|
| Exams / profiles | NEET, JEE Main, JEE Advanced, FOUNDATION (CBSE/AP/TS blueprints run under FOUNDATION) |
| Subjects | Physics, Chemistry, Mathematics, Biology |
| Blueprints | `neet`, `jee_main`, `jee_advanced`, `cbse_x_science`, `cbse_xii_physics`, `ap_scert_x_science`, `ts_scert_x_science`, `objective_45`, `descriptive_40`, `mixed_50` |
| Seeds | 11, 42, 777 |
| **Total** | **57 papers · 1747 questions** |

**Board note (finding B, below):** direct board scopes (`--board CBSE/AP/Telangana --class X`) are **refused** — only NEET/JEE/FOUNDATION profiles are certified. Board-style papers only exist as blueprints *rendered from the JEE/NEET grade-11–12 corpus*, which is the root of the realism problem.

---

## The 12 measured dimensions

| # | Dimension | Result | Verdict |
|---|---|---|---|
| 1 | Fully answerable deterministic questions | **3.2%** (56/1747) | ❌ P0 |
| 2 | Objective items emitted as AI specs/placeholders | **97.7%** (1207/1236) | ❌ P0 |
| 3 | Descriptive answers using generic marking guideline | **93.7%** (402/429 filled) | ❌ P0 |
| 4 | Real model-answer quality | 6.3% have a real answer; those are **10–13-word fragments** | ❌ P0 |
| 5 | "General / blank" chapter concentration | **41.5%** (725/1747) | ❌ P1 |
| 6 | Concept-title quality in rendered stems | 4.1% overtly junk **on filled stems** + subject mislabels | ⚠ P1 |
| 7 | MCQ option / distractor quality | **0 / 29** filled MCQs carry options | ❌ P1 |
| 8 | Bloom authenticity | 79.3% self-reported met; compute items mislabelled | ⚠ P1 |
| 9 | Difficulty authenticity | **40.8%** self-reported met (59% relaxed) | ❌ P1 |
| 10 | Exam realism vs blueprint | **Structure good, content empty** | ⚠ mixed |
| 11 | Repetition | 103 templates cover **68%** of filled Qs (314/458) | ⚠ P1 |
| 12 | Teacher-ready paper percentage | **0 / 57** | ❌ P0 |

---

## Evidence & raw examples

### [1][2] Objective items are specs, not questions
NEET flagship (`neet_full`, seed 42), first questions a student sees:

```
Physics · Section A
1. [SPEC · author via approved AI] mcq on 'Refraction' (Physics) — bloom=understand,
   difficulty=hard, marks=4; requires 4 options, exactly one correct, 3 plausible distractors…
2. [SPEC · author via approved AI] mcq on 'Inductance' (Physics) …
3. [SPEC · author via approved AI] mcq on 'Electric Field' (Physics) …
```

Per-config answerable rate (student-answerable **and** keyed):

```
neet_full           1.4%     neet_obj_phy/chem/bio   0.0%
jeemain_full        2.7%     jeemain_obj_phy/chem    0.0%
jeeadv_full         4.2%     cbse_xii_physics       14.3%   ← best case
```
Pure objective papers (`*_obj_*`) are **0–7% answerable**. The flagship full exams are **1–4%**.

### [3][4] Descriptive answers — generic or trivial
The 6.3% that have a *real* answer are single-sentence scraped fragments that don't scale to the mark value, several with broken word-spacing:

```
[3-mark] Describe Power.
  → "thetime rate at which work is done or energy istransferred"      (broken spacing)

[5-mark] Discuss Totipotency, illustrating your answer with examples.
  → "the capacity to generate a whole plant from any cell of the plant"  (no examples; 13 words for 5 marks)

[2-mark] State the meaning of Mutation.
  → "change in the genetic material"
```
Real-answer length vs marks (median words): **2-mark → 10 · 3-mark → 12 · 5-mark → 13.** Only **one** 5-mark question in the entire matrix received any real answer. The other 93.7% read:
> *"[Marking guideline — award full marks for a correct, in-syllabus explanation of X; teacher to confirm key points.]"*

### [5] "General" concentration
41.5% of questions sit in a `General <Subject>` or blank chapter bucket:
```
281 General Chemistry · 192 General Biology · 149 General Physics · 103 General Mathematics
```
The chapter graph exists but ~2 of every 5 questions cannot be attributed to a real chapter — unusable for blueprint weighting or "test chapter X" requests.

### [6] Concept-title junk & subject mislabels (leaking into printed stems)
```
concept 'Ohmwas led to his law'  → stem: "Define Ohmwas led to his law."     (merged words, x5 across matrix)
concept 'litres'                 → stem: "Explain litres."                    (a unit, not a concept)
concept 'Logarithms'  tagged Chemistry   (in a "CBSE X Science" paper)
concept "Baye's theorem" tagged Physics  (in a CBSE XII Physics paper)
```
These are printed to the student, not just internal.

### [7] "MCQ" items have no options
All 29 deterministically-filled "mcq" items render with `options: null` — they are actually **numeric compute problems** mislabelled as MCQ:
```
[type=mcq] "A steady current of 13 A flows through a conductor for 16 s. Calculate the total charge." → 208 C  ✓ (correct, but no A/B/C/D)
```
The numbers are computed **correctly** (verified: 13×16=208 C, F=ma=56 N, P=F/A=2 Pa, det[[2,1],[2,3]]=4, V=IR=39 V). But a paper that promises "4 options, one correct" and prints a bare numeric answer is internally inconsistent, and there are **zero** genuine conceptual MCQs with distractors anywhere in the matrix.

### [8][9] Bloom / difficulty authenticity
The compute items are labelled **`bloom=remember, difficulty=hard`** simultaneously — a plug-and-chug formula is neither hard nor recall (it's apply/easy). Engine self-report: **difficulty met on only 40.8%** of items (59% silently relaxed because the candidate pool lacked items at the requested difficulty); bloom met on 79.3%. The labels on the paper are therefore not trustworthy signals for a teacher choosing difficulty.

### [10] Exam realism — the one relative bright spot
Blueprint **structure** is genuinely good:
```
NEET:     172 Q / 688 marks (vs real 180/720), P45 · C45 · B82, all MCQ, +4/−1 negative marking ✓
JEE Main:  73 Q / 292 marks (vs real 75/300), P25 · C23 · M25, 60 MCQ + 13 numerical ✓
JEE Adv:   32 Q / 108 marks, balanced P/C/M, MCQ + numerical + match ✓
```
Sections, internal choice, timing, and negative-marking rules are all faithful. **The frame is exam-real; the frame is empty.**

### [11] Repetition
103 filled-stem templates (numbers masked) account for **314 of 458 filled questions (68%)**. Because the deterministic fill is ~40 universal formula families, filled questions are near-clones across papers and seeds:
```
x9  "evaluate the determinant of the #×# matrix [[#,#],[#,#]]"
x8  "a steady current of # a flows … calculate the total charge"
x6  "describe gravitation the universal law"   x6 "state the meaning of nuclei"
```
Within a single paper, concept duplication is rare (one case: `Wien's displacement law` ×2 in NEET). Cross-paper repetition is severe.

### [12] Teacher-ready papers
**0 / 57.** No paper reaches even a low print-ready bar (all slots filled, real stems, real keys).

---

## Root causes (verified in frozen code, read-only)

1. **Objective fill depends on a ~40–80 formula-template registry keyed to compute concepts** (`qpgen/templates.py`, 80 families: 74 numeric-MCQ, 4 assertion-reason, 1 match). `find_template()` binds only via conservative keyword groups (`ohm`, `pressure`, `kinetic energy`, …). The corpus concept pool is dominated by **conceptual** topics (Refraction, Inductance, Transcription, Plastids) that match **no** template → `build_spec()` → SPEC. This is the direct cause of the 97.7% spec rate and is **by design** ("templates/distractors/values = 0 … become validated SPECS" — `materialize.py` header).

2. **Descriptive fill pulls a one-line definition from the KIE** (`usable_definition`); when none is clean enough (the common case) it falls back to the generic marking guideline. Hence 93.7% generic and, where a definition exists, a fragment that ignores the mark weight. The concept text itself carries scrape artifacts ("thetime", "istransferred").

3. **Concept extraction is still noisy** (as long flagged: only `subject_domain` is reliable). The 5 curate phases reduced but did not eliminate junk titles ("Ohmwas led to his law", "litres") or subject mislabels ("Logarithms"→Chemistry). Noisy concepts also drive the 41.5% `General` bucket — items without a confident chapter fall through to `General <Subject>`.

4. **Corpus ≠ boards.** The certified corpus is JEE/NEET grade 11–12 foundation. "CBSE/AP/TS Class X" papers are that corpus poured into a board-shaped blueprint, so a "Class X Science" paper contains Integrals, Inverse Trigonometric, and Determinants (grade 11–12, and Mathematics inside a Science paper). Board realism cannot be achieved from this corpus regardless of the engine.

5. **"MCQ" type is assigned to numeric-compute templates** that never produce options — a labelling defect in how compute families map onto MCQ slots.

**These are corpus/coverage limits, not engine bugs.** The engine correctly refuses to fabricate and correctly labels what it cannot produce. The output is unusable-with-AI-off because the deterministic knowledge to fill these slots does not exist yet — exactly as the QP-engine memory warned (templates = 0 at engine freeze; corpus is noisy on concepts).

---

## Findings classified

**P0 — blocks "print today with AI off"**
- **P0-1** 97.7% of objective items are specs, not questions (dims 1, 2). Root cause 1.
- **P0-2** 93.7% of descriptive answers are generic marking guidelines; no model answers (dim 3, 4). Root cause 2.
- **P0-3** 0/57 papers are teacher-ready (dim 12). Aggregate of P0-1/2.

**P1 — materially degrades trust even where filled**
- **P1-1** 0/29 filled "MCQ" items have options; compute items mislabelled MCQ (dim 7). Root cause 5.
- **P1-2** Difficulty label untrustworthy — met on only 40.8%; compute items tagged `remember+hard` (dims 8, 9). Root cause 3.
- **P1-3** 41.5% of items in `General/blank` chapter → blueprint weighting & chapter requests unreliable (dim 5). Root cause 3.
- **P1-4** Junk concept titles + subject mislabels reach printed stems (dim 6). Root cause 3.
- **P1-5** 68% of filled questions are template near-clones across papers (dim 11). Root cause 1.
- **P1-6** Board realism impossible from current corpus (grade 11–12 content in Class-X board frames). Root cause 4.

**P2**
- **P2-1** Descriptive answers ignore mark weight (13 words for a 5-mark "discuss with examples").
- **P2-2** Scrape artifacts in answer text ("thetime", "istransferred", "ofthe").

**P3**
- **P3-1** NEET renders 82 Biology vs the real 90 (candidate-pool limited); minor structural drift.
- **P3-2** Board scopes error out rather than returning a "not certified for boards" explanation to a teacher UI.

---

## Smallest next improvement plan (highest print-readiness per unit effort)

The goal is **usable-with-AI-off**, so every step must add *deterministic* content or stop over-promising. Ordered by leverage:

1. **Stop the MCQ over-promise (P1-1, ~S).** Where a slot is filled by a numeric compute template, render it as a **numeric/short-answer** item (it already has a correct worked answer), or synthesize 3 distractors from the existing `_mcq_options` misconception logic so a real 4-option MCQ prints. This converts today's 29 optionless "MCQ" into either honest numeric items or genuine MCQs with zero new knowledge.

2. **Expand the compute-template registry along the corpus's actual high-frequency computable concepts (P0-1, ~M).** The pattern frequencies already exist in provenance. Prioritise the top computable Physics/Chemistry/Math concepts by frequency; each new family lifts objective fill for every paper. Target the specific concepts that currently dominate the SPEC list (Refraction, Inductance, Electric Field, Oscillations, …) — only the computable ones; the rest stay spec.

3. **Raise the descriptive answer bar (P0-2, ~M).** Replace the generic marking guideline with a **structured, mark-weighted key built deterministically from KIE definition + concept-graph neighbours** (definition → key points → mark split), and gate on answer length ≥ f(marks). Where the KIE has no clean definition, keep the item a spec instead of emitting a hollow "filled" — better an honest gap than a fake answer.

4. **Clean concept titles at render time (P1-4, ~S).** A deterministic sanitiser pass on `display_title` (reject merged-word tokens like "Ohmwas", bare units like "litres", enforce subject-consistency e.g. "Logarithms"∉Chemistry). This is a rendering guard, cheap, and removes the most embarrassing student-facing artifacts immediately.

5. **Attribute the `General` bucket (P1-3, ~M).** Use concept-graph chapter edges to reassign `General <Subject>` items to real chapters; where confidence is low, exclude from chapter-targeted requests rather than mislabel.

6. **Gate board scopes honestly (P1-6, P3-2, ~S).** Until a real board corpus exists, have board requests return an explicit "boards not yet certified — showing foundation-corpus practice" notice, so a teacher is never handed a Class-X paper full of grade-12 calculus without warning.

**Do not** wire AI-fill as the answer to P0-1/P0-2. The audit question is specifically *AI-off* readiness; AI-on is a separate, already-gated path. The deterministic gap must be closed with deterministic content or with honest specs — not by moving the goalposts to AI.

---

## Bottom line

The **engine, blueprints, structural realism, refusal discipline, and numeric correctness are sound** — this is a well-built scaffold that never fabricates. But measured on real output with AI off, it is **not a paper generator today; it is a paper *specification* generator.** A teacher pressing "generate, AI off" gets an exam-shaped shell in which ~97% of objective questions and ~94% of answer keys must still be written by hand. **Print-ready: no. 0 of 57 papers.**

The certified QP engine remains **frozen**; no code was changed by this audit.
