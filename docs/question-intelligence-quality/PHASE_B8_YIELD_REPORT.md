# Phase B8 — Biology Evidence Depth + Mathematics Structure Resolution: Final Yield

**Date:** 2026-07-12 · **Status:** DONE; **retained gate 2/4 — Biology & Mathematics FAIL** → STOP. Physics &
Chemistry frozen (untouched). Two disjoint blocker-resolution tracks run, tested, audited, committed. Engine
frozen (`qpgen` byte-identical); `kie.db` untouched (read-only + scratch `qie.db` copy); qcorpus read-only; no
threshold / confidence gate / support requirement / verification rule weakened; AI OFF (no new judge passes —
existing 48 cached Tier-2 verdicts + deterministic KVS only); A5 seam inert. **434 tests green.** Evidence:
`phase0_evidence/yield_gate_B8_final.json`.

## Retained verification-backed yield gate (unchanged thresholds; ≥8 verified models/subject)

| Subject | Verified models | Gate | Determination |
|---|---|---|---|
| **Physics** | **20** | ✅ | cleared (frozen this round) |
| **Chemistry** | **12** | ✅ | cleared (frozen this round) |
| **Biology** | **1** | ❌ | hard **corpus-depth** ceiling — not extraction, not resolution |
| **Mathematics** | **6** | ❌ | the 6 are **false relation-matches**; genuine topic-consistent = **0** |

**2/4.** Same result as B7, now with the *cause* pinned by a built-and-measured recovery path (Biology) and by
a Math structure model that exposes the Math count as inflated.

---

## TRACK 1 — Biology evidence depth

**Audit (measured, not assumed).** Biology loss is **NOT** bulk extraction loss. Of 1,798 Biology questions in
the qcorpus manifest, the base adapter already recovers **1,611 (90%)** as text-verifiable MCQs. The stranded
band is thin and precisely characterised:
- **44** answer-associated, non-visual MCQs dropped by an **OCR option-glue** defect — a sibling option's text
  is merged onto another option's line (`{'a':'foo (b) bar','c':..,'d':..}`), so the answer label parses empty;
- **33** answer-associated **visual-dependent** MCQs (diagram-locked);
- the rest are genuinely empty (no option text present).

**Build — smallest governed recovery path** (`qie/doc_recover.py`, deterministic, read-only on manifests):
- **Option de-glue**: splits embedded `(x)` markers back into their own labels — recovers question STRUCTURE
  from existing verified sources, no re-parse of the PDF, no image answer-inference, source-associated
  `answer_ref` only, no fabrication. Yields **only the delta** the base adapter drops (never double-counts).
  Recovered: **+14 Biology, +30 Chemistry, +14 Physics** genuinely-broken MCQs.
- **Visual-dependent items** are surfaced through a *separate* generator that **never** enters text
  verification (a diagram-locked answer is not text-verifiable — honest, per "do not infer answers from
  images").

**Measure — fed through the UNCHANGED strict resolver + KVS + Tier-2:** Biology verified models stay **1**.
The recovered evidence does not create new qualifying concepts. **Definitive structural ceiling (measured):**
even with de-glue, **only 4** resolved Biology concepts reach the (unweakened) ≥5-DNA / ≥2-doc bar —
`BIO_CUTTING` (14/14), `BIO_MITOCHONDRIA` (12/12), `BIO_PROTEINS` (8/8), `BRD_PHY_ce26529e8f59` (5/5); the next
candidate `BIO_DEVELOPMENT` sits at 4/4. The gate needs **8 verified**. The blocker is a hard **corpus-depth
ceiling**: strict resolution correctly fragments the coarse buckets into many small canonical concepts, and
the corpus simply does not contain ≥5 questions from ≥2 independent docs for ≥8 *distinct* Biology concepts.
Extraction recovery cannot manufacture that depth.

## TRACK 2 — Mathematics structure resolution

**Audit — and the key finding: the retained gate's Math=6 was INFLATED.** `guess_subject` mis-attributes
Physics/Chemistry items to Mathematics; those items carry 4–5 OCR-parsed numbers; the permutation search in
`relations.verify` then finds *some* school formula that reproduces the stated answer within 2% **by
coincidence**. Confirmed on the real corpus — every one of the 6 "verified" Math models is a false match:
- `area_rect` (37): *"two equi-convex lenses"*, *"two heaters 1 kW and 2 kW"* → 1×2 = 2;
- `area_trap` (22): *"light travels distance x in air and 10x in a denser medium"* → 0.5·(1+10)·2 = 11;
- `ap_sum` (17): *"metallic bar of Young's modulus 0.5×10¹¹"* → a garbage OCR magnitude hits 50000;
- `mean2` / `sum_n`: physics wire/disc problems; `area_tri`: calculus integrands whose coefficients fit ½·a·b.

**Build — Math-appropriate deterministic structure model** (`qie/math_structure.py`), the Math analogue of the
Biology resolver but **structure-first** (Math answers are numbers, not concept names):
- resolves a **topic signature** (geometry-area/perimeter/volume, sequence-AP/GP, statistics-mean, interest,
  probability, algebra-roots, right-triangle) with a **hard science veto** and a **section-heading / OCR-noise
  veto** — so mis-attributed science and headings resolve to *unresolved*, not a spurious topic;
- verifies with the **independent relation solver** — single-step, plus a **guarded 2-step chain** (linear/
  product allowlist, consume-all-numbers, stricter 0.5% tolerance) so multi-step cannot brute-force a target;
- accepts a match **only when the relation's family matches the resolved topic** (the false-match killer: an
  optics item cannot count as a trapezium area even though the numbers fit);
- normalises **algebraically-equivalent** forms (a·b, a·b·c) to one schema; **returns None when uncertain**.
- Verification strength is **UNCHANGED** (same library, same 2% single-step tolerance); this adds *precision*
  only — it never lowers a bar (multi-step is *stricter*).

**Measure — apply the unchanged gate to the genuine-math-resolved evidence:** of **132** raw single-step
"matches", **all 132 are rejected as false**; only **4** items in the whole corpus carry a confident math
topic; **genuine topic-consistent verified Math models = 0** (0 multi-step). Root cause: the corpus is
**JEE/NEET foundation (calculus-heavy)** while the relation library is school arithmetic/geometry — a
fundamental content mismatch. There is not a single clean "area of a rectangle" / "sum of an AP" school
problem with a correct relation match. Genuine deterministically-verifiable Math = **0** (< 8, FAIL) — and the
prior 6 was not real.

---

## Honest determination

**Can the existing verified corpus support 4/4 under unchanged quality standards? No.**
- **Physics (20) ✅, Chemistry (12) ✅** — cleared, frozen this round.
- **Biology ❌** — hard corpus-depth ceiling: max **4** resolved concepts reach ≥5/≥2; need 8. Resolution and
  Tier-2 verification are proven; the per-concept evidence density is not there and extraction recovery
  (built and measured) cannot create it.
- **Mathematics ❌** — the retained 6 are coincidental false matches; the genuine deterministically-verifiable
  count is **0**. The corpus is calculus-heavy JEE/NEET; the school relation library cannot verify it.

The two capabilities are real, tested engineering (option-glue recovery recovered 58 broken MCQs across
subjects; the Math structure model correctly rejects 132/132 false matches). They did not — and honestly
could not — force the gate to 4/4. **No scaling, no production generation, A5 inert, AI OFF.** Teacher
validation remains mandatory before any market/quality claim. Holding at **2/4** for owner direction.
