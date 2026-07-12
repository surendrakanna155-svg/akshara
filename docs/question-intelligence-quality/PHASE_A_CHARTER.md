# Phase A — Foundations Charter (owner-approved 2026-07-12)

**Status:** APPROVED and IN PROGRESS. **Yield gate RETAINED** (owner, 2026-07-12).
**Governs:** `OPUS_FABLE_RECONCILIATION_RECORD.md` §4/§6, `QUALITY_FIRST_IMPLEMENTATION_ROADMAP.md`,
`PHASE0_EVIDENCE_REPORT.md`.

## Approval + standing gate
- Owner verdict: **"QUALITY ARCHITECTURE PROVEN. YIELD NOT YET PROVEN. APPROVE PHASE A WITH YIELD GATE
  RETAINED."** Phase A is funded; Phases B–F are **not**.
- **Retained yield gate (hard, blocks Phase-B scaling):** ≥ **8 distinct-lane Item Models per subject**, each
  distilled from ≥ **5 DNA** from ≥ **2 resources**, measured on **full-corpus** mining **after** concept-
  canonicalization — re-tested at the Phase-B benchmark. Phase-0/0b measured 2/1/0/0 → 7/6/7/7 nominal
  (~5/2/4/6 genuine after removing OCR-junk pseudo-concepts). **This gate is not waived; it moves to Phase B
  on the cleaned, full corpus.** No scaling until it clears.

## Guardrails (non-negotiable for all Phase-A work)
1. **Frozen runtime engine.** `kie/qpgen/` behavior is unchanged in Phase A. The 8-surface engine-v2 seam
   lands **inert** (additive fields only; the frozen `qp_output_audit` matrix stays green; golden tests pass)
   and is a separately-reviewed change set — not smuggled in with foundation code.
2. **Isolation.** The new offline quality layer lives in a **new package `kie/qie/`** (Quality Intelligence
   Engine) with its **own local store `qie.db`** — separate from the certified `kie.db`. Foundation work never
   writes engine tables.
3. **Local-only derived knowledge.** DNA / Item Models / KVS / generated instances stay gitignored per the
   storage decision; only **code / schema / tests / docs / evidence reports** are committed.
4. **Reversible + evidenced.** Any operation that would mutate the certified `kie.db` (e.g. concept
   canonicalization) is done as an evidenced, reversible curate operation with a backup and a
   candidate-report-first step — never a blind in-place edit.
5. **EOS gate per slice.** Each slice is verified and gate-checked before it is called done.
6. **Benchmark-gated, not endpoint-gated.** No quality claim without blind-review evidence; teacher validation
   still mandatory before any production/market claim.

## Phase-A slice plan (each independently reviewable; stop-and-review between)
- **A0 — Foundation scaffold — ✅ DONE (2026-07-12).** `kie/qie/` package built: `lanes.py` (11-lane
  taxonomy + per-lane verification strategy), `relations.py` (relation library v0, 56 relations, independent
  `verify()`; validated on real corpus at 60% in Phase-0b), `store_schema.sql` + `store.py` (isolated `qie.db`
  with DNA / item_model / distractor_dna / KVS / generated_item / concept_canon_ledger tables; item_model
  carries `n_dna`/`n_resources`/`concept_scope` for the retained yield gate), `concept_canon.py`
  (candidate identifier). **27 new unittests green; 26 existing engine tests still green; `qpgen/` + `kie.db`
  untouched; `qie.db` gitignored.** Concept-canon run on the real DB → **59 candidates** (42 auto-quarantine
  = 30 ocr_junk + 12 section/question fragments; 17 prefix/domain mismatches → **review**, not auto-reject),
  written to `qie.db` with `applied=0` (kie.db NOT mutated). Evidence:
  `phase0_evidence/concept_canon_candidates.json`. EOS gate: **PASS**.
