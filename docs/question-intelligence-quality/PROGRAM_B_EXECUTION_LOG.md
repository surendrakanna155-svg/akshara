# Program B — PYQ Re-attribution & Re-mining · Execution Log

**Program:** B (PYQ Re-attribution & Re-mining) · implements roadmap **R5-4** (measured Exam DNA v2).
**Branch:** `feature/program-b-pyq-remining` (new, off the frozen QIE baseline `bbee4803`; NOT pushed).
**Plan (SSOT):** [`PROGRAM_B_PYQ_REMINING_ENGINEERING_PLAN.md`](PROGRAM_B_PYQ_REMINING_ENGINEERING_PLAN.md).
**Predecessor:** QIE/QDI Remediation — COMPLETE, OWNER-ACCEPTED, FROZEN (`42c93454`). Treated as immutable history.

This log is the running record of what has actually been implemented, verified, tested, certified, documented,
and committed — one section per milestone (B0…B6). It never re-plans (the plan is the SSOT).

---

## Owner authorization — plan ACCEPTED, implementation AUTHORIZED · 2026-07-22

The owner **accepted** the Program B Engineering Discovery and **approved the implementation plan**, confirming
the finding that the core issue is **provenance reconstruction**, not simple attribution cleanup. All eight owner
decisions are approved (with two concrete tightenings, recorded verbatim as binding):

| OD | Owner decision (binding) |
|---|---|
| **OD-1** | Process **only genuine PYQ papers**. DPP, mock tests, coaching sheets, practice material remain **separate datasets** (never mixed into exam DNA). |
| **OD-2** | Every certified pattern must maintain **deterministic provenance**: **Question → Chunk → Source Document → Exam → Year → Subject**. If provenance cannot be reconstructed → **Honest-Null**. |
| **OD-3** | Hybrid approved: implement **structural difficulty only**; **do not claim measured student difficulty**. Measured difficulty stays unavailable until sufficient learning evidence exists. |
| **OD-4** | **Subject is always determined from the source document BEFORE concept resolution.** Never derive subject from legacy prefixes. |
| **OD-5** | Minimum sample threshold = **30 independent PYQs**. Below that → report **"Insufficient Evidence."** Never fabricate statistics. |
| **OD-6** | Every mining pass creates a **new immutable version**. **Never mutate previously certified datasets.** |
| **OD-7** | Certification remains **deterministic**. Independent verification **mandatory**. **Model agreement may reject but never certify.** |
| **OD-8** | Proceed with the current owned corpus (**~188 PYQ docs**) as **Version 1**. The pipeline must remain **scalable** so future acquisitions incorporate **without redesign**. |

**Execution discipline (owner-mandated, per milestone B1→B6):** implementation · adversarial verification ·
regression tests · EOS gate · documentation · commit. **Stop only for a genuine owner decision or an external
dependency.**

**Engineering consequences locked in from the OD answers:**
- OD-2 ⇒ a `pyq_item` with no reconstructable Question→Chunk→Doc→Exam→Year→Subject chain **is not created** (or is
  written honest-null on the unreconstructable axis and excluded from measured weights). Provenance is a
  precondition, not an annotation.
- OD-5 ⇒ the small-sample floor is a **hard 30 independent PYQs** per measured cell; below → `insufficient_evidence`.
- OD-6 ⇒ examdna.db **v1 is never mutated**; because its `exam_weight`/`exam_distribution` PKs exclude `version`,
  the v2 measured layer is written to **new version-keyed tables in Program B's own derived store** (`pyq_corpus.db`),
  leaving v1 byte-identical.
- OD-1 ⇒ `dpp`/`mock`/practice are classified into a **separate dataset** and can never feed an `exam_dna_v2` weight.

---

## Baseline

- Branch created off `bbee4803`. Predecessor QIE branch left frozen (no commits added to it).
- Local test baseline: KIE suite established green before any Program B code (see B0).
- Frozen substrate opened **mode=ro** throughout; `kie.db` + `knowledge_index.db` asserted MD5 byte-identical.

---

## Progress ledger

Legend: ✅ done (committed) · 🔵 in progress · ⏸ owner-gated · ⏳ blocked (external) · ⬜ not started

