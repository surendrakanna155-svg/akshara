# KIE Content Density — OCR Recovery + Fill-Aware Selection (Phase 1–2)

**Date:** 2026-07-11
**Scope:** Owner-authorized final levers: (1) recover cleaner source text / better extraction; (2)
fill-aware selection. Engine deterministic pipeline preserved except a documented, regression-locked
selection exception. AI OFF; no fabrication; AP unsupported until real AP corpus exists.
**Branch:** `feature/qp-content-readiness`. Full KIE suite green.

---

## Honest bottom line

**Full teacher-ready papers (100% of the intended blueprint): still 0 of 54.** The best paper is
now **96%** (foundation_mixed, 25/26 — one MCQ short); 6 papers reach ≥90% and 9 reach ≥50%, up
from 0/3/6. Printed deterministic positions rose **74 → 357** across the program; all integrity
gates are 0. But no paper is fully complete, because clean grounded definitions are capped at **47**
(OCR/source-limited) and objective sections need MCQ-fillable concepts that compete with the
descriptive sections for those same definitions. **The exit target is not met; this is measured,
not declared.** (An earlier "3 full TS_X papers" was a *surviving-slot* artifact — corrected here to
measure against the INTENDED blueprint, which counts a dropped section as missing.)

---

## Requested metrics (same 57-paper AI-OFF matrix; honest intended-blueprint denominator)

| Metric | Result |
|---|---|
| **Full teacher-ready papers (100%)** | **0 / 54** |
| Papers ≥90% filled | **6** (foundation_mixed ×3 @96%, foundation_desc ×3 @92%) |
| Papers ≥50% filled | **9** |
| Blueprint fill rate | **21.0%** (357 printed / intended) |
| **TS_X fill rate** | **60%** (45/75) — Part A descriptive 100%, Part B objective 0% (definitions consumed by Part A) |
| **CBSE_X fill rate** | **15.4%** (18/117) — NCERT-Science chapters have no templates + few defs |
| Objective fill rate | **14.1%** |
| Descriptive coverage | **100%** of printed descriptive carry a real grounded key (0 placeholders) |
| Grounded definition count | **47** (baseline 21) |
| Chapter diversity (printed) | **18 distinct chapters** |
| Concept diversity (printed) | **66 distinct concepts** (18.5% of printed slots) |
| Repetition across papers | max single concept reused in **21 / 54** papers (small fillable pool) |
| Bloom relaxation (printed) | met **84%**; 57 relaxed (honestly labelled + noted) |
| Difficulty relaxation (printed) | met **58%**; 150 relaxed (honestly labelled + noted) |
| Isolation / integrity gates | **all 0** — student-facing specs, optionless MCQ, OCR artifacts, junk titles, board misuse; AP fails closed |

---

## Phase 1 — Source text / OCR recovery (empirical, no code change)

Audited the ingested CBSE/NCERT + TS Class-X sources and compared local extraction methods on them —
**by measurement, not appearance**:

| Method | def-first yield | corruption rate | avg word len |
|---|---|---|---|
| pymupdf `text` (pipeline default) | 20 | 0.4% | 4.57 |
| **pymupdf `words` (used by the extractor)** | **20** | **0.4%** | **4.57** |
| pdfplumber | 11 | 15.3% | 5.75 (worse spacing) |

`pymupdf_layout` / `pdftotext` are not installed. **words-mode is already optimal**; pdfplumber is
worse. Broadening the definitional patterns (colon "Term: …", "X is called Y", "X means …") was
tested and **rejected** — the colon pattern yields 161 pairs that are ~**95% garbage** ("Material
required is A candle, paper…"), a false-positive rate that violates "never invent". **Conclusion:
extraction quality is not the bottleneck — definition yield is genuinely capped (~47) by the source
content, and re-running governed extraction confirms it (no gain available).**

## Phase 2 — Fill-aware selection (documented, narrowly-scoped exception)

**Proven need:** full papers were 0 while fillable concepts existed but weren't being selected.
**Change:** `engine._fillable_map` computes, per candidate, the deterministic fill strength it can
actually materialize AS-IS (0 solver-verified template · 1 grounded definition — descriptive key or
definition-match MCQ · absent = unfillable). `select._priority` uses it as the **primary** key, with
subject → chapter → seed balancing **among fillable content** so completeness rises without weakening
diversity, isolation, bloom/difficulty (bucket applied upstream), seed determinism, or cross-paper
uniqueness. Backward compatible (no map ⇒ identical prior behaviour).

**Independent re-audit of the changed behaviour:** distinct printed concepts 64 → 66 and distinct
chapters (18) held steady while completeness rose (TS_X 40%→100%-of-Part-A, NEET Physics objective
0%→47%) — diversity preserved. 6 fill-aware regression tests (preference, subject-balance-among-
fillable, chapter diversity, determinism, cross-paper uniqueness, backward-compat).

---

## Why full papers are still 0 (measured root cause)

The two levers extracted the maximum available value, but the wall is arithmetic:
- **47 grounded definitions total**, subject-skewed (Bio 11+board, Chem 8+board, Phys 3, Math 2),
  plus ~40 computable templates. A blueprint needs both descriptive keys AND objective items, and
  **each concept is used once per paper (dedup)** — so descriptive and objective sections compete
  for the same ~47 definitions. TS_X (18 defs, 25-question blueprint) fills Part A (15) fully but
  leaves Part B (10 MCQ) empty → 60%, not 100%.
- The best papers (foundation_mixed 96%, foundation_desc 92%) are **one question short** — a single
  slot in a type/subject/chapter bucket with no remaining fillable concept.

Full papers require **more clean definitions** (the multiplier on both key types) — which needs
better source content, not better extraction (already optimal) or smarter selection (already
fill-first). Extraction and selection are no longer the bottleneck; **definition count is.**

---

## Remaining path to full papers (honest)

1. **More clean grounded definitions** — the only real lever now. Clean digital NCERT/board
   textbooks (not OCR-noisy PDFs), or more board subjects/chapters. Each definition feeds a
   descriptive key AND a definition-match MCQ, so it compounds.
2. **Un-encrypt / re-source CBSE Math X** (currently encrypted → CBSE Math unavailable).
3. Optionally, blueprints whose section mix matches the available fillable-by-type distribution.

All the machinery (board profiles, definition-first extraction, definition-match MCQ, fill-aware
selection) is in place and **scales automatically with definition count** — it is not the limiter.

---

## Governance & integrity

Intake gates enforced throughout; no fabrication of definitions, distractors, or mappings; grade/
board/subject isolation verified (0 Class-10 leak into NEET/JEE); AP fails closed (no corpus). The
one frozen-engine selection exception is documented, regression-tested, and independently re-audited.
Completeness is now measured against the intended blueprint (dropped sections count as missing), so
the reported numbers are honest.

## Bottom line

OCR recovery found no available improvement (words-mode already optimal; broadening rejected as
~95% false-positive), and fill-aware selection lifted near-complete papers to **96%** (best) with
**6 papers ≥90%** — a real jump from 0 — while preserving diversity, isolation, and all integrity
gates. **But 0 papers are fully complete**, because clean grounded definitions are capped at 47 and
descriptive/objective sections compete for them. The exit target is **not met**; the sole remaining
lever is more clean source definitions (a data problem), and every engine capability to exploit them
is already built and measured.
