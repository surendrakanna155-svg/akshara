# Root Cause Investigation — QDI source subject/exam indexing defect

**Date:** 2026-07-20 · **Trigger:** QDI mining analysts reported that JEE-Physics requests returned NEET
Biology content. **Method:** traced the full pipeline (owned docs → chunking → metadata → subject
classification → source_documents → `exam_sources()` → `candidate_chunks()` → QDI mining), proved the root
cause with code + data evidence, then implemented and validated the correct architectural fix. **No temporary
patches.**

---

## 1. Symptom

`exam_sources(subject="Physics", exams=("JEE_Main",))` returned **126 documents; the top 8 were all
`category='NEET'`** (NEET 2021 previous papers). The mining analysts, reading the resulting chunks, found
Biology questions + ~50% OCR boilerplate under a "JEE Physics" request, and correctly refused to fabricate.

## 2. Pipeline trace with evidence

| Stage | Finding | Evidence |
|---|---|---|
| Owned docs → source_documents | exam identity is reliable (`category`/`exam` per doc) | NEET docs have `category='NEET', exam='NEET'`; 74 genuine `category='JEE_Main'` docs exist |
| Chunking | OK — chunks preserve order + structure | `chunks` has `ordinal, section_path, page_start/end` |
| Metadata → **Subject classification** | **ROOT DEFECT** | `phase3_metadata.py:295` `subject = infer_subject(whole_doc_text)` — a whole-document term-frequency classifier assigns **ONE** subject per document. But NEET/JEE papers are **combined P+C+B/Maths in one PDF**. Result: NEET combined papers scattered as **68 "Physics" / 47 "Chemistry" / 17 "Biology" / 20 None**, each force-labeled one subject by whichever section's OCR terms scored highest |
| `exam_sources()` selection | **PROXIMATE DEFECT** | `WHERE (category IN (exams) OR rel_path LIKE '%Question_Bank%' OR rel_path LIKE '%Previous_Papers%')` — the exam restriction is **OR'd** with the path patterns, so **any** Previous_Papers doc passes regardless of exam. A JEE request matched NEET docs via `path~Previous_Papers`, then the `subject='Physics'` clause matched the mis-tagged NEET paper |
| `candidate_chunks()` | **ENABLING DEFECT** | joins chunks to the **doc-level** `subject`; no per-chunk subject → for a combined paper, hands back a P+C+B+boilerplate mix |
| OCR | Contributing | bilingual Hindi/English papers → heavy Devanagari mojibake (~half the chunks are instruction furniture) |

**Where JEE-Physics → NEET-Biology happens (proven):** the OR-bypass returns NEET combined papers for a JEE
request; those papers carry a single artifact subject tag; `candidate_chunks` cannot isolate a subject within a
combined paper, so it surfaces the (Biology-dominant) mix.

**Proven recoverable:** chunks carry ordered **section-subject markers** — the sample NEET paper has 32 in
order (`Physics@ord4,27 → Chemistry@43,59 → Biology@75… → Physics@153…`). Subject is fully recoverable at the
section level.

## 3. Root cause (architectural)

**Subject was modeled at DOCUMENT granularity (a whole-document frequency guess), while the source reality is
COMBINED multi-subject exam papers.** Exam is correctly a document property; **subject is a SECTION property**.
Two concrete defects flowed from this: the `exam_sources` OR-bypass (proximate) and the doc-level single-subject
tag with no chunk-level resolution (root).

## 4. Correct fix (implemented, not a patch)

Implemented in the QDI read layer (`kie/qie/knowledge/qdi.py`) — **non-destructive** to the frozen `kie.db`
intake (the doc-level tag is simply no longer trusted for combined papers):

1. **`exam_sources()`** now matches the **exam identity** (`category IN (exams) OR exam IN (exams)`) — the
   Previous_Papers/Question_Bank path-bypass is removed, and the unreliable doc-level `subject` is no longer a
   document filter.
2. **`resolve_chunk_subjects()`** (new): walks a paper's chunks in `ordinal` order and propagates the
   most-recent in-paper section-subject marker to each chunk (`Physics/Chemistry/Botany→Biology/Zoology→Biology/
   Mathematics`). Chunks before the first marker stay `None` (never guessed).
