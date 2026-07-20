# ⛔ RETIRED — broad-crawl acquisition (superseded 2026-07-09)

The broad website crawler in this directory (`crawl.py`, `discovery.py`,
`frontier.py`, `fetch.py`, `manifest.py`, `verify.py`) implemented the
**old acquisition strategy: crawl official sites and download every discovered
PDF**. That strategy was **abandoned by owner decision on 2026-07-09.**

Why it was retired:

- It optimised for **maximum PDF count**, not curriculum coverage.
- Its last run verified 1,714 PDFs but **only 4 were classified to a real
  class + subject** — 1,710 were `Unclassified/General` (mostly syllabus dumps,
  circulars, notifications). ~0% of the canonical class×subject matrix.
- It pulled non-curriculum noise (circulars, notifications, tenders,
  administrative documents) that the project does not want.

**Do NOT run these scripts.** The code is kept for reference only.

## Replacement — deterministic, matrix-driven acquisition

The acquisition strategy is now **deterministic** and walks the canonical
curriculum matrix only:

```
Board → Class → Subject → Document Type → Download → Verify → Store → Update coverage
```

Only resources that belong to the canonical matrix are acquired
(syllabus, textbook, teacher-guide, blueprint, question-bank, sample-paper —
Priority-A/B). Circulars, notifications, tenders, and administrative documents
are ignored by design (Priority-C, `null` coverage target).

Entry points (this is what runs now):

- Source resolvers (official pages, organised by class+subject):
  `scripts/discovery/ncert_catalogue.py`  (CBSE textbooks)
  `scripts/discovery/cbse_catalogue.py`   (CBSE syllabus)
  `scripts/discovery/ap_catalogue.py`     (AP SCERT textbooks)
  `scripts/discovery/cisce_catalogue.py`  (CISCE / ICSE)
- Deterministic worklist: `DOWNLOAD_QUEUE.json` (one cell per matrix resource)
- Downloader + certified V1–V11 verifier: `scripts/download/downloader.py`
- Continuous service: `scripts/acquisition/run_acquisition.py`
- Coverage matrix (progress = coverage, not PDF count):
  `scripts/reports/coverage_matrix.py`
