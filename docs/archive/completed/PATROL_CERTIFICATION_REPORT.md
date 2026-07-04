# Patrol Certification Report — M14

**Branch:** `release/v1.0-preprod`  
**Date:** 2026-06-16  
**Registry:** `qa/patrol/run_erp_coverage.sh` — 89 suites  
**Mode:** `ERP_COVERAGE_MODE=full` (88 suites + smoke)

---

## Status: IN PROGRESS

Full regression initiated post-M14. Prior baseline: **10/89 device-certified** (batch-1 post-`2ed4275`).

---

## Pre-flight gates

| Gate | Result |
|------|--------|
| `flutter analyze` | ✅ 0 issues |
| `flutter test` | ✅ 1688 passed, 1 skipped |
| Emulator | Cold boot via `scripts/qa/start_emulator.sh` |
| Product blockers | ✅ 0 (PROD-01/02 resolved) |

---

## Certification matrix

| Batch | Suites | Status |
|-------|-------:|--------|
| 0 — Smoke | 1 | ⏳ Pending |
| 1 — Post-expansion (certified) | 10 | ✅ Prior green (`rerun_batch1.sh`) |
| 2–11 — Full inventory | 78 | ⏳ Pending full run |

**Target:** 89/89 certified  
**Current:** Awaiting full regression completion

---

## Failure classification protocol

| Class | Action |
|-------|--------|
| **Product defect** | Fix app code, re-run affected suite |
| **Patrol defect** | Fix harness/keys/timing in `patrol_test/` |
| **Infrastructure** | Emulator restart, split batch, retry |

---

## M14 fixes affecting Patrol

| Suite | Fix |
|-------|-----|
| `inventory_po_e2e_test` | Dynamic PO finance handoff |
| `auth/logout_test` | QA logout → `/qa-login` |
| All suites | FV-PLAT-14 default config enables all modules (no nav regression) |

---

## Commands

```bash
# Full regression
ERP_COVERAGE_MODE=full ./qa/patrol/run_erp_coverage.sh

# Batch-1 confirm
./qa/patrol/rerun_batch1.sh
```

---

## Update log

| Run ID | Passed | Failed | Notes |
|--------|-------:|-------:|-------|
| `20260615_195149` (prior) | 55 | 23 | Pre-`2ed4275` inventory |
| `rerun_batch1` post-`2ed4275` | 10 | 0 | Certified |
| M14 full run | — | — | **Pending** |

_Update this table when `ERP_COVERAGE_MODE=full` completes._
