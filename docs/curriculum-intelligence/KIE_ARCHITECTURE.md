# Knowledge Intelligence Engine (KIE) — Canonical Architecture Blueprint

**Date:** 2026-07-10 · **Status:** approved implementation blueprint for the KIE build.
**Precedence (subordinate, never competing):** Engineering Constitution/EOS → **Assessment-Intelligence-Platform v3.0** (D1–D11, top law) → **AIMS** (Golden Rules 1–20, Concept/Family/Template model) → **MCIP** + Download-Verification addendum → this blueprint. This document does **not** create a new canon; it is the *deterministic local-processing implementation* that realizes v3.0/AIMS's offline asset-building layer and fills its green-field gaps (parser, chunking, local index, intake bridge). Ref: `KIE_IMPLEMENTATION_AUDIT.md`.

**Owner decisions binding this build:**
- **Scope:** primary corpus = JEE/NEET foundation (`curriculum/resources/foundation/`, 363 files, acquisition-complete); board-curriculum track ingestible later via the same engine. No further acquisition/crawling (locked).
- **Deterministic 1–7 now; Phase 8 (AI generation) WIRED but activation GATED** behind the owner's P3-AI lift. AI concept-tagging (Phase 5) is likewise gated; the deterministic path is the default and must stand alone.
- **Local-only outputs** (storage lock): derived knowledge lives on local disk (gitignored); git carries only engine code, schemas, tests, configs. Promotion to Postgres is a later, human-gated Intake step.
- **Original-content-first / copyright-safe (D8, Rule 7):** PYQs are analysis-only (L2, never reproduced); the engine stores *patterns/structure/metadata*, never copied question text into shippable assets.
- **Deterministic/AI target (NEW KIE target, stated here):** ≥90% of pipeline value is deterministic; ≤10% is offline, small-chunk, gated AI. Never send a whole book/PDF to a model (v3.0 line 200).

---

## 1. Repository structure

Engine code (committed) under `curriculum/scripts/intelligence/kie/`; outputs (local-only, gitignored) under `curriculum/knowledge/kie/`.

```
curriculum/scripts/intelligence/kie/          # COMMITTED (code + tests + schema DDL)
  __init__.py
  config.py            # paths, thresholds, corpus selection (foundation|board)
  store.py             # local SQLite store (open/migrate/txn), schema in schema.sql
  schema.sql           # local DDL — MIRRORS the Postgres edu_* shapes + adds source_documents/chunks
  ledger.py            # per-(doc,stage) idempotent checkpoint ledger
  phase1_verify.py     # Repository Verification + D-5 certification gate (wraps repository_verifier)
  phase2_parse.py      # PyMuPDF text · pdfplumber tables · Tesseract OCR (scanned)
  phase3_metadata.py   # document + section metadata (extends knowledge_base_prep)
  phase4_chunk.py      # structural chunker
  phase5_concept.py    # deterministic concept extraction (+ gated small-chunk AI hook)
  phase6_graph.py      # Concept Graph builder (canonical_concepts + concept_prerequisites)
  phase7_questions.py  # Question Intelligence (patterns/difficulty/Bloom/trends from PYQs)
  phase8_generate.py   # AI family/template generation — GATED (raises if AI not authorized)
  intake.py            # Knowledge Intake Center: local→review→promote to Postgres edu_*
  cli.py               # `python -m ...kie.cli <phase> [--corpus foundation] [--resume]`
  tests/               # unittest, synthetic PDFs (reuse common/workspace.make_sample_pdf)

curriculum/knowledge/kie/                      # LOCAL-ONLY (gitignored)
  kie.db               # SQLite: documents, chunks, concepts, edges, questions, ledger, fts, vectors
  parsed/<doc_id>.json # normalized per-document parse output (text + tables + blocks)
  reports/             # KIE_*_REPORT.md per phase
```

Reuse verbatim: `repository_verifier.py`, `verification_engine._verify_pdf/_sha256`, `metadata_tools`, `common/workspace.py`, `common/coverage.py`, `configs/*.json`.

## 2. Processing pipeline (deterministic-first)

```
PDF/ZIP  → [P1 verify+certify] → [P2 parse: text|table|OCR] → [P3 metadata] →
[P4 chunk] → [P5 concept-extract (det. + gated AI)] → [P6 concept graph] →
[P6b local search/vector index] → [P7 question intelligence] → [[P8 AI generation — GATED]]
                                                                        ↓
                                                        [Intake Center → Postgres edu_*]
```
Each arrow is idempotent and checkpointed (§9,§11). A stage reads only the prior stage's committed output from `kie.db`; nothing re-runs unless the source checksum changed (§14). Rule 200: deterministic tooling parses everything it can; AI only ever sees a **single small chunk**, never a document.

## 3. Metadata schema

