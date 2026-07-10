# Knowledge Intake Center — Certification Report

**Date:** 2026-07-10 · **Status:** ✅ implementation-complete · **Scope:** incremental
ingestion for the Knowledge Intelligence Engine (KIE).
**Package:** `curriculum/scripts/intelligence/kie/intake/` (11 files, ~1.4k LOC) ·
**Tests:** 38 intake tests, part of **116/116** green KIE suite · **Env:** `curriculum/.venv`
(py3.14), stdlib + PyMuPDF/pypdf (reused).

The Knowledge Intake Center is the **single entry point** for introducing new knowledge
into the KIE. The processed **360-document repository is the immutable, certified
baseline** ([FULL_REPOSITORY_PROCESSING_REPORT.md](FULL_REPOSITORY_PROCESSING_REPORT.md),
16/16 verification). The Intake Center processes **only new / modified / newer-version
files**, never the whole repository again, and orchestrates the **existing** deterministic
phases — it duplicates none of them.

---

## 1. Architecture

Local, deterministic, stdlib-first. It is an **orchestration layer over the frozen
`kie.phaseN` components**, plus a small set of **additive control tables** and a
**per-batch isolation** model.

```
kie/intake/
  __init__.py     public surface (enums + dataclasses)
  models.py       SourceKind · Disposition · ReviewStatus · BatchStatus · IntakeSource · ItemStats · IntakeItemView
  schema.sql      ADDITIVE control tables (core kie/schema.sql stays FROZEN)
  store_ext.py    apply_intake_schema() — idempotent, kept out of core migrate
  collector.py    normalize every supported input → IntakeSource (zip expand, folder walk, watch diff, URL stub)
  detect.py       verify (reuse RepositoryVerifier) + duplicate + version/lineage detection + baseline backfill
  pipeline.py     staging pipeline: reuse phases 2-7 on an isolated staging DB + per-doc review signals
  promote.py      additive staging→production copy + version records + derived (graph/questions) refresh
  center.py       IntakeCenter facade: batch lifecycle + review queue + decisions + watch
  report.py       live batch + queue reports
  cli.py          import / queue / show / approve / reject / refresh / watch / backfill-lineage / report / url
```

**Isolation model.** Each import is a **batch**. New files are processed through the full
pipeline in a **per-batch staging SQLite store** (`knowledge/kie/intake/staging/<batch>.db`)
that contains *only that batch's documents*. The certified baseline is never opened for
writing until a human approves an item; approval performs an **additive** copy into the
production store. This is what makes "only approved knowledge enters production" and
"never reprocess the repository" both true and enforceable.

**Control tables** live in the production `kie.db` alongside content but never modify it:
`intake_batches`, `intake_items` (the review queue — the reviewable unit is one source
document), `document_versions` (append-only version lineage), `watch_state`.

**Reuse (zero duplication).** Integrity+hashing = `repository_verifier` /
`verification_engine`; parse/metadata/chunk/concept/graph/questions = `kie.phase2..7`
verbatim; certification gate = `phase1_verify.classify`/`ingest_entry`; store/ledger =
`kie.store`/`kie.ledger`.

---

## 2. Workflow (the mission pipeline — nothing bypasses it)

```
Resource
  ↓  collect (normalize any input → files)
Integrity Verification      reuse RepositoryVerifier.verify_file  → verified | corrupt | encrypted
  ↓
Duplicate Detection         sha256 already in production KB?      → EXACT_DUPLICATE (skip)
  ↓
Version Detection           newer content for a known lineage?    → NEW_VERSION | NEW
  ↓  (stageable = NEW | NEW_VERSION only; corrupt/encrypted quarantined, never processed)
Parser → Metadata → Chunking → Concept Extraction   (per-doc, ledger-incremental, in staging)
  ↓
Knowledge Graph Update → Question Intelligence Update   (derived, over staging for preview)
  ↓
Review Queue                pending | needs_review  (auto-flags route the doubtful ones)
  ↓
Approval                    human gate — Rule 9 teacher authority
  ↓  (additive promotion + global KG/QI refresh over the combined corpus)
Production Knowledge Base
```

Every imported file becomes an `intake_item`; there is no code path that adds knowledge
to production except `approve → promote`.

---

## 3. Supported inputs