| Milestone | Scope | State |
|---|---|---|
| **B0** | Owner approval recorded · execution log · plan committed · baseline established | ✅ `0117e2bd` |
| **B1** | Corpus role classification (`pyq_source_class`) — 225 genuine PYQ (NEET 105/JEE_MAIN 68/JEE_ADV 52) | ✅ verified (2 rounds) · EOS PASS |
| **B2** | Subject attribution (OD-4, `pyq_chunk_subject`) + subject-scoped concept resolver (D3 fix) | ✅ verified (2 rounds) · EOS PASS |
| **B3** | Question re-mining (`pyq_item`, provenance chain OD-2) — 15,803 instances / 108 docs | ✅ verified (3 rounds) · EOS CONDITIONAL PASS |
| **OCR** | OCR Recovery Lane (parallel, non-blocking) — deterministic re-OCR + verified-improvement gate | ✅ verified · EOS PASS · `822d95cf` |
| **B4** | Structural difficulty (OD-3, `structural_proxy`) + marking-scheme extraction (OD-6) | ✅ verified (CONFIRMED, P2 fixed) · EOS PASS |
| **B5** | `exam_dna_v2` measured layer — floor on INDEPENDENT SITTINGS; all exams insufficient_evidence (honest); v1 byte-identical | ✅ verified (CONFIRMED, P2 independence fix) · EOS PASS |
| **B6** | DNA v2 consumer contract — provenance surfaced + fail-closed exam-representative gate | ✅ EOS PASS |

---

<!-- Milestone entries are appended below as each is executed. -->

## B3 — Question re-mining with a deterministic provenance chain (OD-2) · 2026-07-22

**Scope:** re-mine individual questions from the eligible papers into `pyq_item`, each reconstructable end-to-end
(Question → Chunk → Source Document → Exam → Year → Subject), **without fabricating questions from OCR noise**.

**What landed** — `kie/qie/pyq/mining.py` (read-only over frozen kie.db; consumes B1 + B2):
- **OCR-robust marker** `_markers`: `32.A` (number-dot-Capital) or `Q.2`. Bare spaced numbers (`11 12 13 14` —
  OMR answer-grid bubbles) are **not** markers (no dot-capital) so they can never become questions.
- **Sequence validation** `_valid_runs`: markers are kept only where they extend a coherent increasing run; a
  backward jump or a large forward jump is dropped as noise. A doc with no coherent run yields **NO items**
  (honest-null, never guessed).
- **Full provenance** per item: `doc_id`, `exam`/`year` (from B1), `subject` (from B2's `pyq_chunk_subject` of the
  marker's chunk — honest-null if that chunk was null/boundary), `chunk_ids` + `chunk_sha256` (content-addressed,
  RI-2 style), content-addressed `item_id`. An item is created ONLY with this chain.
- **Question type** `_question_type` (assertion_reason / match / numerical / mcq / short_answer / unknown),
  specific types before mcq. **OCR fail-safe:** a near-prose-free span is `ocr_flagged` → type/concept honest-null
  (a mangled span never becomes a typed, concept-bearing question). **Conservative concept resolution:** only a
  certified concept name (≥2 words) present VERBATIM in the stem, resolved subject-scoped (B2) — else honest-null.

**Adversarial verification (independent, refute-first) — Round 1 → REFUTED (major, valuable).** The first
extractor ("any coherent increasing numbered run = questions") produced real **P0 phantom data**: exam
instructions, an NTA notice, a syllabus/experiment list, and physics variables (`Q1`,`Q2`,`x=0.The`) were stored
as questions; instruction bullets numbered `1..K` pushed the *real* questions (restarting at 1) out as backward
jumps; the last marker's span swallowed up to **349,560 chars** as one "question"; the two-space `1.␣␣Capital`
form was missed; and letter-DENSE Hindi garble passed the OCR fail-safe. **The extractor was redesigned around a
per-item question-STRUCTURE gate** (below) and the whole class of defects closed.

