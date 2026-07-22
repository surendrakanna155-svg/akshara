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