| Input | How | Notes |
|---|---|---|
| **Single PDF** | `import file.pdf` | |
| **Multiple PDFs** | `import a.pdf b.pdf …` | |
| **Folder Import** | `import folder/` | recursive; unsupported files ignored; category defaults to folder name |
| **ZIP Import** | `import bundle.zip` | container → member PDFs extracted as individual resources (zip-slip guarded); `.ecar` stays a single archive document |
| **Drag & Drop** | `import <mixed paths>` | files + folders, deduplicated by resolved path |
| **Local Watch Folder** | `watch folder/ [--once] [--interval N]` | content-hash diff vs `watch_state`; only new/modified files re-ingested |
| **Direct URL Import** | `url <URL>` | **placeholder only** — `url_import` raises `UrlImportNotImplemented`; the Center never downloads from the network |

All file inputs funnel through one collector (`collect_paths`), so the same verify → dedup
→ version → stage path applies uniformly.

---

## 4. Duplicate strategy

Two layers, both content-addressed (`doc_id = sha256[:16]`):

1. **Exact-content duplicate** — if the sha256 already exists in production
   `source_documents`, the file is marked `EXACT_DUPLICATE`, **skipped** (never re-parsed),
   and surfaced in the queue with the existing `doc_id`. This reuses all existing knowledge.
2. **In-batch / store-level collapse** — the store keys everything by `doc_id`, so identical
   content can only ever occupy one row; re-staging identical content is idempotent.

Corrupt / encrypted files fail the integrity gate → `QUARANTINED`, never processed
(D-5). Same-name / different-content files are *not* duplicates — they flow to version
detection.

---

## 5. Versioning strategy

**Never overwrite; preserve history.** A logical document has a deterministic
`lineage_key` (category + basename with year and session/shift/set markers stripped;
overridable per file for UI-linked versions). Version detection compares an incoming file
against the current **lineage head** in `document_versions`:

- new content for a known lineage → `NEW_VERSION`, `version_no = head+1`; on promotion the
  prior head's `superseded_by` is set to the new `doc_id` — **the old version's rows stay**
  (its chunks/concepts are never deleted). Both versions remain queryable; downstream can
  prefer the current head.
- unknown lineage → `NEW`, `version_no = 1`.

`document_versions` is **append-only**. `register_baseline_lineage()` (CLI
`backfill-lineage`) is a one-time, idempotent, additive backfill that registers the
pre-existing 360-doc corpus into the lineage table (chained old→new by year) so yearly
updates chain against the baseline — control-table writes only, content untouched.

---

## 6. Review workflow

The reviewable unit is one **source document** carrying its derived knowledge. Every item
has a review status: **`pending` · `needs_review` · `approved` · `rejected`** (plus
`skipped` for duplicates/quarantined, which are not reviewable).

- Auto-triage after staging: `parse_failed`, `low_ocr` (<60% confidence), `no_chunks`,
  `no_concepts` route an item to **`needs_review`**; clean extractions land **`pending`**.
- `show <item>` previews the item's provenance, per-doc stats (chunks/concepts/formulas/
  patterns), flags, and a sample of the concept titles it introduced (read from staging).
- **`approve`** → additive promotion into the production KB + a version record, then the
  Knowledge Graph + Question Intelligence update (deferrable with `--no-refresh` for bulk).
- **`reject`** → nothing is promoted; the decision is retained (history).
- Transitions are guarded: a rejected or duplicate/quarantined item cannot be approved; a
  batch auto-closes when all its items reach a terminal status.

**Only approved knowledge enters the production graph** — promotion is the only writer.

---

## 7. Incremental update strategy

- The 360-doc baseline is **immutable**: intake never runs the per-doc phases (parse/
  chunk/concept) on baseline docs — the staging store only ever contains the current
  batch's files.
- **Content-hash + ledger checkpointing** decide work: unchanged content is an exact
  duplicate (skipped); changed content is a new version. The per-doc phases in staging are
  `ledger.needs_run`-gated, so re-runs are O(changed).
- **Reuse existing metadata**: exact duplicates return the existing `doc_id` and are not
  reprocessed; the parsed cache (`parsed/<doc_id>.json`) is content-addressed and shared
  between staging and production, so promotion copies rows, never re-parses.