**What the redesign does** (`kie/qie/pyq/mining.py`):
- **Marker:** `Q.2` (dot REQUIRED — `Q1` variable rejected) or `12.` + ≤3 spaces + Capital/paren (catches the
  born-digital `1.␣␣At`), num≥1 (rejects `x=0.The`), not mid-word. Over-matching is fine — the gate decides.
- **The gate `_is_question`:** a marker's **bounded, capped** span (≤3000 chars — no tail-swallow) becomes a
  question ONLY if it is **readable** (mean-token-length + a ≥2 common-English-word check — rejects OCR garble
  and non-English papers), carries real **structure** (≥3 MCQ options, or numerical/assertion/match), and is
  **not an instruction block** (rejects exam instructions, NTA notices, experiment/syllabus lists).
- **De-duplication:** a non-English/regional paper (a duplicate of the English version) is skipped; the text is
  truncated at the solutions-section header (no re-mining restated solutions); the same question repeated across
  booklet codes collapses via an **OCR-tolerant content fingerprint** (`stem_fp`, the set of longest words).
- **Provenance (OD-2):** every item still carries the full chain (doc/exam/year/subject/chunk_ids/sha256),
  content-addressed id (now position-bound so a repeated page yields distinct rows).

**Live outcome (measured, honest):**
- **11,598 question INSTANCES from 109 docs** (≈10,599 distinct by content fingerprint): NEET 10,184 ·
  JEE_ADVANCED 1,033 · JEE_MAIN 381. Types: mcq 10,029 · match 1,138 · assertion_reason 244 · numerical 178.
- The verifier's phantom docs (NTA notice, experiment list, Hindi garble) now yield **0 items**; no span exceeds
  the 3000-char cap; every item has a full provenance chain.
- **Honest instance model:** one PDF may hold several booklet codes / a solutions restatement → repeat instances.
  B5 counts **distinct DOCS** for the OD-5 N≥30 floor and **normalizes per-doc**, so instance duplication can
  never distort a measured distribution; `stem_fp` enables corpus-wide dedup at B5.
- subject_rate ~8% / concept_rate ~1% (much of NEET is honest-null at subject/chapter level) — honest-null, never
  guessed.

**Adversarial verification took THREE rounds** (this is the hardest milestone — extracting questions from OCR'd
papers): **R1 REFUTED** (P0 phantom flood — instructions/notice/experiment-list/variables mined; 349k-char
tail-swallow) → redesigned around the per-item structure gate. **R2 REFUTED at P1** — instruction/section-header
text still slipped in via the NEXT question's options bleeding into the span; `stem_fp` false-merged 210 distinct
questions; the readability floor dropped 132 real chemistry questions → **fixed:** stem-scoped the gate (reject a
section/instruction leading stem), exact-content dedup (no false-merge), relaxed the readability floor. **R3 →
CONDITIONAL PASS** — the P1s are closed (false-merge 0; chemistry recovered; section/instruction rejected;
provenance/determinism/freeze **flawless**); a **P2 residual** of JEE answer-key lines (`Q.26:(A),(C)` — answer
letter as the first paren → tiny stem) → **fixed:** the stem must carry ≥12 letters of real question prose, plus
a paper-furniture guard.

**Final live outcome:** **15,803 question instances / 108 docs** (NEET 14,432 · JEE_ADVANCED 987 · JEE_MAIN 384;
mcq 14,047 · match ~1,700 · assertion 273 · numerical ~180). Phantom docs 0; spans capped at 3000; **0
false-merge**; every item fully provenance'd; frozen kie.db + index + examdna v1 **byte-identical**; deterministic.

**Tests:** `kie/tests/test_program_b_b3_mining.py` — 25 tests (markers, the structure gate incl.
instruction/section/answer-key/furniture rejection + chemistry recall, dedup no-false-merge, full-chain synthetic,
live anti-phantom/provenance/span-cap/determinism). Full KIE suite **1210 green** (incl. the OCR lane's 35 tests).

**EOS gate: CONDITIONAL PASS.**

**Honest limitations + tracked residual (stated):**
- **Instance duplication:** a paper's booklet codes (OCR'd differently) yield repeat INSTANCES that exact dedup
  cannot safely collapse (a coarser fingerprint would false-merge distinct questions). NEET is ~5× (14,432
  instances vs ~200/paper). **This is handled at B5, not B3:** B5 counts DISTINCT DOCS for the OD-5 N≥30 floor and
  NORMALIZES per-doc, so instance duplication cannot distort a distribution; `stem_fp` + repeated `question_number`
  let B5 estimate the multiversion factor. **B3 must not be read as a unique-question count.**