Two levels, both reusing existing shapes:
- **Resource-level** — reuse `configs/metadata_schema.json` + `metadata_tools.validate`. The engine *populates* the dormant `knowledge_base_prep` block (`chapters`, `topics`, `learning_outcomes`, `bloom_classification`, `competency_mapping`) as P3/P5 complete — moving it from `PENDING_EXTRACTION` to real values.
- **Document-level (KIE, local)** — `source_documents` table: `doc_id` (sha256-derived stable id), `corpus` (foundation|board), `abs_path`, `rel_path`, `sha256`, `bytes`, `pages`, `parser_class`, `parser_strategy`, `board`, `exam` (JEE_Main|JEE_Advanced|NEET|AIIMS|NCERT|…), `subject`, `class_label`, `doc_type`, `year`, `language`, `license_status`, `verify_status`, `certify_status`, `created_at`. Provenance is mandatory (Rule 13 traceability).

## 4. Chunk schema

`chunks` table (local): `chunk_id` (`<doc_id>#<ordinal>`), `doc_id` FK, `ordinal`, `page_start`, `page_end`, `char_start`, `char_end`, `block_type` (`heading|paragraph|list|table|figure_caption|question|option|solution|formula|example`), `section_path` (e.g. `Ch3 › 3.2 › Worked Example`), `text`, `token_est`, `sha256`, `lang`. Chunking policy: **structure-aware, not fixed-width** — split on detected headings/blocks (PyMuPDF span/font analysis + pdfplumber layout), keep tables/questions/solutions atomic, target ≤~512 tokens with heading-anchored overlap. This is green-field (audit §2) — no frozen spec constrains it.

## 5. Concept schema (mirrors Postgres `canonical_concepts`)

Local `concepts` table mirrors `canonical_concepts` exactly so Intake is a 1:1 promote: `concept_code` (permanent, `<SUBJECT>_G<grade>_<domain>_<slug>_<nnn>`), `title`, `definition`, `subject_domain`, `typical_grade_range`, `bloom_levels`(json), `difficulty_range`(json), `curriculum_boundary`(json), `foundation_boundary`(json), `common_misconceptions`(json), `reference_facts`(json: formulas/laws/theorems/definitions), `status`, `merged_into`, `evidence`(json: chunk_ids + method + confidence). Rule 2: every downstream asset references ≥1 `concept_code`.

## 6. Knowledge Graph schema (= AIMS Concept Graph; mirrors `concept_prerequisites`)

Local `concept_edges` table mirrors `concept_prerequisites`: `from_concept`, `to_concept`, `relationship_type` (`prerequisite|parent_child|related|confused_with`), `strength`, `notes`, `evidence`(json). **Not a second graph** (audit recon #2). DAG/cycle validation for `prerequisite` edges enforced in code (as the Postgres design expects). `concept_board_mappings` mirror table maps a concept into board/exam trees with `alignment` (exact|partial|extends) — this is how JEE-depth vs Class-scope is expressed without merging trees.

## 7. Database tables

- **Local (SQLite, `kie.db`)** — source of truth during processing: `source_documents`, `chunks`, `concepts`, `concept_edges`, `concept_board_mappings`, `formulas`, `question_patterns`, `question_families`, `question_templates`, `distractors`, `generated_items`, `stage_ledger`, `chunks_fts` (FTS5), `chunk_vectors` (optional/gated). Schemas mirror the Postgres `edu_*` columns 1:1 wherever a promotion target exists.
- **Postgres (Supabase)** — **reuse the existing dormant tables as-is** (`canonical_concepts`, `concept_prerequisites`, `concept_board_mappings`, `edu_question_families/templates/distractors`, `edu_question_bank_items`). **No new prod migration for chunks/source-docs/vectors** — those stay local (storage lock; `pgvector` timing-locked to v3.0 Phase-3 per TD-CI-12). The only Postgres writes happen through the Intake Center (§15), human-gated, into existing tables.

## 8. Vector Index schema

- **Default (committed, deterministic):** SQLite **FTS5** over `chunks.text` → BM25 lexical retrieval + concept/section filters. Zero heavy deps, fully deterministic, reproducible.
- **Optional (gated, local-only):** `chunk_vectors(chunk_id, dim, vec BLOB)` populated by a *local* embedding model (sentence-transformers), cosine via numpy. Embeddings are an AI surface → **behind the same gate as Phase-5 AI**; the deterministic FTS5 path must fully function without it. No production `pgvector` (locked).

## 9. Processing workflow

Per-document, per-stage, idempotent: `stage_ledger(doc_id, stage, status[pending|done|failed|skipped], input_sha256, output_ref, error, updated_at)`. A phase processes only docs whose ledger row for that stage is absent/failed or whose `input_sha256` changed. `--resume` continues; `--force` re-runs. Batch is per-doc parallel (multiprocessing pool) since docs are independent. Corpus selected via `--corpus foundation|board` (default foundation).

## 10. Error handling

Per-doc `try/except` isolates failures — one bad PDF never aborts the batch. Every failure writes `status=failed` + typed `error` (`PARSE_ERROR|OCR_FAILED|CORRUPT|ENCRYPTED|BOUNDARY_VIOLATION|LOW_CONFIDENCE`) to the ledger and continues. Boundary violations (content beyond curriculum scope) and low-confidence extractions are **quarantined, never stored as certified** (Rule 6, boundary "never store violations"). Zero fabrication: missing data stays honestly empty (I4).

## 11. Recovery checkpoints

Two layers: (a) the SQLite `stage_ledger` (fine-grained, resume mid-phase); (b) `PROJECT_STATUS.json:kie_phaseN` + a `KIE_<phase>_REPORT.md` snapshot at each phase end. **Per mission rule, every phase that compiles + passes tests becomes a git commit = a recovery checkpoint.** A crash resumes from the ledger with no recomputation of `done` rows.

## 12. Performance strategy

Deterministic + local + embarrassingly parallel per doc. Incremental by checksum (§14) — steady state reprocesses only changed docs. NEW KIE targets (stated, not pre-existing): text-extract ≥5 docs/s/core; OCR bounded to the 93 flagged scanned files (rasterize at 300dpi, page-parallel); full 363-doc cold build < ~30 min on a laptop; re-runs O(changed). Caching: parsed output persisted to `parsed/<doc_id>.json` so P3+ never re-parse.

## 13. Testing strategy

`unittest` (repo convention), run under `curriculum/.venv`: `.venv/bin/python -m unittest discover -s curriculum/scripts/intelligence/kie/tests -v`. Each phase ships: unit tests (synthetic byte-correct PDFs via `common/workspace.make_sample_pdf`, extended with text/table/scanned fixtures), a schema round-trip test (local↔mirror parity), and a small **golden end-to-end** fixture (a tiny synthetic "textbook" → expected chunks/concepts/edges). Determinism test: same input → byte-identical `kie.db` rows (stable ids, sorted writes). No network, no real copyrighted PDFs in tests. Every phase must be green before the next (mission IMPLEMENTATION RULES).

## 14. Incremental update strategy

On re-run: recompute each doc's `sha256`; unchanged → skip (ledger `done`). Changed/new → reprocess that doc and cascade only its dependent rows (its chunks → its concepts' evidence → affected edges), emitting a `KIE_IMPACT_REPORT.md` (docs added/changed/removed, concepts touched). Maps to wave CI-C9. Concept `merged_into` handles dedup over successive runs without deleting history.

