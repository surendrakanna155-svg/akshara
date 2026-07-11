# QP Content Readiness Remediation — AI OFF

**Date:** 2026-07-11
**Scope:** The QP Content Readiness Remediation Program requested after the 2026-07-11 output-quality
audit (which found 0/57 teacher-ready papers). Engine **architecture frozen**; work confined to the
sanctioned knowledge/content lanes plus documented, regression-locked engine exceptions.
**Method:** Re-ran the *exact same* 57-paper / 1747-question AI-OFF matrix after every phase, measuring
the real student/teacher-facing output — not internal test counts. Certified QP engine remains frozen.
**Branch:** `feature/qp-content-readiness` (7 commits). Full KIE suite: **321 tests green** (was 310).

---

## The one question, answered honestly

> **"Out of the same 57-paper matrix, how many papers can a real teacher print and give to students
> without manually rewriting questions or answer keys?"**

Two honest numbers, because they answer two different things:

- **Papers whose *printed* body needs zero rewriting: 36 of 48 served** (the 9 Class-X board papers are
  now *correctly refused*, not generated). Every question printed in those 36 has a real stem, valid
  options, and a real answer key — nothing fake, nothing to rewrite.
- **Papers that are a *complete* teacher-ready exam (≥90 % of the blueprint filled): 0.**

So: **a teacher can now print a clean, correct, honest paper from 36 of 48 scopes — but it will be
SHORT.** Across the whole matrix only **69 of ~1480 blueprint positions (4.7 %)** can be produced
deterministically from the certified corpus with AI off. **No scope yields a full-length exam.**

This is a fundamentally different failure than the baseline. Before, 100 % of papers *looked* full but
were fake (97.8 % of objective items were authoring stubs printed as questions, 93.7 % of answers were
generic placeholders). Now the engine **never presents anything it cannot stand behind** — it prints
what is real and honestly lists the rest as "requiring authoring". **The remaining gap is the CORPUS,
not the engine.**

---

## Exit-gate scorecard (measured on the printed student body)

| Gate requirement | Baseline | After | Status |
|---|---|---|---|
| Student-facing authoring specs/placeholders | 402+ printed | **0** | ✅ |
| Optionless / malformed filled MCQs (printed) | rendered w/o options | **0** | ✅ |
| Fabricated answers | none (but fake keys) | **0** | ✅ |
| Board / grade corpus misuse | 9 papers | **0** (9 refused) | ✅ |
| Broken concept-title / OCR artifacts (printed) | 19 | **0** | ✅ |
| Teacher-ready keys w/ mark-appropriate depth | generic 93.7 % | printed descriptive **100 % real, mark-weighted** | ✅ |
| Materially improved answerable coverage | 3.2 % | **4.7 %** printed (objective fill 2.2 %→4.3 %) | ⚠ improved but corpus-capped |
| Materially reduced "General" concentration | 29.3 % | **7.2 %** (printed); in-scope 74 %→55 % | ✅ |
| Materially reduced clone repetition | within-paper n/a | **within-paper 0** across 12 papers | ✅ |

All *integrity* gates pass. The two ⚠ items (coverage) are bounded by the corpus, quantified below.

---

## What was done (7 phases, each tested + committed)

Recovery-first, one owner, DB backed up before any at-rest mutation. Priority order preserved; sequenced
by dependency so each phase is independently verifiable.

1. **Audit harness** (`scripts/reports/qp_output_audit.py`) — reproducible 57-paper measurement at the
   **data layer** (not the lossy JSON renderer). This is both the tool and the exit-gate verifier. It
   immediately proved the "0/29 optionless MCQ" finding was a *render omission*, not a data defect
   (filled MCQs already carry valid options; `validate.py` enforces it).
2. **P1-2 concept-quality repair** (`kie/curate/concept_quality.py`, content lane) — high-precision,
   individually-calibrated rejection of residual non-concepts the runtime sanitizer is deliberately too
   lenient to drop (publication names, glued chapter headings, clause extractions, pedagogy scaffolds,
   a hand-verified bare-generic stoplist) + subject-mislabel fixes. **69 rejected, 3 resubjected;
   junk titles in output 19 → 0.** Verified zero real-concept rejections.
3. **P1-3 chapter attribution** (`qpgen/chapters.py` reference-data refinement — sanctioned by the file's
   own contract) — expanded keyword coverage + new Math "Geometry & Mensuration" and Biology
   "Biomolecules & Metabolism" / "Reproduction & Development" chapters. **In-scope General 74 % → 55 %;
   printed General 29.3 % → 7.2 %.**
4. **P1-1 template expansion** (`kie/curate/templates_ext.py`, content lane via the existing hook) —
   10 solver-verified families for the corpus's actual high-frequency computable concepts (Equilibrium,
   Probability, Integers, Magnetic Flux, Circles, gravitational force, Perimeter, Triangle, Parallelogram,
   Median). **Objective coverage Math 4 %→12 %, Physics 5 %→6 %; family library 80 → 90.**
5. **P0-1 + P0-2 render honesty** (`qpgen/assemble.py` — documented, regression-locked engine exception,
   confined to the two render functions). The student paper now contains **only** teacher-ready items
   (real stem, valid options rendered as (A)–(D), real key); SPEC stubs and generic-guideline answers go
   to a clearly-separated **"Items requiring authoring"** worklist; the header states honest coverage;
   descriptive keys render as **mark-weighted marking schemes** grounded in the concept's own evidence.
