# Program B — PYQ Re-attribution & Re-mining · Engineering Discovery & Plan

**Status:** 📐 **PLAN ONLY — awaiting owner approval. Nothing implemented.**
**Date:** 2026-07-22 · **Author lane:** Program B (new, independent) ·
**Predecessor (immutable):** QIE/QDI Remediation Program — COMPLETE, OWNER-ACCEPTED, FROZEN
(baseline `42c93454` on `feature/qie-question-planning-layer`).

This document is the deliverable of Program B's **first objective**: a complete engineering discovery
and planning phase. It does **not** begin implementation. Per the program rules, after this plan the
program **STOPS** until the owner explicitly approves it.

**Standing laws inherited (non-negotiable, carried from the remediation program):**
Honest-Null · never fabricate metadata · never weaken a certification gate · preserve provenance ·
freeze-as-versioning (frozen `knowledge_index.db` + `kie.db` never mutated) · deterministic checks
certify (model agreement may reject, never certify) · every future implementation independently verifiable.

> **Governing lesson (why this program exists):** *"wrong knowledge is worse than missing knowledge."*
> The current mined corpus is not missing — it is **confidently wrong** (a constant `exam`, a null
> `subject`, mislabelled concept prefixes, and no link back to the source paper). Program B's job is to
> replace confidently-wrong metadata with **measured, provenance-linked, honest-null** attribution.

---

## 0. What was read first (per the program's READ-FIRST rule)