- **A1 — Baseline snapshot + benchmark harness — ✅ DONE (2026-07-12).** Immutable baseline captured
  (`phase0_evidence/qp_baseline_PhaseA_2026-07-12.json`; matches the frozen engine exactly — print coverage
  21.0%, clone 272/357, teacher_ready_full_paper=0 — so all later deltas are attributable). Gold-benchmark
  harness promoted to `kie/qie/benchmark.py` (blind-packet builder, Krippendorff-α, per-engine medians/lift/
  majority-direction, PRE-REGISTERED thresholds as constants: absolute-bar ≥4, lift ≥1.0, α floor 0.6;
  `evidence_kind` + `teacher_validation_required` so proxy evidence is never mislabelled). **9 new tests;
  the harness reproduces the Phase-0b verdict EXACTLY on the real judge data** (passed=True, all 4 lift dims,
  identical α). 36 QIE tests + 35 existing tests green; engine untouched. EOS gate: **PASS**.
- **A2 — Concept canonicalization (execution) — ✅ DONE (2026-07-12).** `kie.db` backed up
  (`kie.db.bak-phaseA2-20260712`, local). Reversible `apply_quarantine`/`rollback` (per-row `prior_status` +
  full backup) quarantined the **42 auto-reject** candidates (OCR-junk + section/question fragments incl.
  `BIO_CHOOSE_THE_COR`); the **17 prefix/domain-mismatch candidates were NOT touched** (owner instruction).
  Active concepts 1736 → **1694** (−42). Post-canon audit: engine still behaves — served 54, refused 3,
  printable-clean 51, all integrity gates 0, teacher_ready_full_paper 0, coverage 21.0→21.1; clone ticked
  272→277 (minor, expected — smaller pool; a Phase-D diversity concern, not a canon regression, no gate
  weakened). 4 apply/rollback tests green. Evidence: `phase0_evidence/qp_postcanon_A2_2026-07-12.json`.
  EOS gate: **PASS**. Reversible via `concept_canon.rollback()` + the backup.
- **A3 — KVS v0 seed — ✅ DONE (2026-07-12).** `kvs_seed.py` seeds the assertion base / taxonomy from
  `concept_edges` + `reference_facts`, **filtered against post-canon active concepts** (so A2's quarantine
  keeps junk out of the KVS — concretely, **235 edges skipped** for touching quarantined concepts). Seeded
  **1,684 assertions** (1,419 edge + 265 reference-fact) + 131 taxonomy rows into local `qie.db`. **Honest v0
  finding: 0 are promotable** (`evidence_count ≥ 2`) — the raw material (single-source edges + bare law-name
  facts) cannot yet back non-numeric verification; a real KVS needs dedicated **multi-source mining (Phase B)**.
  4 tests green. The relation library (numeric backbone) was delivered in A0. Evidence:
  `phase0_evidence/kvs_v0_seed_A3.json`. EOS gate: **PASS** (plumbing correct + tested; thinness reported).
- **A4 — E-lite ingestion boundary — ✅ DONE (2026-07-12).** Built as an **additive extractor**
  (`elite_ingest.py`) that runs ALONGSIDE the frozen phase2/phase4 (does NOT modify them): detects
  question/option/answer/solution boundaries (numbering + option-marker + `Answer(n)` regex, validated on
  real corpus in Phase-0b) and preserves the images/equations/tables (incl. LaTeX) that phase4 currently
  drops, with page/bbox provenance, into new `qie.db` `elite_question` / `elite_visual_asset` tables. So the
  ~200–300 incoming board PDFs can be ingested without silently losing structure. 4 tests green; frozen
  ingestion phases untouched. EOS gate: **PASS**.
- **A5 — Inert engine-v2 seam:** additive `QuestionSlot` fields (`item_model_id`, `lane`, `difficulty_drivers`,
  `gate_verdicts`, `solution_steps`), a gate slot in `validate.py`, a lane/archetype hook in `select.py` — all
  inert, matrix green. Separately reviewed.

**Phase-A exit:** benchmark harness runs; `qie.db` schema migrated; relation library + KVS v0 cover the first
benchmark slice; concept canonicalization done with evidence; engine-v2 seam merged inert with the matrix
unchanged. **No question-quality claim yet** (that is Phase B, behind the retained yield gate).