- **Promotion is additive and scoped to the new `doc_id`**: `INSERT OR IGNORE` /
  scoped-delete-then-insert. A `concept_code` shared with the baseline keeps the baseline
  row **verbatim** (proven by test). The FTS index stays in lockstep with chunks.
- The **derived layer** (concept graph, question intelligence) is the one thing recomputed
  globally on approval — the "Knowledge Graph Update" / "Question Intelligence Update"
  steps. This re-derives from already-parsed chunks (deterministic, no LLM, no re-parse);
  it is a projection over the corpus, not source content. *Trade-off:* related-edge
  re-ranking (phase-6 per-concept cap) means the derived graph reflects the whole corpus
  after each update — source rows are never regressed, but derived edges are refreshed by
  design. Documented and intended.

---

## 8. Yearly maintenance workflow

For the recurring NCERT / JEE Main / JEE Advanced / NEET releases — **without rebuilding
the repository**:

1. (once) `kie.intake.cli backfill-lineage` — register the baseline for versioning.
2. Each year: `import <new PDFs>` (or drop them into a watched folder). Files whose content
   matches a known lineage are detected as **`NEW_VERSION`** and staged in isolation.
3. Review the new versions in the queue; `approve` the good ones.
4. Promotion adds the new versions additively, supersedes the prior heads (history kept),
   and refreshes the graph + question intelligence over the combined corpus.

No prior year's knowledge is deleted or reprocessed; the new year is layered on top.

---

## 9. Future extension points

- **Direct URL Import** — the declared placeholder (`collector.url_import`). When an
  authorized offline-download channel exists, it plugs into the same collector → the rest
  of the pipeline is unchanged.
- **Concept-granular review** — today the reviewable unit is a document; the model supports
  narrowing to per-concept / per-family approval later.
- **Optional embeddings (gated)** — the FTS5 lexical index is the deterministic default;
  local vectors remain behind the same gate as Phase-5 AI.
- **Postgres promotion (D-5/D-6)** — the KIE Intake bridge (`intake.py` in
  `KIE_ARCHITECTURE.md §15`) promotes approved local rows into the dormant `edu_*` tables;
  this Center is the ingestion front-half feeding it.
- **Phase 8 (AI generation)** — remains feature-gated; the Center never invokes it.
- **Watcher as a service** — `poll_watch_folder` is a pure one-pass primitive; the CLI
  `watch --interval` loops it. A supervised daemon can wrap the same call.

---

## 10. Verification & guarantees (evidence)

| Guarantee | Enforcement | Test |
|---|---|---|
| Core schema / Phases 1-7 untouched | intake schema is additive, applied separately | `test_intake_schema` |
| Every input is recorded; nothing bypasses | `import_paths` writes an item per file | `test_intake_center::no_resource_bypasses` |
| Corrupt/encrypted never processed | D-5 quarantine gate | `test_intake_detect::quarantined` |
| Exact duplicate skipped (no reprocess) | sha256 vs production | `test_intake_center::exact_duplicate` |
| New version preserves history | append-only `document_versions` + supersede | `test_intake_promote::new_version` |
| Baseline rows never mutated | additive promotion; shared concept preserved verbatim | `test_intake_promote::preserves_baseline` |
| Only approved knowledge promoted | promotion is the only writer; guarded transitions | `test_intake_center::reject/cannot_approve` |
| Promotion idempotent; FTS lockstep | scoped OR-IGNORE / delete-then-insert | `test_intake_promote::idempotent` |
| Reuses frozen phases | staging runs `kie.phase2..7` | `test_intake_pipeline::reuses_frozen_phase_functions` |

**Regression:** full KIE suite **116/116 green** after every phase; the immutable
production `kie.db` (360 certified docs / 33 870 chunks / 2 548 concepts) was never
touched during development (all tests use temp stores).

**EOS gate:** PASS — additive, reuse-first, regression-safe; no P0s. Follow-on (non-code):
the standing yearly workflow is owner-operated; a supervised watch daemon is optional.

---

*This is the canonical ingestion system for the Knowledge Intelligence Engine. Subordinate
to Assessment-Intelligence-Platform v3.0 / AIMS; see
[KIE_ARCHITECTURE.md](../curriculum-intelligence/KIE_ARCHITECTURE.md).*
