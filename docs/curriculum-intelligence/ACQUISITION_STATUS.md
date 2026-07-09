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

Acquisition is complete **only when that matrix is filled**. **Authoritative status (`curriculum/reports/COVERAGE_MATRIX.md`): 10.1% — 74 / 736 verified cells.** By board: CBSE 14.8% (26/176), TS 12.5% (20/160), AP 6.9% (11/160), CISCE 7.1% (17/240). **653 cells UNRESOLVED** (no source resolved yet — NOT yet "Missing"). The lane has **CONVERGED at 10.1%** on currently-resolved sources; raising coverage needs source-ladder expansion (official→mirror→third-party) for the unresolved cells, then a fresh lane pass. *(The retired broad crawler's PDF counts — CBSE 2225 etc. — are NOT the metric; the Coverage Matrix is.)*

## In progress (separate curriculum lane — do NOT interfere)
A **deterministic, matrix-driven acquisition service** (`scripts/acquisition/run_acquisition.py`) fills the matrix — it builds a queue of matrix cells and acquires toward per-cell coverage. It has **CONVERGED at 10.1%** on currently-resolved sources (stopped; no actionable work left). Further coverage = expand the source ladder for the 653 unresolved cells → fresh lane pass. This lane owns `curriculum/` acquisition state; other lanes must not touch it (do not interrupt/replace/spawn-another). Repository completeness is judged by that lane's matrix-coverage report, not by the retired crawler's `1728 verified` engine count.

## Reporting rule
Wherever acquisition status is shown (roadmap, dashboard, registry, memory): say **"Acquisition engine complete; curriculum repository still incomplete (matrix coverage pending)."** Never "acquisition complete".
