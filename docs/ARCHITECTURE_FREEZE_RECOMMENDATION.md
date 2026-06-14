# Architecture Freeze Recommendation — v19 RC1

**Date:** 14 June 2026  
**Target branch:** `release/v19-rc1`  
**Baseline:** `main` (uncommitted QA mission work pending merge)  
**Readiness:** ~95% mock pilot · E2E ~62%

---

## Executive summary

Freeze **product scope** and **module interfaces** for RC1. Allow **bugfix-only** changes in stabilized modules. Defer new write journeys, refactors, and API expansions until post-RC.

---

## Freeze candidates (do not change during RC)

| Module / area | Rationale | Risk if touched |
|---------------|-----------|-----------------|
| **Auth / RBAC / route guards** | Production-critical; 213 tenant probes | Session/permission regressions |
| **Admissions → SIS → Finance handoff** | P0 pilot path; Cycle 4 + E2E green | Cross-module data chain breaks |
| **Repository interfaces (Admissions, Finance, SIS, Auth)** | Contract-tested; pilot APIs | Breaking mock/API parity |
| **Patrol helpers + QA keys (P0 journeys)** | New E2E suites depend on stable keys | Flaky or broken automation |
| **Router / `RouteNames` inventory** | Route protection tests assume stable paths | Navigation smoke failures |
| **`scripts/qa/start_emulator.sh` + `run_erp_coverage.sh`** | RC gate infrastructure | Blocks Patrol regression |

---

## Modules safe for stabilization (bugfix-only)

| Module | Status | Notes |
|--------|--------|-------|
| Admissions | Stable mock + write providers | Lead → SIS E2E proven |
| Finance | Stable assign/collect journey | Full journey Patrol green |
| SIS | Read + conversion stable | Registry verification in E2E |
| Teacher / Parent mobile | Attendance sync mock wired | Integration test green |
| HR | **New** leave write MVP | Freeze after RC tests; no payroll writes |
| Inventory | **New** PO draft MVP | Mock write only |
| Transport | **New** route draft MVP | Mock write only |
| ERP navigation / Admin shell | Layout patterns settling | Filter-bar overflow fixes applied |

---

## Unstable / ongoing — do not expand in RC

| Area | Issue | Type | RC action |
|------|-------|------|-----------|
| **Exam administration** | No ERP exam write path | Product **D** | **Out of RC scope** |
| **HR payroll** | Read-only; no mutations | Product **D** | **Out of RC scope** |
| **11× `*ModuleScaffold` duplicates** | TD-P2-01 open refactor | Tech debt | **No refactor in RC** |
| **~1,600 Riverpod providers** | Rebuild fan-out (TD-P1-08) | Performance | Profile only; no rewrites |
| **Live API write paths** | HR/Inventory/Transport API stubs | Backend | Mock-only for RC |
| **Mock tenant scoping** | Partial (TD-P2-02) | Data correctness | Document limitation |
| **Finance report export** | Snackbar stub only | UX placeholder | Accept for pilot |

---

## Risky areas (extra review on any change)

1. **`auth_provider.dart`** — permission cache clear on login (recent fix); retest QA personas after edits.
2. **Filter-bar action buttons** — body-placed CTAs on HR/Inventory/Transport; verify router smoke + Patrol scroll helpers.
3. **`MockHrWriteStore` leave list** — must stay growable; regression in `hr_write_tests`.
4. **Uncommitted `main` delta** — large QA mission diff; RC branch must cut from **green gated commit**, not dirty tree.

---

## Product scope freeze (pilot)

Align with `docs/QA/v18.8_readiness_assessment.md`:

**In scope for v19-rc1 pilot (mock):**

- Admissions → Enrollment → Approval → SIS → Finance assign/collect  
- Teacher attendance submit + parent KPI sync  
- HR leave submit (new, mock)  
- Inventory PO draft / Transport route draft (new, mock) — **optional pilot; default read-only marketing**

**Out of scope:**

- Exam admin, HR payroll writes, live API production cutover, production SaaS checklist (98+)

---

## Recommendations

1. **Tag RC from `release/v19-rc1`** only after full Patrol 25/25 green + `flutter test` 1304+.
2. **Merge policy:** bugfix + test-only PRs to RC; features → post-RC `main`.
3. **Bump `pubspec.yaml`** to `19.0.0-rc.1+190` at RC cut (Agent G).
4. **Refresh** `docs/ProductionReadinessChecklist.md` header score to 95 after RC doc pass.