3. **`candidate_chunks(subject=…)`** now keeps only chunks whose **resolved** section-subject matches, and drops
   exam-instruction boilerplate + OCR mojibake (`_usable_chunk`: min length, no boilerplate phrases, ≥30% Latin
   alphanumerics).

## 5. Validation (evidence)

- **Exam isolation:** `exam_sources(JEE_Main)` → 74 docs, **0 NEET leaked**; `exam_sources(NEET)` → 151 docs,
  **0 JEE leaked**.
- **Per-subject resolution** on the combined NEET paper: chunks resolve Physics 160 / Chemistry 132 /
  Biology 411 / None 4; `candidate_chunks(subject=…)` returns the correct content — Physics → an AC-capacitor /
  dimensional-formula item; Chemistry → methyl-halide ordering & redox reactions; Biology → a biofortification
  item. **No cross-subject leak.** Boilerplate/mojibake excluded.
- **Regression test:** `tests/test_qpl_source_indexing.py` (synthetic combined paper shaped like the real
  defect) locks exam-identity matching, section-subject propagation, subject-filtered chunk selection, and
  boilerplate/mojibake rejection. **758 tests green.**

## 6. Residual / recommended follow-ups (owner-visible, not blocking)

- **CORRECTION (R1-3, 2026-07-21):** the earlier claim here that "the 7 already-certified JEE-Main Math QDI
  patterns are unaffected (pure-math, not subject-mined here)" was **FALSE** and is retracted. All 7 were
  mined at 19:35 on 2026-07-20 (commit `7da9a829`), **before** this fix landed at 20:44 (`8fb31ac7`), and are
  **irreproducible** under the corrected `exam_sources()`: **5** rest solely on `Practice_Resources` docs
  (canonical `exam='Practice_Resources'`, not `JEE_Main`) and **2** (`QDP_57333bb83da55b`,
  `QDP_e3842c9a9d9c70`) rest solely on `JEE_Advanced 2023 Paper 2` **physics** chunks
  (`cef4c09da7aeebaa#8/#9`: electric dipole, Young's modulus, Bohr-orbit comparison) that the doc-level
  subject tag mis-labelled "Mathematics" — the exact whole-document mis-tag this RCA documents. Every one of
  the 7 carries a **false canonical exam identity** (all stored `exam='JEE_Main'`, none evidenced by a
  `JEE_Main` doc); the 2 physics patterns additionally violate the ≥5-item/≥2-resource evidence floor
  (`evidence_count=1`, a single resource) and one injected a physics `expected_solving_path` into the
  certified set-theory spec `QBP_8061e8a12761a23e` ("The Empty Set"). Under R1-3 the deterministic provenance
  invariant + evidence floor + fail-closed floor now **recall/refuse all 7** (they can no longer reach
  `certified`); re-derivation must run through the fixed exam-identity + provenance-invariant pipeline. The
  live rows themselves stay flagged pending the owner-gated quarantine decision (R0-2). **Standing rule
  (adopted): fix-forward without recalling the affected certified artifacts is prohibited** — an RCA fix must
  also recall every artifact produced under the defect, not merely correct the code path going forward.
- The **frozen `kie.db` intake** still stores the doc-level single-subject artifact. Correcting it *at ingest*
  (mark combined papers multi-subject + segment sections) would be an **intake v-next** (a separate, larger,
  versioned effort); the read-layer resolution above makes mining correct now without a risky mutation of the
  frozen baseline.
- OCR quality on bilingual papers remains a ceiling on qualitative mining yield (re-OCR is a separate effort).

**Verdict:** root cause proven; correct architectural fix implemented and validated; the JEE-Physics → NEET-
Biology leak is closed. Subject-scoped QDI mining is now sound **for NEW mining**; pre-fix certified artifacts
(the 7 patterns above) required RECALL, not merely a forward fix — see §6 correction. Track B generation may
resume only once the R1-3 provenance/evidence gates (implemented) are in place AND the 7 are recalled.