- **Residual P2/P3 (tracked, ~0.1%):** a handful of JEE-Advanced option-only OCR fragments still pass; a few real
  long/passage questions (options >900 chars out) are honest-null-dropped (missing > wrong). Both are tiny and
  JEE-Advanced-concentrated; B5's per-doc normalization further dilutes the wrong-data impact.
- **Coverage:** 108/225 docs — per-question extraction needs a structured, readable, English paper; OCR-scrambled /
  regional / non-MCQ papers are honest-null. subject ~6% / concept ~1% (NEET) → chapter-level DNA at B5 will be
  sparse / `insufficient_evidence`. The **OCR Recovery Lane** (parallel) works to lift the OCR floor over time.

## B4 — Structural difficulty (OD-3) + marking-scheme extraction (OD-6) · 2026-07-22

**Scope:** attribute a STRUCTURAL difficulty to every question (OD-3: never a measured student-difficulty claim)
and establish the marking scheme per exam (OD-6: parsed / published / honest-null — never fabricated).

**What landed:**
- `difficulty.py` → `pyq_item_difficulty` — a deterministic complexity PROXY from `(question_type, span_len)`,
  labelled `difficulty_basis='structural_proxy'` on **every** item. Measured (pilot p-value) difficulty is
  **honest-null** until the ERP response spine has pilot data (R5-5). Coarse by design + labelled as such.
- `marking.py` → `marking_scheme` — per (exam, question_type): NEET mcq **+4/−1** (`parsed_from_paper`, 18/105
  papers state it in a marking context), JEE Main mcq **+4/−1** (`published` — stable), JEE Main numerical +
  JEE Advanced **`honest_null`** (genuinely variable by section/year — NEVER fabricated).

**Live:** difficulty easy 12,869 / moderate 1,768 / hard 1,166 (structural_proxy — NEET is mostly short single
MCQs). Marking: 1 parsed / 1 published / 2 honest-null. Frozen kie.db + index + **examdna v1 byte-identical**.

**Adversarial verification → CONFIRMED** (both hard owner rules hold: `difficulty_basis` is `structural_proxy`
on 15,803/15,803 rows — no measured claim; 0 honest-null schemes carry a mark — no fabrication; deterministic;
v1 untouched). It found a **P2 provenance-honesty defect** — the marking detector fired on bare token
co-occurrence (`+4 μC … −1 m`), so `parsed_from_paper` was an overclaim (JEE Advanced false-fired 26/52).
**Fixed:** the detector is now **context-aware** (the number must sit with `marks`/`awarded`/`deducted`/`correct`)
— false-positives eliminated, JEE Advanced drops to 4/52, NEET rises to a genuine 18/105, JEE Main correctly
falls to `published`. P3s (schema-comment overstated signals; parsed branch hardcoded values) also fixed.

**EOS gate: PASS.** Tests: `kie/tests/test_program_b_b4.py` (11). Full KIE suite **1221 green**.

## B5 — Measured Exam DNA v2 (R5-4) · 2026-07-22

**Scope:** the program's headline deliverable — a MEASURED exam-DNA derived from the re-mined PYQ corpus, honest
about what the ~188-doc corpus can and cannot support, with `examdna.db` v1 preserved byte-identical (OD-6).

**What landed** — `dna_v2.py` → `exam_dna_v2` + `exam_dna_v2_delta` in Program B's own `pyq_corpus.db`:
- **Per-doc-NORMALIZED** distributions: each contributing paper is weighted equally (a doc's internal bucket
  proportions count once), so the booklet-instance duplication B3 leaves in place **cannot distort** a
  distribution. This is where B3's "instances, not unique questions" is neutralized.
