# KIE Content Density — Board Ingestion + Engine Capabilities (CP0–CP5)

**Date:** 2026-07-11
**Scope:** Owner-authorized execution: (1) ingest verified CBSE/NCERT + Telangana Class-X textbook
content via the governed Intake Center; (2) add two minimal deterministic engine capabilities —
board exam profiles/mappings and grounded definition-match MCQ materialization. Recovery-first;
Intake Center gates respected; AI OFF; no fabrication. Branch `feature/qp-content-readiness`.

---

## Honest bottom line (measured)

**Full teacher-ready papers: still 0 of 54 served.** No paper reaches even **50%** blueprint fill.
The program worked and moved every intermediate metric — definition coverage **21 → 47** (more than
doubled), printed deterministic positions **74 → 121 (+64%)**, board scopes now generate **real
Class-X papers** (TS_X best at **40%** fill) — but it did **not** reach the exit target, because the
available board PDFs are OCR-noisy and yield few clean deterministic definitions, and selection is
not fill-aware. **The target is not met; this is reported honestly, not declared complete.**

---

## Requested CP5 metrics (same 57-paper AI-OFF matrix; boards now routed to board profiles)

| Metric | Result |
|---|---|
| **Full teacher-ready papers** | **0 / 54** (≥90% fill: 0 · ≥50% fill: 0) |
| Blueprint fill rate | **7.4%** (121 / 1642 printed) — was 5.0% |
| Objective fill rate | **5.5%** (spec 94.5%) |
| Descriptive answer-key coverage | **100% of printed** descriptive carry a real grounded key (0 placeholders); but only ~5–10% of descriptive *positions* are covered |
| Definition coverage | **47** usable (baseline 21) — +124% |
| MCQ coverage | solver-verified templates + grounded **definition-match** MCQs; objective fill 5.5% |
| Board/grade/subject isolation | **Verified** — 0 Class-10 board concepts leak into NEET/JEE; AP fails closed |
| Remaining unfilled positions | **1521 / 1642 (92.6%)** |

**Board papers (printed / blueprint):** TS_X `ts_scert_x_science` **18/45 = 40%** · CBSE_X
`cbse_x_science` **18/117 = 15%** · AP `ap_scert_x_science` **refused** (no ingested AP corpus).
All integrity gates remain **0** (student-facing specs, optionless MCQs, OCR artifacts, junk titles,
board misuse). Best single paper: TS_X at 40% — the closest any scope gets to a full paper.

---

## What was done (checkpoints, each tested + committed)

- **CP0 — safety.** Full KIE backup (`kie.db.pre-ingest-*`, gitignored); corpus hash `1da7a5b4`;
  baseline 1415 active concepts / 21 definitions recorded.
- **CP1 — governed ingestion (Intake Center, all gates).** Imported CBSE/NCERT Class-X **Science
  (13 chapters)** + Telangana Class-X **Physical Science, Biological Science, Mathematics**.
  Governance held: **NCERT Class-X Mathematics is encrypted → all chapters quarantined** (honest —
  CBSE Math X is not ingestable), one science chapter failed parse. 18 docs promoted additively
  (baseline immutable); provenance + Class-10 attribution verified.
- **CP2 — derived knowledge + definition-first extraction.** Corpus 1415 → 1852 active concepts
  (+437), +8271 chunks. Base cleanup + `concept_quality` rejected the new noise. The concept
  extractor yields *heading-level* concepts while definitions are *term-level*, so the standard
  miner found ~0; new `kie/curate/board_definitions.py` does **definition-first** extraction over
  the clean (words-mode) board text → **+26 grounded verbatim definitions** (21 → 47). Grade/exam
  isolation verified.
- **CP3 — board profiles.** Real `CBSE_X` and `TS_X` exam profiles (grade-10, board-source-isolated)
  + aliases; the board guard now serves a Class-X board blueprint ONLY under its certified board
  profile (`CERTIFIED_BOARD_PROFILES = {CBSE_X, TS_X}`); AP and any FOUNDATION-routed board request
  fail closed. Board scopes now generate.
- **CP4 — grounded definition-match MCQ.** `materialize.py`: an MCQ slot whose concept has a
  grounded definition becomes "Which of the following is best described as: '<definition, answer
  name removed>'?" — concept = single correct answer, distractors = distinct clean sibling concepts
  (same subject/chapter). Fails closed unless 4 distinct options / one correct / ≥3 valid siblings;
  rejects synonym and OCR-merged distractors. No fabrication; re-checked by the validation gate.
- **CP5 — re-certification.** Metrics above.

---

## Why the target is still not met (measured root causes)

1. **Definition yield from the available board PDFs is low (21 → 47).** The PDFs are OCR-noisy
   (~9% of chunks carry merged words; definitional sentences are disproportionately garbled or
   phrase the concept as an object), so precision-first extraction — which refuses to emit a garbled
   answer — recovers only ~26 clean definitions. Descriptive fill is capped by this.
2. **Selection is not fill-aware** (frozen `select.py`): it picks by exam-importance, so it mostly
   selects definition-less concepts even when defined ones exist, sending them to the worklist.
3. **CBSE Math X is unavailable** (encrypted source, correctly quarantined).

Net: a board paper fills only where a selected concept happens to have a grounded definition (→ key
+ definition-match MCQ). That is real but sparse — TS_X 40%, CBSE_X 15% — never a full paper.

---

## Remaining levers to reach full teacher-ready papers (measured, honest)

1. **More/cleaner definitions** — the dominant lever. Either better source text (clean digital
   NCERT/board textbooks, or higher-quality OCR/`pymupdf_layout` re-parse) or more board subjects.
   Definition coverage is the direct multiplier on both descriptive keys AND definition-match MCQs.
2. **Fill-aware selection** — steer objective/descriptive slots toward concepts that have a
   template or a grounded definition, so a board paper fills fully instead of scattering onto
   definition-less concepts. This is an engine-selection change (out of this round's scope).
3. **Un-encrypt / re-source CBSE Math X** to enable CBSE Math papers.

The two engine capabilities added this round (board profiles, definition-match MCQ) are the correct
infrastructure and **scale automatically as definition coverage grows** — they are not the bottleneck.

---

## Governance & isolation

Intake Center gates enforced (verify → certify → dedup → version → review → additive promote);
encrypted/unparseable files quarantined, never forced. Baseline immutable (additive only). Grade/
exam/subject isolation verified (0 Class-10 leak into NEET/JEE). AP support **not claimed** — no
verified AP source ingested → fails closed. No definitions, answers, distractors, or mappings were
fabricated. Full KIE suite green throughout.

---

## Bottom line

Executed all authorized work — governed ingestion of CBSE/NCERT + TS Class-X, definition-first
extraction, board profiles, and grounded definition-match MCQs — and measured the result honestly:
definition coverage more than doubled, printed positions +64%, board scopes now produce real Class-X
papers (TS_X 40%), integrity gates all 0, isolation verified. **But full teacher-ready papers remain
0**, because the available board PDFs yield too few clean deterministic definitions and selection is
not fill-aware. Completion is **not declared**. The next lever is definition coverage (better source
text) + fill-aware selection — the added engine capabilities scale with it. Engine deterministic
pipeline unchanged in shape; AI OFF; nothing fabricated.
