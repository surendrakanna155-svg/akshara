# Curriculum Acquisition Strategy — CANONICAL (locked 2026-07-09)

The **deterministic Board → Class → Subject → Document Type** pipeline is the canonical
acquisition strategy. The broad crawler is retired (`scripts/crawler/RETIRED.md`).
Acquisition acquires ONLY canonical-matrix cells — no circulars, notifications, tenders,
recruitment, or administrative documents.

Pipeline: source resolvers (`scripts/discovery/*_catalogue.py`) → `DOWNLOAD_QUEUE.json`
→ `scripts/download/downloader.py` (V1–V11 verify, retry/backoff) →
`scripts/reports/coverage_matrix.py` → continuous service
`scripts/acquisition/run_acquisition.py`.

**The Coverage Matrix is the canonical progress indicator** (`reports/COVERAGE_MATRIX.md`).
Progress is coverage — verified cells ÷ expected cells — never a PDF count.

---

## Rule 1 — Source Priority (locked 2026-07-09)

Always acquire a resource in this order; only fall to the next tier when the current is
exhausted:

1. **Official board / government source** (e.g. ncert.nic.in, cbseacademic.nic.in,
   cse.ap.gov.in, scert.telangana.gov.in, cisce.org).
2. **Official government mirror** (e.g. diksha.gov.in, epathshala.nic.in, state mirrors).
3. **Trusted third-party source** (only when 1 & 2 fail).

If a third-party source is used it MUST:
- **Record provenance** — `provenance` + `license_status` + `license_note` on the queue
  entry and the resource metadata.
- **Be marked clearly** — tagged `UNOFFICIAL_THIRD_PARTY_COPY`; surfaced in the coverage
  report's provenance roll-up.
- **Keep looking for an official replacement** — listed under
  `provenance.third_party_awaiting_official_replacement`; re-checked on future discovery
  passes and swapped to an official source when one is found.

Current third-party exception: **Telangana (TS SCERT)** textbooks are Google-Drive copies
indexed by ncertbooks.guru (the official scert.telangana.gov.in exposes only encrypted
dynamic URLs). Owner-approved 2026-07-09; tagged, and awaiting an official replacement.

---

## Rule 2 — Coverage Matrix denominator (transparent, locked 2026-07-09)

The denominator is always shown. For every in-scope board:

```
expected_cells(board) = Σ over classes ( subjects in that class ) × (# Priority-A document types)
```

Priority-A document types (8): `syllabus, textbook, teacher_guide, learning_outcomes,
academic_standards, blueprint, question_bank, sample_paper`
(circulars / notifications / supplementary are Priority-C — excluded, `null` target).

| Board | Classes | Subject×Class pairs | × Doc-types | = Expected cells |
|---|---|---|---|---|
| CBSE | 5 (6–10) | 22 | 8 | **176** |
| APSCERT | 5 (6–10) | 20 | 8 | **160** |
| TSSCERT | 5 (6–10) | 20 | 8 | **160** |
| CISCE | 5 (6–10) | 30 | 8 | **240** |
| **TOTAL** | | | | **736** |

Dimensions are config-driven (`configs/boards.json` `subjects_by_class`,
`configs/classes.json`, `configs/quality_rules.json` `priority_categories`); the report
recomputes the denominator from config every run, so it can never silently drift.

Headline **coverage% = VERIFIED ÷ expected**. A secondary **accounted% = (VERIFIED +
DOCUMENTED_GAP) ÷ expected** adds evidenced gaps.

---

## Rule 3 — Missing resources (evidenced-only, locked 2026-07-09)

A resource is **never immediately marked Missing**. Cell states:

- `UNRESOLVED` — expected by the matrix, no source resolved yet. **Discovery is ongoing;
  this is NOT "Missing".** (Was mislabeled "Missing" before this rule.)
- `PENDING` / `RETRY_SCHEDULED` / `FAILED` — a source exists and is being worked through
  the recovery ladder (retry with backoff; try official mirrors via `alternative_sources`).
- `DOCUMENTED_GAP` — the **only** true "Missing": recorded `NOT_PUBLICLY_AVAILABLE` **with
  evidence**, and only after **official sources + official mirrors + known official
  repositories are all exhausted** (V1–V11 recovery ladder → `record_missing` with search
  history in `MISSING_RESOURCES.md`).

Escalation before a `DOCUMENTED_GAP`: exhaust official → official mirror → known official
repository (each attempt logged), then record the gap with supporting evidence.

---

## Rule 4 — Continue

The deterministic acquisition service runs autonomously in the background until the matrix
converges. ERP implementation runs independently in parallel — downloading never blocks
implementation and implementation never waits on downloading. The Coverage Matrix is the
canonical progress indicator.

---

## Rule 5 — Parallel agents + ERP independence (locked 2026-07-09)

**ERP and Curriculum are independent lanes.** Neither waits for the other.

Five acquisition agents run on **disjoint file ownership** (`acquisition/AGENT_MANIFEST.json`):

| Agent | Scope |
|---|---|
| 1 — CBSE | Remaining textbooks: Class 9 SST, Class 9/10 CS |
| 2 — CISCE | Classes 6–10 discovery + downloads |
| 3 — AP SCERT | Supplementary books (EVS, Readers, etc.) |
| 4 — Syllabus | Syllabus documents all boards |
| 5 — Assessment | Blueprint / sample paper / marking scheme |

**Service stop conditions** (only these):
1. Coverage Matrix fully accounted (VERIFIED + DOCUMENTED_GAP = denominator).
2. Owner explicitly stops acquisition.
3. `max-cycles` safety limit reached.

The service does **not** stop merely because the download queue is empty while UNRESOLVED
cells remain — discovery re-runs every cycle until sources are found or evidenced gaps recorded.

**Reporting:** meaningful milestones only (board completed, major coverage jump, new official
source, acquisition converged). No per-batch noise.
