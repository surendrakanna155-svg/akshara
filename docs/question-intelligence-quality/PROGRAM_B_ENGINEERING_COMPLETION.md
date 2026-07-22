# Program B — PYQ Re-attribution & Re-mining · Engineering Completion Checkpoint

**Date:** 2026-07-22 · **Branch:** `feature/program-b-pyq-remining` (local, NOT pushed) ·
**Implements:** roadmap **R5-4** (measured Exam DNA v2) · **Predecessor:** QIE/QDI Remediation (FROZEN, `42c93454`).
**Status:** 🏁 **ENGINEERING COMPLETE — all six milestones (B1–B6) + the parallel OCR Recovery Lane implemented,
independently adversarially verified, EOS-gated, and committed.** Written to the Honest-Null principle: where a
result is honest-null, the reason is stated explicitly. Per-item evidence lives in
[`PROGRAM_B_EXECUTION_LOG.md`](PROGRAM_B_EXECUTION_LOG.md); the plan (SSOT) is
[`PROGRAM_B_PYQ_REMINING_ENGINEERING_PLAN.md`](PROGRAM_B_PYQ_REMINING_ENGINEERING_PLAN.md).

---

## 1. What was built (all committed on `feature/program-b-pyq-remining`)

| Milestone | Deliverable | Verification | Commit |
|---|---|---|---|
| **B0** | Owner-approved plan + execution log; clean 1109 baseline | — | `0117e2bd` |
| **B1** | Corpus role classification `pyq_source_class` (fail-closed exam/year/authority) | 2 rounds · EOS PASS | `130708de` |
| **B2** | Subject attribution `pyq_chunk_subject` (OD-4) + subject-scoped concept resolver (D3 fix) | 2 rounds · EOS PASS | `c8f22304` |
| **B3** | Question re-mining `pyq_item` (provenance chain OD-2) — 15,803 instances | 3 rounds · EOS COND. PASS | `b3943a98` |
| **B4** | Structural difficulty (OD-3) + marking-scheme (OD-6) | CONFIRMED · EOS PASS | `17d11df0` |
| **B5** | Measured Exam DNA v2 `exam_dna_v2` (R5-4) | CONFIRMED + P2 fix · EOS PASS | `9a2bbef4` |
| **B6** | DNA v2 consumer contract `dna_access` (provenance + fail-closed gate) | EOS PASS | `9a2bbef4` |
| **OCR** | OCR Recovery Lane (parallel, non-blocking) `kie/qie/ocr_recovery/` | REFUTED→fixed · EOS PASS | `822d95cf` |

Engine: `curriculum/scripts/intelligence/kie/qie/pyq/` (+ `…/ocr_recovery/`). Derived stores (gitignored):
`pyq_corpus.db`, `ocr_recovery.db`. **Every substantive milestone ran an independent adversarial verifier; six
returned REFUTED and each found a REAL defect** (B3's phantom flood, B3's option-bleed instruction survivors, the
OCR lane's inverted fabrication gate, B5's doc-vs-sitting independence inflation, …) — all fixed + regression-
locked. Full KIE suite **1109 → 1238 green**; frozen `kie.db` + `knowledge_index.db` + `examdna.db` v1 **MD5
byte-identical** throughout.

## 2. The two original defects — fixed

- **D5 (folder-trust):** the ingester set `exam` = the top path folder, so 861 docs read `exam='Cursor_Downloads'`.
  B1 reconstructs identity from the FULL path + content, fail-closed (a folder token never assigns an exam) —
  **recovering** the mislabelled `jeeadv.ac.in` official archive. D5 regression = 0.
- **D3 (mislabelled concept prefixes, `BIO_MOTION`):** B2 attributes subject from the document FIRST, then resolves
  the concept **within that subject** (the prefix is never consulted). Independently measured: the prefix disagrees
  with the frozen index on 51.7% of checkable codes.

## 3. The headline result — honest measured Exam DNA v2

**The owned corpus cannot honestly support a measured exam-DNA — and the program says so rather than fabricating
one.** Under OD-5's **"30 independent PYQs"**, the independence unit is a distinct exam **sitting** (a year), not a
booklet/shift PDF. The corpus holds only **~10–14 sittings per exam** (NEET 10, JEE Advanced 14, JEE Main 6) — well
below 30 — so **every measured distribution (question-type, structural difficulty) is `insufficient_evidence`
(honest-null)**. v2 publishes only the **`published`** mandated subject weights (NEET 25/25/50, JEE thirds);
measured student difficulty is honest-null pending pilot data (R5-5).

This is a precise **measurement of the evidence gap**, not a machinery failure. The pipeline is proven correct
(per-sitting-normalized, deterministic, floor-gated, v1-safe) and **scalable (OD-8): it will emit measured DNA the
moment ≥30 independent sittings exist.** B6's `assert_exam_representative()` is the fail-closed enforcement point —
on this corpus it refuses every exam-representative claim, and will allow one only when a dimension is genuinely
measured.

## 4. What the program DID produce (real, honest engineering value)

- A **provenance-linked question corpus** — 15,803 question instances, each reconstructable Question→Chunk→Doc→
  Exam→Year→Subject (OD-2), phantom-free (instructions/notices/lists/garble rejected), spans capped, 0 false-merge.
- **Corrected attribution** (D3/D5 fixed) + honest-null everywhere unreconstructable.
- The **measured-DNA machinery** + the **N≥30 independent-sitting floor** + the **published/parsed/honest-null
  marking schemes** (NEET +4/−1 parsed, JEE variable → honest-null).
- The **consumer contract** that surfaces `provenance_class` and gates exam-representative claims on v2.
- A parallel, deterministic **OCR Recovery Lane** that proposes verified OCR improvements (never auto-applied;
  frozen substrate untouched) to lift the corpus-quality floor over time.

## 5. Standing-law compliance (held to the last commit)

Honest-Null / never-guess · never fabricate metadata (measured DNA is insufficient_evidence, not invented) · no
certification gate weakened · provenance preserved (content-addressed, RI-2 style) · freeze-as-versioning
(`kie.db`/`index`/`examdna` v1 byte-identical; v2 is additive + versioned, OD-6) · deterministic · every
implementation independently adversarially verified (OD-7).

## 6. Owner-gated / external next steps (nothing here is cleanly buildable now)

1. **Acquire ≥30 independent sittings per exam** (evidence acquisition, not engineering — OD-8) → the measured DNA
   machinery then produces `pyq_measured` distributions automatically.
2. **OCR Recovery Lane — full batch** over the ~149 candidates + `-l eng+hin` for bilingual papers; then the
   **gated, version-bumped re-integration** of verified improvements into a new frozen index (owner + freeze-hatch).
3. **B3 residual (~0.1%, tracked):** a handful of JEE-Advanced option-only OCR fragments; diluted by B5's per-doc
   normalization, further reducible after OCR recovery.
4. **Live product path** stays gated on Program C (live key) + R5-3 (ERP promotion) — Program B produces a
   *measurement layer*, not student-facing questions.

## 7. EOS gate — Program B

**`EOS gate: CONDITIONAL PASS`** — all buildable scope implemented + independently verified + honest; the measured
DNA is honestly `insufficient_evidence` (an evidence gap, correctly reported, not a defect); B3's ~0.1% residual is
tracked; the OCR full batch + re-integration + evidence acquisition are owner/external-gated. No open P0.

**Engineering-complete boundary reached. Branch frozen at the certified engineering baseline (`9a2bbef4`); NOT
pushed (awaiting explicit owner acceptance + push authorization). The next steps are owner/external-gated.**
