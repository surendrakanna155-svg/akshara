# JEE multi-step Physics/Chemistry — evidence-quality check (read-only)

**Date:** 2026-07-13 · **Verdict: EVIDENCE-BLOCKED.** A read-only audit of the raw corpus (`kie.db`, read-only)
behind the depth-profiler's "JEE_MAIN multi-quantity" count. No build; no writes; no acquisition. This is the
viability gate for a JEE multi-step numeric generator — and it fails on evidence, honestly.

## Method
The depth profiler classified items as JEE_MAIN multi-step when they had ≥4 distinct numeric givens and no
single-relation solution (Physics 511 / Chemistry 391). That count was computed over **numeric-token density in
text** — never checked against whether the text is a real, self-contained, solvable JEE problem. So I went to
the source: `chunks` (42,141 OCR'd text chunks), took the question-like chunks (has `?` or a solve-verb) with
≥4 distinct numbers (**2,741**), and classified what they actually are.

## What the "multi-quantity" evidence actually is

| Bucket | Count | % | What it is |
|---|---|---|---|
| **NTA response-sheet OCR shells** | 1,097 | **40%** | The genuine JEE question body was a **rasterized image** on the NTA candidate-response PDF. OCR captured only `A B C D / Answer Given By Candidate / Question ID / Topic Name` — **the question stem does not exist as text.** |
| **Textbook prose** | 444 | 16% | NCERT reprint/figure/activity exposition ("So far we have learnt…", "Draw two triangles…") — not exam questions. |
| **Clean-solvable heuristic pass** | 68 | **2%** | And on inspection these are mostly **school-board** geometry/probability/optics word problems (sphere-in-cylinder, shop-visit probability, lens power), not JEE multi-step numerics — several with visible OCR corruption of formulae. |

## Conclusion
- **The JEE multi-step Physics/Chemistry modality is evidence-blocked.** The real JEE question stems were images
  that were never OCR'd into usable text; the clean numeric problems that remain are school-board word problems,
  not JEE-profile. There is **no reliable structured (givens → relations → answer) substrate** to generate from
  or verify against.
- **The depth-profiler figure (Phy 511 / Chem 391 JEE_MAIN multi-step) is a numeric-token-density artifact** and
  must be read as an *upper bound on candidates*, not a count of usable items. The item-level **profiling** is
  still correct (calculus→JEE_MAIN etc.); only the *multi-step numeric* sub-count was optimistic.
- Unblocking multi-step would require **acquiring/OCR-ing genuine JEE question text** — an **acquisition** task,
  which is on owner HOLD. Not attempted.

## What this leaves as the genuinely-unblocked JEE lane
**Synthesized, deterministically-verifiable JEE-Math** — the only JEE lane that does not depend on the un-OCR'd
corpus. Calculus is built (9 families, 221 verified items); it extends cleanly to definite integrals, limits,
sequences/series, matrices/determinants, complex numbers — each generatable and checkable by an independent
deterministic operation, corpus-free. That is the recommended continued direction; multi-step waits on
acquisition (owner decision).