- **Engineering Completion** — `QIE_REMEDIATION_ENGINEERING_COMPLETION.md` (§6 names R5-4 as "not cleanly
  buildable → Program B"; §9 Program B charter).
- **Execution Log** — `QIE_REMEDIATION_EXECUTION_LOG.md` (owner-decision queue item 1 = R5-4 re-mining).
- **Certification History** — `QIE_REMEDIATION_CERTIFICATION_HISTORY.md` (R5-1/R5-2/R5-6 checkpoints that
  Program B *reuses*; the 🔒 owner-acceptance freeze marker).
- **SSOT Roadmap** — `QIE_REMEDIATION_ROADMAP.md` §R5-4 (Exam DNA v2 — measured, not self-referential) and
  §R5-5/§R5-6 (the calibration + evidence-cleaning items Program B partially unblocks).

The remediation program is treated as **immutable history**. Program B builds a new derived layer *on top
of* the frozen substrate; it re-opens nothing that was certified and mutates no frozen store.

---

## 1. Current PYQ corpus quality assessment

Every number below was measured **live** against the read-only databases on 2026-07-22
(`kie.db` opened `mode=ro`, perms `r--r--r--`; `examdna.db` `mode=ro`). No store was written.

### 1.1 Source-document substrate — `kie.db :: source_documents` (1,241 docs)

| Field | Completeness | Note |
|---|---|---|
| `exam` | 100% populated — **but degenerate** | `exam` is a **verbatim copy of `category`** (the top folder). Not a parsed exam identity. |
| `category` | 100% | **861/1,241 (69%) = `Cursor_Downloads`** — a download-dump folder, *not* an exam. |
| `subject` | **88% (1,096/1,241)** | Physics 560 · Chemistry 235 · Mathematics 228 · Biology 73 · null 145. **The most usable existing signal.** |
| `class_label` | **4% (48/1,241)** | Near-absent grade attribution. |
| `year` | 34% (423/1,241) | Weak temporal signal. |
| `doc_type` | ~99% | dpp 704 · previous_paper 226 · unknown 126 · solution 93 · textbook 29 · answer_key 23 · sample_paper 13 · (empty) 12 · mock_test 9 · collection 6. |

**Genuine competitive-exam previous papers** (the honest measurement base for exam DNA):

| Category | doc_type | Count |
|---|---|---|
| NEET | previous_paper | 106 |
| JEE_Main | previous_paper | 61 |
| JEE_Advanced | previous_paper | 20 |
| NTA_Sample | sample_paper | 1 |
| **Total genuine competitive PYQ** | | **≈ 188 docs** |

Everything else is a different provenance class: **704 `dpp`** (daily practice problems — *practice-set*
density, not exam density), **9 `mock_test`** (third-party mocks), 29 textbooks, 116 solution/answer-key
files, 126 `unknown`, and the 861 `Cursor_Downloads` (unclassified dump — may hide real papers).

### 1.2 Text substrate — `kie.db :: chunks` (re-mining IS possible)

- **57,390 chunks across 1,229 docs**, each with a `doc_id` **foreign key → `source_documents`**.
- `block_type` includes `question`, `option`, `solution`, `formula` — questions are structurally
  addressable.
- `chunks_fts` (full-text) + per-chunk `sha256` exist → content-addressed evidence is available.
- **This is the decisive asset: the corpus can be re-mined from source with correct, doc-linked attribution.**

### 1.3 Parser / OCR state of the PYQ subset (248 previous_paper+mock+sample docs)

born_digital_text 151 · **scanned_image 75** · **sparse_text 21** · unknown 1.
→ **~39% (96/248) are OCR-derived or text-sparse** and need the OCR fail-safe (§9).

### 1.4 Current mined product — `kie.db :: question_patterns` (4,853 rows)

Structurally present (mcq/numerical/assertion_reason/match/short_answer well-distributed), but the
**attribution is unusable** (§2). This is the artifact R5-4 cannot honestly build on.

### 1.5 Current Exam DNA — `examdna.db` (v1, the thing to supersede)

- `exam_weight`: **subject weights hardcoded to 0.333** (`basis='published exam structure'`), chapter weights
  `provenance_class='evidence_proportional'` with basis strings that literally say **`"...NOT PYQ-measured"`**.
- `exam_distribution`: difficulty / depth / archetype probabilities, `provenance_class='curated_prior'`.
- **No marking-scheme table exists** (R5-4 requires +4/−1 / partial stored).
- `version='v1'`, `status='curated'`. Crucially, the builder docstring reserves `status='certified'` for
  **"the mining phase … which replaces the curated_prior dimensions with mined, independently-audited
  evidence and bumps the version."** — **Program B is that pre-designed mining phase.** The schema already
  anticipates a measured v2 without mutating v1.

### 1.6 Verdict

The corpus is **recoverable but not repairable-in-place.** The *substrate* (docs + chunks + doc-level
subject + the frozen concept index) is sound and linkable; the *derived attribution* (`question_patterns`
+ `examdna` v1) is degenerate. Program B is a **re-mine from substrate**, not a re-label of the patterns.

---

## 2. Existing attribution defects (defect register)

Each defect below is **confirmed by live query**, not inherited from prior prose.

| # | Defect | Evidence | Severity |
|---|---|---|---|
| **D1** | `question_patterns.exam` is a constant | `exam='foundation'` on **4,853/4,853** | P0 for measured DNA |
| **D2** | `question_patterns.subject` is null everywhere | `subject=NULL` on **4,853/4,853** | P0 |
| **D3** | `concept_code` subject-prefix is mislabelled | `BIO_MOTION` (27), `BIO_POWER` (25), `BIO_DESCRIBING_MOTION` (7), `BIO_MOTION_IN_A_STRAIGHT_LINE` (6), `BIO_HOW_FORCES_AFFECT` (4) — physics topics under `BIO_` | P0 (a mislabel would leak into a subject weight) |
| **D4** | **No pattern→document provenance** | all 4,853 `evidence` = identical placeholder `{"analysis":"pyq_pattern"}` — no doc_id, no chunk ref | **P0 — makes in-place re-attribution impossible** |
| **D5** | doc `exam` = folder name (`exam`≡`category`) | **861/1,241 `exam='Cursor_Downloads'`** — a folder, not an exam | P0 (folder-trust is the root cause) |
| **D6** | difficulty is defaulted, not measured | 88% (`4,282/4,853`) labelled `hard` — not a credible distribution | P1 |
| **D7** | weak temporal signal | `years` populated on 33% of patterns; doc `year` 34% | P1 (frequency/recency weighting is thin) |
| **D8** | grade attribution near-absent | doc `class_label` 4% | P2 |
| **D9** | examdna v1 is self-referential | chapter weights `evidence_proportional` to the index's own concept density; subject weights hardcoded 0.333; no marking scheme | P1 (the R5-4 defect itself) |
| **D10** | practice ≠ exam conflation risk | 704 `dpp` + 9 `mock_test` are practice material; folding them into "exam DNA" would measure practice density | P1 (design must separate them) |

**Root cause (single sentence):** the original mining pass trusted **folder names** for identity and
**stored no link back to the paper**, so identity is both wrong *and* unverifiable. Program B fixes both:
attribute from **content + doc-level subject + the certified concept spine**, and **record the doc/chunk
provenance on every mined item.**

---

## 3. Required data model

All new stores are **derived and versioned**; the frozen `kie.db` / `knowledge_index.db` are opened
`mode=ro` and remain **MD5 byte-identical**. `examdna.db` v1 rows are **never mutated** — v2 is appended.

### 3.1 New derived store — `pyq_corpus.db` (gitignored, like the other derived stores)

**`pyq_source_class`** — one row per `source_documents.doc_id`, the corpus-scoping decision:
```
doc_id PK · source_role (genuine_pyq | practice_dpp | mock | textbook | solution_key | unknown)
         · exam_resolved · exam_method · exam_confidence
         · subject_resolved · subject_method · subject_confidence
         · year_resolved · year_method
         · classify_basis (json: raw signals → decision) · provenance_class · created_at
```

**`pyq_item`** — one row per re-mined question (the corrected replacement for `question_patterns`):
```
item_id PK (content-addressed) · doc_id FK→source_documents
         · chunk_ids (json: ["<doc_id>#<ordinal>", ...])   -- REQUIRED provenance
         · chunk_sha256 (json, RI-2 style content binding)
         · exam · subject · concept_kc (KC_ id, honest-null allowed)
         · question_type · marks · negative_marks
         · difficulty_label · difficulty_basis (pilot_measured | structural_proxy | honest_null)
         · year · attribution_confidence · attribution_method (json per-field)
         · provenance_class · honest_null_fields (json list) · created_at
```

**`pyq_attribution_audit`** — append-only ledger: `(item_id, field, raw_signal, resolved_value, method,
confidence, decided_at)`. Nothing is overwritten; every attribution decision is inspectable.

**`marking_scheme`** — `(exam, subject, question_type, marks_correct, marks_incorrect, partial_rule,
source_doc_id, provenance_class[published|parsed_from_paper|honest_null], version)`.

### 3.2 Extended examdna (append v2 — never touch v1)

Reuse the existing `exam_weight` / `exam_distribution` schema (it already carries `provenance_class`,
`status`, `version`). Program B writes **new rows** with:
- `version='v2'`, `status='certified'` **only** after the gate passes,
- `provenance_class='pyq_measured'`, and a `basis` string that cites the **exact measured N**
  (e.g. `"pyq_measured: 142 NEET Physics items across 12 papers, 2015–2024"`),
- honest-null cells (below the small-sample floor, OD-5) either **omitted** or written with an explicit
  `provenance_class='insufficient_n'` fallback to the v1 evidence_proportional value, **clearly labelled**.

### 3.3 Versioning key

The derived layer is fingerprinted to `(frozen_index_fingerprint, pyq_corpus_fingerprint)` so a rebuild is
deterministic and any drift is detectable — mirroring R5-1/R5-2/R5-6.

---

## 4. Re-mining pipeline

Ten deterministic stages. Each stage is **honest-null-first**, **append-only in provenance**, and
**re-runnable to a byte-identical result**. Model assistance (if any) may *propose* but a deterministic
rule *decides* — model output can never certify (standing law).

```
S1  Corpus scoping & role classification   source_documents → pyq_source_class.source_role
S2  Exam attribution                        (content + category signals, fail-closed on folder) → exam_resolved
S3  Subject normalization                   (doc subject ∧ concept subject_domain) → subject_resolved
S4  Question extraction                     chunks[block_type∈{question,option,solution}] grouped per doc → pyq_item skeletons (+ chunk provenance)
S5  Concept / KC re-attribution             subject-scoped resolution over the KC_ spine → concept_kc (honest-null on ambiguous)
S6  Difficulty classification               structural proxies (labelled) — measured difficulty stays honest-null pre-pilot
S7  Marking-scheme extraction               parse paper instructions; else published scheme; else honest-null
S8  Aggregation → exam_dna_v2               measured weights + distributions with N + provenance_class='pyq_measured'
S9  Independent verification (adversarial)  refute-first probes (§11); REFUTED → fix + regression-lock
S10 Versioned publish                       append examdna v2 (v1 preserved); blueprints gate on v2 (§12/B6)
```

Guardrails threaded through every stage: (a) the frozen substrate is `mode=ro`; (b) a question that cannot
be cleanly attributed on a given axis is counted in an explicit **"unattributed" bucket** and *excluded*
from that axis's measured weight — never silently dropped, never guessed; (c) every `pyq_item` carries its
`chunk_ids` — an item with no resolvable source chunk **is not created**.

---

## 5. Exam classification strategy

**Canonical taxonomy** (competitive-exam DNA only): `NEET`, `JEE_Main`, `JEE_Advanced`.
Historical lineages recorded but mapped honestly: `AIPMT`→NEET-lineage, `AIIMS`→NEET-lineage (label
retained in provenance; owner decides whether lineage papers feed current-exam DNA — OD-1). `NCERT` /
`CBSE_NCERT` / `TS_SCERT` are **board/textbook**, not competitive-exam DNA.

**Signal hierarchy (fail-closed):**
1. **Content signals from the doc's own chunks** are authoritative — paper header/title ("National
   Eligibility cum Entrance Test", "JEE (Main) 2019"), question count, marking pattern (+4/−1), section
   structure.
2. **`category` folder** is used **only when it is a real exam token** (NEET / JEE_Main / JEE_Advanced /
   AIIMS / AIPMT / NTA_Sample) **and content does not contradict it**.
3. **Filename tokens** — last resort, corroborating only.

**Hard rules:**
- **`Cursor_Downloads` (861) never assigns an exam by folder name.** Each such doc is classified by content;
  if content is insufficient → `exam_resolved=NULL` (**honest-null**, excluded from measured DNA).
- **Conflict rule (the D5 fix):** if folder says NEET but content says JEE → **HOLD** (ambiguous, honest-null).
  The folder never wins over content. This is the exact defect (D5) that produced the degenerate corpus.
- Every `exam_resolved` carries `exam_method` + `exam_confidence`; a manually-reviewable **ambiguous queue**
  is produced (owner may fund a review pass — OD-2), but nothing enters a weight without a confident,
  content-grounded exam.

---

## 6. Difficulty classification strategy

This is the axis where honesty matters most (D6: 88% defaulted `hard` is not a measurement).

**The honest hierarchy:**
1. **`pilot_measured`** — empirical difficulty (p-value / % correct) from real student responses. **Not
   available:** the ERP response spine (`edu_student_item_responses`, mig 20260853) is seeded at *first
   pilot use* and cannot be backfilled (per the completion report §5). So **measured difficulty is honestly
   null today.**
2. **`structural_proxy`** — deterministic, computed, and *labelled as a proxy, not a measurement*: reasoning
   steps (from the linked solution chunk), multi-concept span, numeric-vs-conceptual, question_type
   (assertion-reason / match are structurally harder), option count. Reproducible; explicitly **not** student
   difficulty.
3. **`honest_null`** — when even a structural proxy is unreliable (OCR-mangled stem, no solution chunk).

**Decision (subject to OD-3):** Program B **computes structural-proxy difficulty and labels it as such**,
but the **`exam_distribution` difficulty dimension stays `curated_prior` until pilot data exists** — Program
B does **not** publish a "measured difficulty distribution," because it cannot measure one yet. A proxy is
never relabelled as a measurement. This keeps R5-5 (calibration) as the honest home of measured difficulty.

---

## 7. Subject normalization strategy

**Canonical subjects:** `Physics`, `Chemistry`, `Mathematics`, `Biology`. (Botany/Zoology split for NEET is
**out of scope** unless the owner requests it — the substrate labels "Biology"; splitting it would be
guessing.)

**Sources, in trust order:**
1. **Doc-level `subject`** (88% populated, clean) — the primary signal, propagated to every question mined
   from that doc.
2. **`concepts.subject_domain`** — the *authoritative* subject per certified concept (used to cross-check
   and to fill the 145 null-subject docs when the doc's concepts agree unanimously).
3. **The mislabelled `concept_code` prefix is explicitly IGNORED as a subject signal** — it is defect D3.

**Cross-check rule:** doc subject vs concept `subject_domain` → agreement = confident; **disagreement =
HOLD (honest-null)**, logged to the audit. A null-subject doc gets a subject only if its concepts are
unanimous; otherwise honest-null. **No subject is ever guessed for a weight**; unattributable items go to
the reported "unattributed" bucket.

---

## 8. Concept / KC mapping strategy

**Reuse the certified crosswalk built in remediation — do not rebuild it:**
- **R5-2 `concept_namespace`** (KC_ spine convergence) + **R5-1 multimap resolver** (CONFIRMED by adversarial
  verification; honest-null on ambiguous, never first-wins).

**The elegant fix for D3 (mislabelled prefix):** attribute **subject first** (§7, from the doc — reliable),
then resolve the concept **within that subject's scope** using the concept *name tail*, not the broken
prefix. Subject-scoped resolution makes `BIO_MOTION` resolve as *Motion → Physics* (or honest-null),
because the search space is the doc's attributed subject, so the wrong `BIO_` prefix is simply never
consulted. This turns a P0 mislabel into a non-issue by construction, without editing a single frozen row.

**Rules:** unresolved → honest-null; ambiguous (≥2 KC_ candidates in scope) → honest-null; OCR-junk codes
already retired by R5-2 stay retired. A concept is **never** assigned to make a count look better.

---

## 9. OCR cleanup strategy

**Reuse R5-6 `evidence_clean.py`** (the deterministic chunk-cleaning pass + mangled-math advisory flag,
already CONFIRMED freeze-safe / byte-identical). Program B adds no new OCR engine and **never re-OCRs a
clean body** (standing KIE lesson).

**Fail-safe policy for the ~39% OCR/sparse PYQ docs:**
1. **Prefer born-digital docs** (151 clean) for any numeric measurement.
2. For scanned docs, run the R5-6 cleaner; a chunk flagged **near-prose-free / high-symbol** is **not used
   to ground a numeric measurement** (mangled math must never become a data point).
3. A question whose *stem* is OCR-mangled may still count toward **exam / subject / question-type** DNA if
   *those* signals are clean, but its **concept and difficulty are honest-null** (partial honesty, not
   all-or-nothing).
4. Unreadable → the item is **not created** (no phantom questions).

---

## 10. Provenance preservation strategy

**Every re-mined item is provenance-complete or it does not exist:**
- `pyq_item` requires `chunk_ids` (`<doc_id>#<ordinal>`) + `chunk_sha256` (content-addressed, RI-2 style).
- `attribution_method` + `attribution_confidence` recorded **per field**; `honest_null_fields` lists what
  was refused.
- `pyq_attribution_audit` is **append-only** — every raw signal → decision is reconstructable.
- **exam_dna_v2** rows cite the exact measured N in `basis` and carry `provenance_class='pyq_measured'`; a
  cell that falls back to v1 is labelled `insufficient_n`, never silently presented as measured.
- **Freeze-as-versioning:** frozen `kie.db` + `knowledge_index.db` opened `mode=ro`; MD5 asserted
  byte-identical before/after every build. examdna **v1 rows never mutated**; v2 is additive.
- Unattributable docs (Cursor_Downloads, unknown) keep their **honest-null attribution recorded** — not
  deleted, not guessed.

---

## 11. Independent verification plan

Program B inherits the remediation method: **each substantive milestone → an independent adversarial
verifier prompted to REFUTE first** (default to "not real"); a finding that survives is fixed +
**regression-locked** before the checkpoint. Verifiers run file-disjoint from implementers.

**Mandatory refute-first probes:**
1. **Mislabel-leak:** assert no mislabelled prefix reaches a weight — a `BIO_MOTION` item lands under
   **Physics or honest-null, never Biology**. (Directly attacks D3.)
2. **Folder-trust leak:** assert `exam` is **never** assigned from `Cursor_Downloads` (or any folder) alone;
   a content-less dump doc is honest-null. (Attacks D5.)
3. **Provenance completeness:** assert every `pyq_item` resolves to a live chunk whose sha256 matches;
   an item with a dangling/placeholder evidence ref cannot exist. (Attacks D4.)
4. **Honest-null integrity:** unattributable items are counted in the "unattributed" bucket and **excluded**
   from measured weights, and the exclusion count is **reported** (no silent drop, no inflation).
5. **No-guess on ambiguity:** every ambiguous exam/subject/concept resolves to null, never a pick.
6. **Measured-vs-opinion delta report:** v2 `pyq_measured` weights vs v1 `evidence_proportional` — quantify
   divergence per chapter; a large divergence is a *finding to surface*, not smoothing to hide.
7. **Freeze-safety:** `kie.db` + `knowledge_index.db` MD5 byte-identical; examdna v1 rows untouched.
8. **Determinism:** rebuild → identical corpus fingerprint.
9. **Marking-scheme correctness:** parsed +4/−1 matches the paper's stated scheme; honest-null when unstated.
10. **Small-sample honesty:** any cell below the OD-5 floor is honest-null / labelled `insufficient_n`,
    never published as "measured."

Adversarial rounds continue until a verifier returns CONFIRMED (or its findings are all fixed + locked),
exactly as R4-3/R5-2/R5-6 did (all of which returned REFUTED and found real defects).

---

## 12. Certification milestones

Each milestone follows the standing checkpoint discipline: **Design → Implementation → independent
adversarial verification → tests → EOS gate → documentation → commit**, with the frozen stores asserted
byte-identical at every step.

| Milestone | Scope | Exit gate |
|---|---|---|
| **B0** | This discovery + plan | **Owner approval** (the STOP below). |
| **B1** | Corpus role classification (`pyq_source_class`) — genuine_pyq / practice / textbook / solution / unknown; Cursor_Downloads + unknown resolved-or-honest-null | controls: known-bad classification refused; coverage reported honestly |
| **B2** | Exam + subject + concept **re-attribution** (honest-null throughout) | adversarial verify probes 1,2,5; EOS |
| **B3** | Question **re-mining** with doc-linked provenance + OCR fail-safe | adversarial verify probes 3,7; content-addressed evidence; EOS |
| **B4** | **Difficulty** (structural-proxy, labelled) + **marking-scheme** extraction | probes 6,9; honest-null where absent; EOS |
| **B5** | **exam_dna_v2** measured layer (weights + distributions, N + provenance) | probes 4,6,8,10; measured-vs-opinion delta report; v1 preserved; EOS |
| **B6** | Integration — blueprints surface `provenance_class`; every "exam-representative" claim gates on v2 | final EOS gate; RI-6/RI-2 style invariants added to the permanent suite |

Every milestone adds regression tests to the kie suite (currently 1109 green) and must keep it green.
No milestone weakens an existing gate; no milestone ships a product-visible artifact (Program B produces a
*measurement layer*, not student-facing questions — those remain gated behind Program C's live key).

---

## 13. Required owner decisions

These cannot be made from the code or the standing laws alone; the plan **STOPS** for them. A recommendation
is given for each, but the owner decides.

| # | Decision | Recommendation |
|---|---|---|
| **OD-1** | **Exam-DNA scope:** measure only genuine competitive PYQ (~188 NEET/JEE_Main/JEE_Advanced docs), or also include `dpp`/`mock` as a *separate, clearly-labelled* practice-DNA class? And do AIPMT/AIIMS lineage papers feed current NEET DNA? | Exam DNA = **genuine competitive PYQ only**; `dpp`/`mock` recorded as a **separate `practice_measured` class**, never mixed into exam weights. Lineage papers feed NEET DNA **only** with a `lineage` provenance flag. |
| **OD-2** | **Cursor_Downloads (861) + unknown (126):** approve content-classify-or-honest-null (fail-closed, folder never assigns exam)? Fund a manual review of the ambiguous queue? | Approve fail-closed content classification. Manual review **optional** — the ambiguous queue is exported for the owner; unresolved stays honest-null (excluded, not guessed). |
| **OD-3** | **Difficulty:** ship interim **structural-proxy** difficulty (labelled, not measured) in v2, or hold difficulty entirely honest-null until pilot response data (R5-5)? | Compute + **label** structural-proxy difficulty on `pyq_item`, but keep the `exam_distribution` difficulty dimension **`curated_prior` until pilot** — no fabricated "measured difficulty." |
| **OD-4** | **Versioning:** confirm v2 **supersedes-by-versioning** (v1 preserved, never mutated) and that any product "exam-representative" claim now **gates on v2**. | **Yes** — freeze-as-versioning; v1 retained as the honest baseline; v2 is the measured layer. |
| **OD-5** | **Small-sample floor:** the minimum measured N (papers and items per exam×subject×chapter cell) below which a weight is honest-null / `insufficient_n` rather than "measured." | Owner sets the floor (illustrative: ≥ 3 papers **and** ≥ 8 items per cell). Below floor → honest-null or labelled v1 fallback. **Given ~188 docs, many fine-grained cells WILL be honest-null — this is expected and honest.** |
| **OD-6** | **Marking scheme:** when a specific paper doesn't state its scheme, use the **published official** scheme (`provenance_class='published'`) or honest-null? | Use the **published official** scheme with `provenance_class='published'`; parse per-paper when stated (`parsed_from_paper`); honest-null only if neither exists. |
| **OD-7** | **Freeze-hatch:** does re-mining need the deferred R3-4 FTS5 / `chunks(doc_id,ordinal)` index rebuild (which would mutate frozen v1.5 `kie.db`)? | **No** — the existing `chunks` + `chunks_fts` + `idx_chunks_doc` suffice for a purely-derived pass. Keep the freeze intact. |
| **OD-8** | **Evidence sufficiency:** is ~188 owned PYQ docs an acceptable measurement base, or acquire more PYQ *before* publishing measured DNA? (Board expansion = evidence acquisition, not engineering.) | Proceed with the owned corpus; publish measured DNA **only for cells that clear the OD-5 floor**, honest-null elsewhere. Surface a coverage report so the owner can decide whether to acquire more. |

---

## STOP

The engineering discovery and plan is complete. **Program B implements nothing until the owner explicitly
approves this plan** (and, with it, decisions OD-1…OD-8). On approval, execution begins at milestone **B1**
in a controlled session, milestone-by-milestone, each independently verified and EOS-gated, on the frozen
substrate — building the measured, provenance-linked, honest-null PYQ knowledge corpus that becomes the
authoritative evidence foundation for future Question Intelligence.
