# Patrol Current Status

**Branch:** `release/v1.0-preprod`  
**Commit:** `2ed4275` (`2ed427529931762ff20b41f02057d573ce388514`)  
**As of:** 2026-06-15 (post QA expansion Cycle 1)  
**Registry:** `qa/patrol/run_erp_coverage.sh`

> Superseded stabilization reruns (`rerun_final_4`, `rerun_final_6`, `rerun_final_11`, etc.) are **not** counted below.

---

## Summary

| Metric | Value |
|--------|------:|
| **Total suites registered** (`ALL_TARGETS`) | **89** |
| **Full regression scope** (`ERP_COVERAGE_MODE=full`, smoke excluded) | **88** |
| **Patrol test cases** (all workflow files) | **222** |
| **Suites passing (device-certified post-`2ed4275`)** | **10** |
| **Suites failing (device-certified post-`2ed4275`)** | **0** |
| **Suites awaiting full regression** | **78** |

---

## Registration

| Mode | Suites | Notes |
|------|-------:|-------|
| `ALL_TARGETS` | 89 | Includes `erp_coverage_smoke_test.dart` |
| `ERP_COVERAGE_MODE=fast` | 1 | Smoke only |
| `ERP_COVERAGE_MODE=full` | 88 | Skips smoke (duplicate coverage) |

Batch-1 expansion suites (added in `2ed4275`):

- `finance_filters_e2e_test.dart`
- `finance_exports_e2e_test.dart`
- `admissions_exports_e2e_test.dart`
- `management_actions_e2e_test.dart`
- `sis_filters_e2e_test.dart`
- `director_portal_navigation_e2e_test.dart`
- `industry_pack_navigation_e2e_test.dart`
- `healthcare_navigation_e2e_test.dart`
- `hostel_visitors_e2e_test.dart`
- `library_digital_resources_e2e_test.dart`

---

## Post-`2ed4275` device certification

**Certified green:** `qa/patrol/rerun_batch1.sh` — **10/10** suites on `emulator-5554` (`Medium_Phone_API_36.0`, cold boot via `scripts/qa/start_emulator.sh`).

| Suite | Result |
|-------|:------:|
| `finance_filters_e2e_test` | ✅ |
| `finance_exports_e2e_test` | ✅ |
| `admissions_exports_e2e_test` | ✅ |
| `management_actions_e2e_test` | ✅ |
| `sis_filters_e2e_test` | ✅ |
| `director_portal_navigation_e2e_test` | ✅ |
| `industry_pack_navigation_e2e_test` | ✅ |
| `healthcare_navigation_e2e_test` | ✅ |
| `hostel_visitors_e2e_test` | ✅ |
| `library_digital_resources_e2e_test` | ✅ |

**Static gates at `2ed4275`:** `flutter analyze` 0 issues · `flutter test` 1683 passed (~1 skipped).

---

## Last successful full run

| Question | Answer |
|----------|--------|
| Full `ERP_COVERAGE_MODE=full` at **current 88-suite inventory** post-`2ed4275` | **Not executed** |
| Last documented full run (prior inventory, 79 suites) | `20260615_195149` — **55 passed / 23 failed** (partial; fixes landed in `2ed4275`) |
| Last documented **all-green** full Patrol | `20260614_002828` — **22/22** (pre-expansion inventory; superseded) |

**Next action:** `ERP_COVERAGE_MODE=full ./qa/patrol/run_erp_coverage.sh` on `2ed4275` to certify the full 88-suite inventory.

---

## Known infrastructure failures

| ID | Symptom | Mitigation |
|----|---------|------------|
| INFRA-01 | `Device emulator-5554 is not attached` when Patrol starts without a live emulator | Run `bash scripts/qa/start_emulator.sh` first (used by `rerun_batch1.sh`) |
| INFRA-02 | Gradle reports **0 tests executed** (APK built, no journeys run) | Avoid `/` in `patrolTest` descriptions; prefer `flutter pub get` over `flutter clean` mid-session; re-run single suite |
| INFRA-03 | Emulator instability on **long sessions** (~2h+): login timeouts, adb offline | Cold boot via `start_emulator.sh`; split runs (`rerun_batch1.sh`, targeted reruns) |
| INFRA-04 | **CI macOS** Patrol (`flutter_patrol_rc.yml`) historically red | Use local/device-farm Android emulator for certification |
| INFRA-05 | Patrol log artifacts under `qa/patrol/reports/` are **gitignored** | Capture run ID locally when certifying |

---

## Known product failures

No Patrol suite is **device-certified failing** post-`2ed4275`. Open product gaps affecting coverage scope:

| ID | Area | Issue | Patrol impact |
|----|------|-------|---------------|
| PROD-01 | Inventory procurement | Full **create → approve → receive** PO chain fails when dynamic PO lacks finance handoff linkage (`po_201` scenario) | `inventory_po_e2e_test` scoped to **approve handoff only** on seeded `po_4` |
| PROD-02 | Auth (QA builds) | Logout routes to `/login` instead of `/qa-login` | `PATROL-002` in `qa/patrol/reports/bugs.json` — low severity, open |
| PROD-03 | Parent golden tests | Dashboard golden drift after QA login banner | `PATROL-004` — high severity for goldens, not blocking Patrol journeys |

Stabilization fixes in `2ed4275` (parent receipt PDF, finance QR, substitute teacher, director portal, trust intelligence, copilot context cast, etc.) address **prior Patrol failures** but are **not yet re-certified** in a single full regression run.

---

## Commands

```bash
# Fast smoke (~2 min)
./qa/patrol/run_erp_coverage.sh

# Full regression (88 suites, ~60+ min)
ERP_COVERAGE_MODE=full ./qa/patrol/run_erp_coverage.sh

# Batch-1 expansion only (10 suites, certified post-2ed4275)
./qa/patrol/rerun_batch1.sh
```

---

## Related docs

- `docs/PATROL_CERTIFICATION_REPORT.md` — prior 79-suite partial run (superseded)
- `docs/QA/FINAL_COVERAGE_REPORT.md` — QA expansion Cycle 1 inventory
- `docs/QA/PATROL_EXPANSION_PLAN.md` — Tier 1/2/3 backlog toward 150–300 suites
