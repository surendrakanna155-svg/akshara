# Question-Corpus STAGING Lane — NON-CERTIFIED · NON-PRODUCTION

This directory is a **loss-minimising staging evidence base** produced from third-party
educational PDFs (JEE/NEET DPPs, chapterwise banks, previous papers) under
`curriculum/resources/foundation/Cursor_Downloads/`.

```
RAW DOCUMENT  ->  LOSS-MINIMISING EXTRACTION  ->  STRUCTURED STAGING CORPUS
```

It is **not** certified content, **not** production data, and is **never** merged into the
active KIE database (`curriculum/knowledge/kie/kie.db`), the Phase-0 corpora, `kie/qpgen/`, or
the Certified Question Bank. It exists only for extraction, preservation, provenance, and
later architecture-approved assessment-structure analysis.

Everything here is **local-only** and gitignored (`curriculum/.gitignore` → `staging/`).

## What runs this

Code lives at `curriculum/scripts/staging/qcorpus/` (committable). It **reuses** the proven
in-repo parser (`kie.phase2_parse.parse_pdf_file` — PyMuPDF primary, pdfplumber tables,
detection-first Tesseract OCR) as the extraction primitive, but writes to this isolated
staging tree instead of the KIE DB. See `benchmark/PARSER_ROUTING_BENCHMARK.md` for the
parser-route decision (why we did **not** install Docling/MinerU/Marker).

```
# from curriculum/ (venv = curriculum/.venv, py3.14):
PYTHONPATH=scripts/staging:scripts/intelligence .venv/bin/python -m qcorpus.cli <cmd>

inventory   filesystem inventory only
benchmark   parser-route benchmark on a representative slice
biology     Priority-1 (StudentBro Biology) + checkpoint
run         full corpus in priority order (RESUMABLE — re-run to resume)
manifests   rebuild derived JSONL manifests from per-doc records
report      regenerate BIOLOGY_PRIORITY_CHECKPOINT.md + OCR_AND_EXTRACTION_REPORT.md
gate        isolation + integrity gate (KIE DB / Phase-0 hashes unchanged)
```

## Layout

| path | contents |
|---|---|
| `state/processing_state.json` | global resumable state (atomic writes) |
| `state/docs/<doc_id>.json` | one crash-safe record per document (state machine) |
| `state/isolation_baseline.json` | KIE-DB / Phase-0 hashes captured at first run |
| `raw/<doc_id>.json` | RAW parser output, written once, **never overwritten** |
| `normalized/<doc_id>.json` | normalized text + additive `search_text`, questions, assets, equations, notation |
| `assets/<doc_id>/` | extracted raster images (watermarks de-duplicated) |
| `manifests/*.jsonl` | derived manifests, rebuilt atomically from records |
| `reports/*.md` | Biology checkpoint + final OCR/extraction report |
| `benchmark/` | parser-route benchmark + report |

`doc_id = sha256(file)[:16]` — the same content-addressed identity the KIE store uses, so a
document has one stable processing identity across crashes/resumes and byte-identical copies
collapse to one doc (exact-duplicate detection).

## Isolation & integrity guarantees

- The active KIE DB and Phase-0 pre-registration are **hash-verified unchanged** before/after
  every run (`qcorpus.cli gate`). Importing the reused parser does not open `kie.db`.
- RAW extraction is preserved separately from NORMALIZED; normalization never overwrites raw
  evidence. Notation repairs are **additive** (`search_text`); ambiguous notation is flagged
  `FORMULA_UNCERTAIN`, never silently changed.
- Answers/solutions are linked **only where present in the source** — none are fabricated.
- Source PDFs are read-only and stay gitignored/uncommitted.

## Explicitly NOT done here

No Question DNA mining, no Item Model construction, no question-family registration, no
question generation, no certification, no production merge. Those happen later, only under the
approved Question Intelligence architecture and only with explicit owner approval.
