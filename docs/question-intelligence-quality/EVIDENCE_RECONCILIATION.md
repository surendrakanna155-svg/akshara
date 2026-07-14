# Project-wide JEE/NEET evidence reconciliation — the conversion funnel

**Date:** 2026-07-14 · Owner-directed complete read-only audit across ALL project-owned acquisition/OCR
evidence (not just qie.db/KVS), to answer the decision-critical question: **have the downloaded/OCR'd JEE/NEET
files already been converted into the structured knowledge the generation engine needs — or do we possess them
unstructured?** Read-only; nothing modified.

## Answer (decision-critical)
**We POSSESS a large body of JEE/NEET evidence — OCR'd and question-extracted with answer keys — but it was
never converted into machine-usable knowledge (concept-bound relations / structured facts), and it does not
reach the QIE→qpgen path.** This is "we possess it but failed to structure it," not "we do not possess it."

## Evidence inventory (project-owned, incl. gitignored)
`curriculum/` = 58 GB. Relevant stores:
- **`resources/foundation/` — 1,199 raw JEE/NEET PDFs** (JEE_Main 75, JEE_Advanced 20, NEET 152, AIIMS 26,
  AIPMT 6, NTA_Sample 1, Practice 54, Cursor_Downloads 865). The organized raw acquisition.
- **`staging/qcorpus_noncert/` (1.1 GB, gitignored) — the Cursor OCR/extraction lane**: 863 docs, 46k page/
  question images, and derived manifests: **22,759 extracted questions**, 91,878 equation records, 70,541
  visual assets, 12,926 page extractions.
- `resources/archive/board_out_of_scope/` 27 GB — board material, correctly OUT of JEE/NEET scope.
- `downloads/duplicates/` 7.3 GB — already-deduplicated copies; `downloads/failed/` 588 MB.
- `knowledge/kie/kie.db` — the certified corpus DB (below).

## Two processing lanes — both OCR'd/extracted, NEITHER structured into knowledge

**Lane A — `kie.db` (certified corpus, feeds qpgen scope):** 380 exam-paper docs → **42,141 chunks · 4,853
question_patterns · 3,006 concepts · 317 formulas**. BUT the concept/formula layer is names-only: **all 317
`formulas` have `expression`=the law's name and `symbols`=NULL — 0 machine-usable relations.**

**Lane B — `qcorpus_noncert` (staging, gitignored, explicitly "never merged into kie.db"):** 863 DPP/
chapterwise docs → **22,759 questions** (9,421 COMPLETE · 12,074 MCQ · **10,354 with answer keys** · 7,585 with
solutions), by subject **Physics 10,967 · Chemistry 5,030 · Mathematics 4,052 · Biology 1,798**. Its 91,878
"equation candidates" are **font-glyph detections** (`text`="æ"/"ö"/"ç" + bbox), **not parsed relations**. Its
README states no DNA mining / structuring / generation is done in the lane ("later, only under approved
architecture with owner approval") — so it was **never structured**. It fed only ~2,996 *thin* DNA rows into
`qie.db` (concept labels, empty solution_dna).

## The 10-state conversion funnel

| State | Status |
|---|---|
| 1 ACQUIRED | ✅ 1,199 foundation PDFs |
| 2 OCR'D | ✅ both lanes (kie 42k chunks; qcorpus 863 docs / 12,926 pages) |
| 3 QUESTION/TEXT EXTRACTED | ✅ 22,759 questions (9,421 complete, 10,354 answer keys) |
| 4 STRUCTURE EXTRACTED | ◑ partial (MCQ options/answers in qcorpus; concepts+patterns in kie.db) |
| 5 INGESTED INTO CORPUS/DB | ◑ kie.db chunks/concepts/patterns; qie.db thin DNA — qcorpus NOT merged |
| 6 **CONVERTED → MACHINE-USABLE KNOWLEDGE** | ❌ **NO** — no concept-bound relations; no structured facts; formulas=names; KVS empty; equations=glyphs |
| 7 VERIFIED (locked hierarchy) | ❌ only the ~11–14 hand-built qie concepts |
| 8 AVAILABLE TO COMPOSITION ENGINE | ❌ only those ~11–14 |
| 9–10 THROUGH QIE→QPGEN PRODUCT PATH | ❌ only those ~11–14 (JEE Math 6/Phys 5/Chem 0; NEET Bio 3/Phys 5/Chem 0) |

**The break is at state 6 (structuring), for evidence that has already reached states 1–3.**

## The convertible prize (why conversion is worth it) — measured lower bound
Deterministic title-matching of the 6,113 clean, complete, answer-keyed extracted questions against the
certified in-scope concepts:

| | Physics | Chemistry | Biology |
|---|---|---|---|
| certified concepts with ≥2 matching answer-keyed questions | JEE **29** / NEET **29** | JEE **4** / NEET **5** | NEET **30** |
| qie covers today | 5 | **0** | 3 |

Even this crude lower bound shows the existing evidence carries answer-keyed question support for ~6–10× more
certified concepts than qie covers now, across the currently-empty Chemistry and thin Physics/Biology — enough
to materially rebalance papers **if structured**.

## What conversion requires (and its honest yield profile)
The evidence is **conceptual/factual MCQs + answer keys + OCR-glyph math**, not clean symbolic relations:
- **Qualitative/factual knowledge (structure-function, cause-effect, process, concept facts):** VIABLE via a
  governed extractor — LLM proposes a structured fact from (stem + answer-key), verified by answer-key evidence
  + multi-source/Tier-2 corroboration + an independent examiner, bound to a certified concept, then the
  compositional engine authors a NEW question from the verified fact (never cloning the source). This is the
  path to the Chemistry(factual)/Biology coverage.
- **Quantitative relations (named laws):** LOW deterministic yield — the relations are not present as clean
  symbols (equation manifest = glyphs; numeric-question math OCR is garbled). Answer-key-verified relation
  *induction* is possible on the clean-numeric subset but partial; the balance of named-law relations would
  otherwise need canonical curation (a separate owner-flagged call).

The owner has authorized LLM-as-extraction-assistant for this task **with** verify-before-register and the
locked hierarchy (deterministic/evidence first; LLM never truth; no source-question copying).

## Bottom line
- **Possession: YES**, large and multi-subject, quantified above.
- **Conversion state: NOT DONE** — the structuring step (state 6) was explicitly deferred and never built.
- **Next (warranted): build the governed structured-extraction bridge** — start with the VIABLE, verifiable
  slice (answer-keyed factual knowledge → verified concept-bound facts → engine authors fresh questions → real
  qpgen path → re-measure balance), which the measured prize shows can lift Chemistry off 0 and Physics/Biology
  well beyond today. `qpgen`/`kie.db` untouched; bank not promoted; broad acquisition remains HOLD.
