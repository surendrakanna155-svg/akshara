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
| **B2** | Exam + subject + concept re-attribution | ⬜ |
| **B3** | Question re-mining with deterministic provenance chain + OCR fail-safe | ⬜ |
| **B4** | Structural difficulty (labelled) + marking-scheme extraction | ⬜ |
| **B5** | `exam_dna_v2` measured layer (N≥30 floor, v1 preserved) | ⬜ |
| **B6** | Integration (blueprints surface provenance_class; exam-representative gates on v2) + final EOS | ⬜ |

---

<!-- Milestone entries are appended below as each is executed. -->

## B1 — Corpus role classification (`pyq_source_class`) · 2026-07-22

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

**Honest limitations (stated):** subject is deliberately NOT pinned at the doc level for full papers
(`multi_subject_defer`) — it is resolved per-question from section headers at B2/B3 (OD-4). Practice/mock exams
are attributed for completeness but excluded from DNA (OD-1). 40 `unknown`-role + 78 honest-null-exam docs remain
honest-null, never guessed.
