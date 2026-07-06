# Download Verification & Recovery Engine — Canonical Specification

**Added by owner:** 2026-07-07 · Extends [`MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md`](MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md) Parts 03/04/08 (download validation, storage rules, metadata) with a mandatory verification & recovery engine.
**Status:** requirement is canonical; implementation delivered 2026-07-07 (see §5).

---

## 1. Principle

**Downloading a file does NOT mean the resource is complete.** Every downloaded resource must pass full verification before it is accepted into the production repository. Never report a download as successful until all verification checks pass.

## 2. Verification checks (per downloaded file, in order)

| # | Check | Rejects |
|---|---|---|
| V1 | File physically exists in the expected local folder | ghost queue entries |
| V2 | Filename matches the expected resource (and the naming standard) | mislabeled saves |
| V3 | File extension is correct **and matches actual content** (magic-byte sniff) | HTML error pages saved as `.pdf` |
| V4 | File size is reasonable for its type | empty files, 1 KB "PDFs", truncated stubs |
| V5 | SHA-256 checksum generated | — |
| V6 | Checksum stored successfully (write + read-back match) | silent index corruption |
| V7 | File can actually be opened (read probe, head + tail) | permission/corruption failures |
| V8 | **PDF deep checks** (when PDF): valid header · EOF marker present · xref/startxref integrity (truncation/partial-download detection) · page count > 0 · pages parse/render (pypdf when available; deterministic structural parse otherwise) | corrupted or partially downloaded PDFs |
| V9 | Metadata generation succeeds (all mandatory fields; schema-valid) | anonymous resources |
| V10 | Resource is indexed (master + download + checksum indexes; read-back verified) | orphan files |
| V11 | Move into the production repository (`resources/…`) with post-move checksum re-verify | partial moves |

**Duplicate rule:** before V11, the checksum is compared against the checksum index — identical content is diverted to `downloads/duplicates/` with a recorded duplicate mapping (one verified copy kept, per Part 04).

## 3. Recovery loop (on ANY failed check)

1. Mark the download **FAILED** with a machine-readable reason code + detail.
2. Record it in `FAILED_DOWNLOADS.json` (url, reason, http status, retry count, last attempt, next retry, alternative-source candidates).
3. Search for another official source (source-priority ladder of Part 05).
4. Retry the download; compare the replacement file (fresh full verification; checksum compared against the failed artifact).
5. Continue until a valid resource is verified **or** all official/trusted sources are exhausted.
6. If no valid copy exists → record in `MISSING_RESOURCES.md` (board, class, subject, expected resource, search locations, reason, recommendation).

Failed artifacts are preserved in `downloads/failed/` for forensics — never silently deleted.

## 4. Reporting & the final repository audit

- `reports/DOWNLOAD_VERIFICATION_REPORT.md` — continuously regenerated: Total Expected · Successfully Verified · Corrupted · Empty · Duplicates · Retried Downloads · Alternative Sources Used · Remaining Missing · **Overall Download Health Score** (weighted, formula in `configs/verification_rules.json`).
- **Final repository audit** (before any Knowledge-Base phase): every expected resource exists · every PDF re-opens · every metadata file exists · every checksum verifies · every index entry resolves · every required folder contains its expected resources. Only on a clean audit is the repository marked **`REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION`** (written to `PROJECT_STATUS.json`). A failed audit blocks the phase — do not proceed.

## 5. As-implemented (2026-07-07)

Location: `curriculum/` workspace (default per owner decision D-2 recommendation; root configurable in `configs/paths.json`).

| Artifact | Role |
|---|---|
| `curriculum/configs/paths.json` | Single source for every workspace path (location-agnostic engine) |
| `curriculum/configs/verification_rules.json` | Size floors, magic bytes, PDF rules, retry/backoff policy, health-score weights |
| `curriculum/scripts/verification/verification_engine.py` | Core library: checks V1–V11, duplicate diversion, recovery-queue management, missing-resource recording, report generation |
| `curriculum/scripts/verification/verify_downloads.py` | CLI — single-file or batch verification of `downloads/incoming/` against `DOWNLOAD_QUEUE.json` |
| `curriculum/scripts/verification/repository_audit.py` | CLI — the final §4 audit; writes `REPOSITORY_AUDIT_REPORT.md` and gates the READY status |
| `curriculum/scripts/verification/tests/` | Unit suite with synthetic fixtures (valid / truncated / zero-page / HTML-masquerade / empty / duplicate) |

Acceptance criteria: [`../planning/ACCEPTANCE_TEST_PLAN.md`](../planning/ACCEPTANCE_TEST_PLAN.md) §AT-V. The acquisition waves (CI-A1..A5) MUST route every download through this engine — direct writes into `resources/` are prohibited.
