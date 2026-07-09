# Acquisition Status — canonical terminology (owner correction 2026-07-09)

> **"Acquisition engine complete. Curriculum repository still incomplete."**

Do **NOT** describe acquisition as "complete". The distinction is deliberate:

## ✅ Acquisition ENGINE — complete (proven)
The crawler/acquisition mechanism works and is proven:
- Clean, correct run: 3 no-new cycles + frontier drained; **1,728 verified / 2,323 discovered**.
- **Integrity proven:** only 2 verified-not-on-disk (down from 1,172 in the pre-fix collision run) — the filename-collision, stale-dedup, and completion-detector fixes all hold.
- 1,710 PDFs / 6.8 GB / 1,714 distinct contents; 14 genuine duplicates deduped.

## ⚠ Curriculum REPOSITORY — still INCOMPLETE
The **only** success criterion for "acquisition complete" is the canonical coverage matrix:

```
Board  →  Class  →  Subject  →  Document Type
```

Acquisition is complete **only when that matrix is filled**. It is not, today:
- **Board coverage skewed:** CBSE ~2,225 verified; **AP 81, TS 17 (thin); CISCE 0 (missing entirely).**
- **Per-cell completeness unverified:** class × subject × document-type cells are not all covered.
- 346 download-failures (NCERT 403s, retry-exhausted) = unavailable-with-evidence, not covered.

## In progress (separate curriculum lane — do NOT interfere)
A **deterministic, matrix-driven acquisition service** (`scripts/acquisition/run_acquisition.py`) is running to fill the matrix — it builds a queue of matrix cells (~139) and acquires toward per-cell coverage. This lane owns `curriculum/` acquisition state; other lanes must not touch it. Repository completeness is judged by that lane's matrix-coverage report, not by the crawler's `1728 verified` engine count.

## Reporting rule
Wherever acquisition status is shown (roadmap, dashboard, registry, memory): say **"Acquisition engine complete; curriculum repository still incomplete (matrix coverage pending)."** Never "acquisition complete".