## 15. Knowledge Intake Center integration

The bridge from local KIE knowledge to the production ERP, honoring D-5/D-6 and Rule 9 (teacher authority):
1. **Package** — `intake.py` selects local rows at a chosen trust level (e.g. concepts with evidence ≥ threshold) and renders a human-reviewable **Intake Package** (concepts, edges, families, sample instances, provenance).
2. **Review** — a human (teacher/curriculum owner) approves/edits (Rule 9 overrides the engine). No auto-promotion.
3. **Promote** — approved rows are written into the existing dormant Postgres tables (`canonical_concepts` → `concept_prerequisites` → `concept_board_mappings` → `edu_question_families/templates/distractors`; certified deterministic instances → `edu_question_bank_items` with `trust_status` per D-6). Promotion is additive, RLS-scoped, and idempotent (upsert by `concept_code`/`*_code`).
4. **Deterministic unlimited generation** — once certified families/templates exist in Postgres, the *existing* deterministic engine (CI-C1/C3/C7/C8 solver + item rotation) instantiates unlimited solver-checked original instances **with no runtime AI** (v3.0 §419, I9 direction). This is how "unlimited original JEE/NEET questions" is delivered under the Phase-8 gate.

---

## Phase → deliverable map (each: compile → tests → new tests → checkpoint → commit)
1. **Repository Verification** — `store.py`+`schema.sql`+`ledger.py`+`phase1_verify.py` (wrap `repository_verifier`, add D-5 certification gate) + tests.
2. **Parser** — `phase2_parse.py` (PyMuPDF/pdfplumber/Tesseract, routed by `parser_strategy`) + tests + deps.
3. **Metadata Engine** — `phase3_metadata.py` (doc + section metadata, populate `knowledge_base_prep`) + tests.
4. **Chunking Engine** — `phase4_chunk.py` (structure-aware) + FTS5 index + tests.
5. **Concept Extraction** — `phase5_concept.py` (deterministic term/formula/definition mining; gated AI hook off) + tests.
6. **Knowledge Graph** — `phase6_graph.py` (concepts → edges, DAG validation, board mappings) + tests.
7. **Question Intelligence** — `phase7_questions.py` (PYQ pattern/difficulty/Bloom/trend mining → family/template skeletons; analysis-only, original) + tests.
8. **AI Question Generation** — `phase8_generate.py` present but **raises `AiGenerationGatedError` unless `KIE_AI_AUTHORIZED`**; deterministic instantiation of certified families is the shipping path.