- **OD-5 floor of 30 mined docs** per cell: at/above → measured (`pyq_measured` for observed question-type;
  `structural_proxy` for B4's difficulty — never "measured student difficulty", OD-3); below → **honest-null
  `insufficient_evidence`** (probability NULL, never fabricated).
- **Subject weight = `published`** (the exam mandates its subject split — truer than thin OCR attribution).
- A **measured-vs-v1 delta** report (structural proxy vs v1's authored `curated_prior`).

**Adversarial verification → CONFIRMED, then a load-bearing HONESTY fix.** The verifier confirmed every measured
claim by independent recomputation (per-doc normalization exact to the digit; 0 fabrication; floor-gated; v1
byte-identical). But it caught a decisive **P2**: the floor keyed on distinct **docs**, and NEET's "74 mined
papers" are really only **~10 distinct exam years** (2020 = 23 docs, 2023 = 19 — booklet/shift PDFs of the SAME
sitting, which are NOT independent). Counting 74 duplicated docs as 74 independent PYQs would inflate the sample
— exactly the statistic-fabrication OD-5 ("30 **independent** PYQs") + the standing law forbid. **Fixed:** the
floor + normalization now key on distinct **independent sittings** `(exam, year)`; a distribution is averaged
sitting→doc→item, so neither within-doc booklet instances nor cross-doc booklet PDFs of one sitting can distort
it. (Also fixed a P3 doc-drift: the B3 schema's "B5 dedups by stem_fp" comment corrected.)

**Live outcome (the honest truth of the owned corpus):**
- **Under the independent-sitting floor, NO exam qualifies:** NEET **10** sittings, JEE_ADVANCED **14**, JEE_MAIN
  **6** — all < 30 → **every measured distribution is `insufficient_evidence`** (honest-null, never fabricated).
  The owned ~188-doc corpus is really ~10–14 exam sittings per exam; it does not meet the owner's 30-independent
  -PYQ bar. This is the honest measurement of the evidence gap — not a machinery failure.
- What v2 DOES publish: **`published` subject weights** (mandated NEET 25/25/50, JEE thirds). Measured
  question-type + structural difficulty are honest-null pending ≥30 independent sittings (acquisition, OD-8 — the
  machinery is proven + scalable and will emit measured DNA the moment the evidence exists).
- **`examdna.db` v1 BYTE-IDENTICAL** (OD-6); build deterministic; every `insufficient_evidence` cell records its
  `n_sittings` + `n_docs` honestly.

**Tests:** `kie/tests/test_program_b_b5.py` (13, incl. per-sitting normalization + booklet-collapse + all-exams-
insufficient). Full KIE suite **1238 green**.

## B6 — Exam DNA v2 consumer contract (integration) · 2026-07-22

**Scope:** the roadmap's "blueprints surface DNA `provenance_class`; any exam-representative claim gates on v2."

**What landed** — `dna_access.py`:
- `exam_dna(exam[, dimension])` — returns every v2 cell **with `provenance_class` (and `basis`) surfaced**; an
  `insufficient_evidence` cell is returned with `probability=None` (a consumer must handle honest-null, never a
  fabricated 0).
- `assert_exam_representative(exam, dimension)` — **FAIL-CLOSED**: raises `ExamDnaV2InsufficientEvidence` unless
  that dimension is genuinely `pyq_measured`. On the current corpus **every** exam-representative claim is refused
  (no exam clears the independent-sitting floor) — the gate never lets an under-evidenced claim through, and it
  will allow one the moment ≥30 independent sittings make a dimension measured. `published` (mandated) and
  `structural_proxy` are also not "exam-representative" measurements — only `pyq_measured` is.
- `coverage()` — the per-(exam, dimension) provenance map a consumer consults before trusting any cell.

**EOS gate: PASS.** Tests: `kie/tests/test_program_b_b6.py` (5). Full KIE suite **1238 green**.

**Scope:** classify every `kie.db :: source_documents` row (1,241) into a fail-closed role + reconstructed
exam/year/authority, so downstream milestones consume only genuine PYQ with honest provenance (OD-1, OD-2).

**What landed** (new package `kie/qie/pyq/`, all read-only over the frozen `kie.db`):
- `taxonomy.py` — canonical exams (`NEET`/`JEE_MAIN`/`JEE_ADVANCED` + `AIPMT`/`AIIMS` lineage, family map),
  canonical subjects, and deterministic normalizers. **Fail-closed by construction:** `canonical_exam()` returns
  `None` for any non-exam token — so a dump folder (`Cursor_Downloads`, `Practice_Resources`) can never be an
  exam, and a bare unqualified `JEE` (no main/advanced) is honest-null. Year parser uses digit-boundary
  lookarounds (not `\b`) so underscore-delimited years (`JEE_Advanced_2010_Paper1`) parse while a longer number
  never yields a spurious year; **two years in one blob → honest-null (ambiguous, never guessed).**
- `schema.sql` + `store.py` — the derived `pyq_corpus.db` (local-only, gitignored; holds ALL Program B output so
  `examdna.db` v1 stays byte-identical per OD-6). Table `pyq_source_class`.
- `source_class.py` — the classifier. `classify()` is a **pure function** of `(source_documents row, head_text)`;
  `build()` runs it over the corpus. Exam resolution triangulates path segments + filename + category token +
  the doc's own head-chunk content, **fail-closed**: a path/content conflict → `ambiguous` (honest-null); a
  content-silent path token is labelled `path_token` (never overstated as content-corroborated). Practice/mock
  archive tokens (`*_dpp*`, `*_mock`, `*chapterwise`) override a stale `doc_type` so a mislabelled
  `previous_paper` under a practice archive is caught. Aptitude sub-tests (AAT) are excluded from DNA eligibility.
- `controls.py` — 8 adversarial controls (known-bad must be refused, known-good must resolve), incl. the D5
  folder-trust attack, path/content conflict, bare-JEE, DPP/mock non-eligibility, and the official-archive
  provenance recovery. All 8 pass.

**Live outcome (measured, honest — post-verification fixes):**
- **1,241 docs classified:** genuine_pyq **226** · practice_dpp 799 · solution_key 118 · unknown 47 · textbook 29 ·
  sample_paper 13 · mock 9.
- **eligible_for_dna = 225** (genuine_pyq AND a resolved exam AND not an aptitude sub-test AND has minable
  content): **NEET 105 · JEE_MAIN 68 · JEE_ADVANCED 52** — all three clear the OD-5 N≥30 floor at the exam level.
  This **recovers**
  above the raw 188 competitive-PYQ docs: the `Cursor_Downloads/jeeadv_ac_in_archive/...` official JEE-Advanced
  archive + the Embibe JEE-Main papers were reclaimed by reconstructing identity from the full path (the exact
  "provenance reconstruction" the owner flagged), each corroborated by an official/third-party authority tag.
- **Authority recorded honestly:** even most "real category" NEET papers are third-party mirrors
  (`mirror_Careers360`); only the `jeeadv.ac.in` archive is `official`. B5 can filter on this.
- **Year:** 224/235 eligible PYQ carry a year (11 honest-null).
- **honest-null exams (78):** textbooks (29, correct — not exams) + genuinely unattributable practice/unknown.

**Safety + determinism (verified in tests):** frozen `kie.db` + `knowledge_index.db` **MD5 byte-identical**
before/after every build; rebuild is deterministic; the D5-regression query (an exam with zero path/category/
content signal) returns **0**; no practice/mock path leaks into genuine_pyq; `eligible_for_dna` strictly implies
genuine_pyq ∧ resolved-exam.

**Tests:** `kie/tests/test_program_b_b1_source_class.py` — 17 tests (hermetic taxonomy + classify fail-closed +
8 adversarial controls + live-corpus + freeze-safety + determinism). Full KIE suite **1126 green** (1109 baseline
+ 17), 0 failures / 0 errors / 0 db-skips (KIE_CANONICAL=1).

**Adversarial verification (independent, file-disjoint, refute-first):** **Round 1 → REFUTED** — the verifier
found a real leak class the 17 tests + 8 controls were blind to: a **pure NEET-2018 answer key** (`8bab2d2d`) and
a **zero-content NEET solution** (`97d0b7f5`) were stamped `genuine_pyq / eligible_for_dna=1`. Root cause: `_role`
had guards for practice/mock/sample/aptitude but **none for solution/answer keys**, and a generic "question bank"
token could rescue a DPP. **Fixed + regression-locked:** added a solution/answer-key path guard (with a
`with_sol`/`qs_ans` keeper escape so real papers that merely carry solutions stay eligible), split the pyq signal
so only a STRONG `previous_paper`/`pyq` token promotes (a generic "question bank" no longer does), and added a
zero-content eligibility guard. Verified against every concrete repro; also dropped 6 `Motion_JEE_*` coaching
sets that had leaked in under `Practice_Resources`. **Round 2 → B1 HOLDS** — both P0s genuinely closed, **zero
over-exclusion** of intact papers (the 235→225 delta is exactly the 2 keys/solutions + 1 zero-content official
paper + 7 single-subject coaching extracts), freeze/determinism/D5 intact. Round 2 found one real **P1-latent**
(the solution-key regex was overfit to the two spellings in the frozen corpus — bare `key(s)`/`answers`/`soln`/
`ans_key` would dodge on the re-mine) + a **P3** (a practice-archive doc whose filename carries a `previous_paper`
token could escape). **Both fixed + regression-locked:** the guard now uses generalized spellings with
alphanumeric boundaries (not `\b` — the same `_` trap the year parser avoids), and a practice/mock-archive doc is
never promoted to genuine_pyq. Confirmed: all dodging spellings caught, all 6 keepers safe, eligible unchanged at
225. Locked by 15 adversarial controls + 20 live/hermetic tests.

**EOS gate: PASS.**

**Deferred to B3 (recorded, not lost):** a *content-based* answer-key detector (a QNO→ANS table with no question
stems) — B3's question extraction is self-correcting here (a pure answer table yields 0 question stems → 0
mined items → contributes nothing to DNA), but B3 will add an explicit skip so such docs are never counted.

## B2 — Subject attribution (OD-4) + subject-scoped concept resolution (D3 fix) · 2026-07-22

**Scope:** implement OD-4 (subject from the source document, BEFORE concept resolution, never from a legacy
prefix) and the structural fix for defect D3 (mislabelled concept prefixes like `BIO_MOTION`).

**What landed** (new modules in `kie/qie/pyq/`, read-only over the frozen kie.db + index):
- `subject_seg.py` — walks each **DNA-eligible** paper's chunks **in document order** and attributes a subject to
  each chunk: a `section_path` naming one subject (the parser's structural heading, authoritative) → that
  subject; else an **in-text header** (a subject ADJACENT to a PART/SECTION cue, exactly one subject — so a
  multi-subject cover line or an incidental mention is NOT a header) → that subject, which (re)sets the current
  subject for following chunks; else **inherit** the current subject; else **honest-null**. Output table
  `pyq_chunk_subject`. B3 inherits each extracted question's subject from its chunk.
- `concept_attr.py` — the **subject-scoped, strict** concept resolver: `resolve(index, subject, *names)` returns a
  KC_ concept only on a **unique in-subject** name match; **0 matches, within-subject ambiguity, or no subject →
  honest-null**; **never cross-subject, never the prefix**. This makes the D3 fix structural: a "Motion" question
  in a Physics section resolves to the Physics concept (or null) and can never land on Biology. Plus
  `mislabel_report()` — live D3 evidence measured against the **independent frozen index** (not the
  co-mislabelled `concepts.subject_domain`).

**Live outcome (measured, honest):**
- `pyq_chunk_subject`: 14,575 chunks over the 225 eligible docs. **Subject doc-coverage = 40.4%** (91/225 docs
  have a detectable subject-section header): Physics/Chemistry/Mathematics/Biology attributed; the remaining
  **~60% is honest-null at subject level** (no detectable header — those papers still contribute to *exam*-level
  DNA, just not *subject*-level). Coverage is reported, never inflated.
- **D3 evidence (independent):** of the old prefixed concept codes checkable against the frozen index, **51.7%
  (164/317) have a prefix that DISAGREES with the index's subject** (e.g. `BIO_ACIDS_AND_BASES`→Science,
  `BIO_APPLICATIONS`→Chemistry, `BIO_NEWTON_S_*_LAW`→Physics) — proof the prefix is unusable and why subject must
  come from the document. (Measured against `ki_concept.subject`, *not* the co-mislabelled `concepts.subject_domain`
  — that agrees with the bad prefix and would have hidden the defect.)

**Safety + determinism:** frozen `kie.db` + `knowledge_index.db` + `examdna.db` v1 **byte-identical**; rebuild
deterministic; every NULL subject is labelled `honest_null` (no silent default); resolver strictly subject-scoped.

**Tests:** `kie/tests/test_program_b_b2_attribution.py` — 15 tests (hermetic header-detection + segmentation +
concept-resolution controls on a synthetic index + live coverage/honest-null/freeze/determinism/mislabel-evidence).
Full KIE suite **1144 green** (0 failures/errors/db-skips, KIE_CANONICAL=1).

**Adversarial verification (independent, refute-first):** **Round 1 → REFUTED** — the verifier found a real
**P0 boundary defect**: subject was attributed at whole-chunk granularity, so a chunk holding a Physics question
followed by a mid-chunk `PART-II CHEMISTRY` header was stamped Chemistry entirely (proven on `c93299dddc` ord 6
Physics→Chemistry, ord 9 Chemistry→Mathematics; ~61 question-bearing boundary chunks across 13 docs). Also: two-
header chunks silently inherited the wrong prior subject (P1); the 51.7% mislabel headline was inflated by the
coarse `Science` bucket (P2); the header regex matched `part` inside `particle`/`department` and prose "part of
physics" (P2/P3); a schema comment drifted (P3). **All fixed + regression-locked:** attribution is now
**offset-aware** — a chunk that straddles a boundary (header deeper than 50 chars, or ≥2 subject headers) is
**honest-null `mixed_boundary`** (never a single wrong subject) while the current subject still advances so the
next chunk inherits correctly; the header regex is `\b`-anchored with a numeral/single-letter-only label gap
(rejects prose); the mislabel report now reports the broad rate AND the clean cross-subject-swap rate separately
(51.7% / 6.3% — both honest); schema corrected. Live: `c93299dddc` ord 6/9 → `mixed_boundary`; 1061 straddling
chunks now honest-null instead of mislabelled. **Round 2 → B2 HOLDS** — the P0 is genuinely closed (0
single-subject-stamped chunk still straddles a boundary; both repros NULL; all 47 two-header chunks
`mixed_boundary`). Round 2 found the fix opened a **P2 over-nulling** in the *safe* direction: 863 clean
single-subject *continuation* chunks (a deep header repeating the subject already in force — a per-question tag /
sub-section, not a boundary) were nulled. **Fixed:** a deep header whose subject **equals** the current subject
is now a `continuation` (attributed), only a **different** subject is a boundary — recovering 863 chunks (subject
-attributed chunks 4,716 → 5,579) with **zero false-subject risk**, and the summary stat now separates
`(mixed_boundary)` from `(honest_null)`. `mixed_boundary` fell 1,061 → 198 (genuine boundaries only). Residual
P3s (two prose-regex forms with no numeral anchor; a <50-char boundary tail) are **latent — 0 occurrences in the
live corpus** — documented, not fixed. Locked by 21 tests.

**EOS gate: PASS.**

**Honest limitation (stated):** subject coverage is **40.4%** by construction — only papers whose own structure
exposes a subject header can be subject-attributed; the rest (incl. boundary-straddling chunks) are honest-null
(never guessed via number-range heuristics or the concept prefix). This bounds *subject-level* DNA granularity at
B5; *exam-level* DNA is unaffected. Improving it needs richer section parsing or acquired structured papers
(evidence acquisition, OD-8).

**Honest limitations (stated):** subject is deliberately NOT pinned at the doc level for full papers
(`multi_subject_defer`) — it is resolved per-question from section headers at B2/B3 (OD-4). Practice/mock exams
are attributed for completeness but excluded from DNA (OD-1). 40 `unknown`-role + 78 honest-null-exam docs remain
honest-null, never guessed.