6. **P1-4 honest board support** (`qpgen/engine.py` — documented exception) — the three **Class-X board**
   blueprints **fail closed** ("no certified Class-X board corpus; refusing to generate from Class 11-12
   content"). Class-XII board scopes stay supported.
7. **P1-5** — verified difficulty labels are already honest (engine labels the *actual* candidate
   difficulty and surfaces relaxation in Generation Notes; difficulty is not asserted on the student
   paper) and within-paper repetition is **0**. No code change required.

### Engine exceptions taken (all documented + regression-locked)
Per the directive's exception protocol — proven student-facing correctness/gate defects with no
content-layer fix:
- `qpgen/assemble.py` — render options; suppress specs/placeholders from the student body (the renderers
  are the only output path; no content hook exists).
- `qpgen/engine.py` — Class-X board fail-closed guard (blueprints are engine data; explicit gate item).
- `qpgen/chapters.py` — chapter reference-data refinement (data-only; sanctioned by the file's own docstring).

The upstream pipeline (scope · selection · materialization · validation · assemble numbering) is **unchanged**.
No fabrication anywhere; where evidence is insufficient the item is left explicitly unfilled.

---

## Raw evidence — a real rendered paper (CBSE XII Physics, seed 11, AI OFF)

```
**Deterministic coverage (AI OFF):** 4 of 35 blueprint questions are ready to print with a
complete answer key. The remaining 31 ... are listed under *Items requiring authoring*.

## Section A
1. A body of mass 5 kg is near the Earth's surface (take g = 10 m/s²). Calculate the
   gravitational force (weight) acting on it.  (1 mark)
   (A) 5 N  (B) 15 N  (C) 45 N  (D) 50 N
2. A steady current of 13 A flows through a conductor for 16 s. Calculate the total charge ...
   (A) 208 C  (B) 29 C  (C) 13 C  (D) 16 C
...
## Answer Key & Marking
1. Correct option: **50 N** — F = m·g = 5 × 10 = 50 N.
2. Correct option: **208 C** — Q = I·t = 13 × 16 = 208 C.
4. [3 marks] Instantaneous velocity ... is defined as the limit of the average velocity.
   Award marks for: correct statement/definition ...; a supporting explanation or related principle.
```
Every printed item is real, solver-verified, and keyed. The other 31 are honestly deferred, never faked.

---

## The corpus ceiling (why full teacher-ready papers are still 0)

This is the load-bearing finding. The certified corpus simply does not contain the content needed to
fill full papers without AI, and no engine/content-quality work can fabricate it:

- **Definitions:** only **25 of 1415** active concepts have a usable definition; the grounded-definition
  miner (`enrich.py`) is idempotent at 25 — 0 more are safely extractable (the rest would require copying
  source text or fabricating). → descriptive keys are hard-capped.
- **Computable concepts:** ~**3–12 %** of objective concepts match a solver-verified formula (Biology 0 %);
  the majority are conceptual (Refraction, Inductance, Transcription) and **correctly stay specs**.
- **Distractors / misconceptions:** the `distractors` and `common_misconceptions` tables are **empty** →
  conceptual MCQs cannot be built without fabrication and are left to authoring.
- **Boards:** `concept_board_mappings` is **100 % FOUNDATION** with no CBSE/AP/TS or Class-X grade data →
  Class-X board papers correctly fail closed.

Result: 69/1480 (4.7 %) deterministically fillable. This is a **data-acquisition** problem, not an
engineering one — the engine is now correct, honest, and safe.

---

## Smallest next improvement (to raise teacher-ready above 0)

Ordered by teacher-ready yield per unit effort. **All are corpus/data work — the engine needs nothing
more here.**

1. **Grounded definition backfill (biggest lever for descriptive papers).** The descriptive path is
   capped at 25 definitions. A governed, citation-checked definition pass (short, verbatim-or-paraphrased,
   in-syllabus) over the top-frequency concepts per subject would let descriptive blueprints fill — each
   defined concept that selection reaches becomes a real, mark-weighted key.
2. **A curated distractor/misconception bank** for high-frequency conceptual concepts → converts the
   ~95 % conceptual-MCQ backlog into real 4-option MCQs deterministically (the renderer + validator
   already support them).
3. **More computable families** along the measured frequency tail (extends P1-1) — cheap, additive,
   each lifts objective fill for every paper.
4. **Fill-aware selection** (would need an engine change, so gated): steer objective slots toward
   concepts that have a template/bank, so a computable-heavy scope can fill a *full* paper.
5. **Real board/grade corpus ingestion** to lift the P1-4 fail-closed on CBSE/AP/TS Class-X.

Until (1)/(2) land, AI-OFF full papers remain impossible for conceptual/board scopes; the honest interim
is exactly what the engine now does — print what is real, refuse or defer the rest, and never lie to a teacher.

---

## Bottom line

The remediation delivered every **output-integrity** exit gate: no spec, placeholder, optionless MCQ,
OCR artifact, junk title, board misuse, or fabricated answer can reach a student paper; keys are real and
mark-weighted; "General" and repetition are materially down; boards fail closed. **36 of 48 served
scopes now print a clean, correct, honest (if short) paper — up from 0 usable papers at baseline.**

But **0 scopes produce a full teacher-ready exam**, because the certified corpus holds only ~4.7 % of the
deterministic content a full paper needs (25 definitions, ~3–12 % computable coverage, 0 distractors, no
board corpus). The engine is now trustworthy; **reaching full teacher-ready papers is now a data problem**
— grounded definitions and a distractor bank — not an engineering one.

The certified QP engine architecture remains **frozen**; every change was a sanctioned content lane or a
documented, regression-locked exception.
