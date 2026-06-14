# Phase 1 Patrol Verification

**Date:** 14 June 2026  
**Device:** `emulator-5554` (Medium_Phone_API_36.0)  
**Dart defines:** `APP_ENV=development`, `ENABLE_QA_LOGIN=true`, `ENABLE_DEMO_AUTH=true`, `ENABLE_API_MODE=false`

---

## Verdict

| Question | Answer | Evidence |
|----------|--------|----------|
| Was the **historical 2h+ failure** a config issue? | **Yes (A)** | Prior run omitted `--target`; executed full `test_bundle.dart` + generated journeys (~2h 24m). |
| Did **correct Phase 1 invocation** pass on first try? | **No** | 2/4 passed; 2 failed with deterministic product/test-key defects. |
| Do all **four Phase 1 suites pass now**? | **Yes** | Final run: **4/4 successful** in **1m 23s** (83.8s execution). |

**Root-cause mix:** **A** (historical misconfiguration) + **C** (real product QA-key / tab UX defects, now fixed). No flaky timeouts after fixes.

---

## Command (correct invocation)

```bash
patrol test --device emulator-5554 \
  --dart-define=APP_ENV=development \
  --dart-define=ENABLE_QA_LOGIN=true \
  --dart-define=ENABLE_DEMO_AUTH=true \
  --dart-define=ENABLE_API_MODE=false \
  --target patrol_test/workflows/hr_payroll_e2e_test.dart \
  --target patrol_test/workflows/inventory_lifecycle_e2e_test.dart \
  --target patrol_test/workflows/transport_activate_e2e_test.dart \
  --target patrol_test/workflows/education_remark_e2e_test.dart
```

**Do not** pass workflow paths as positional args without `--target` — that runs the entire Patrol bundle.

---

## Run history

### Run 1 — Correct targets (initial verification)

| Metric | Value |
|--------|------:|
| Log | `qa/patrol/reports/phase1_verification/run_20260614_142122.log` |
| Wall clock | ~154s (~2m 34s incl. APK build) |
| Patrol execution | 2m 10s |
| Exit code | **1** |

| Suite | Result | Duration |
|-------|--------|----------|
| `hr_payroll_e2e_test.dart` | ✅ Pass | 8s |
| `inventory_lifecycle_e2e_test.dart` | ✅ Pass | 8s |
| `transport_activate_e2e_test.dart` | ❌ Fail | 10s |
| `education_remark_e2e_test.dart` | ❌ Fail | 26s |

### Run 2 — Re-run after fixes (failed suites only)

| Metric | Value |
|--------|------:|
| Log | `qa/patrol/reports/phase1_verification/rerun_transport_education_20260614_142544.log` |
| Wall clock | 67s |
| Patrol execution | 50s |
| Exit code | **0** |

| Suite | Result |
|-------|--------|
| `transport_activate_e2e_test.dart` | ✅ Pass (11s) |
| `education_remark_e2e_test.dart` | ✅ Pass (10s) |

### Run 3 — Final all-four confirmation

| Metric | Value |
|--------|------:|
| Log | `qa/patrol/reports/phase1_verification/final_all_four_20260614_142658.log` |
| Summary | `qa/patrol/reports/phase1_verification/final_summary.txt` |
| Wall clock | 99s |
| Patrol execution | **1m 23s** |
| Exit code | **0** |

| Suite | Result | Duration |
|-------|--------|----------|
| `hr_payroll_e2e_test.dart` | ✅ Pass | 8s |
| `inventory_lifecycle_e2e_test.dart` | ✅ Pass | 7s |
| `transport_activate_e2e_test.dart` | ✅ Pass | 12s |
| `education_remark_e2e_test.dart` | ✅ Pass | 11s |

**Final result: 4/4 successful, 0 failed, 0 skipped.**

---

## Failures and fixes

### 1. Transport activate E2E — **Product defect (C)**

**Failing test:** `journey: transport route draft then activate E2E`  
**File:** `patrol_test/workflows/transport_activate_e2e_test.dart`

**Error (from Run 1 log):**

```
Expected: exactly one matching candidate
Actual: Found 2 widgets with key [<'transport_activate_route_button'>]
Which: is too many
```

**Root cause:** Seed mock data includes draft route `route_15`; E2E creates another draft (`route_101`). Both rows used the **same static** `QaTestKeys.transportActivateRouteButton`, breaking `assertVisibleKey` (`findsOneWidget`).

**Fix:**

- `QaTestKeys.transportActivateRouteButton(String routeId)` — per-route key
- `transport_routes_screen.dart` — key includes `route.id`
- `transport_journey_helpers.dart` — activate `route_101` (first mock create after counter=100)
- Widget tests updated to assert `route_15` seed draft key

**Classification:** **C — real product defect** (ambiguous QA keys when multiple draft rows visible). Not a flake.

---

### 2. Education remark E2E — **Product defect (C)**

**Failing test:** `journey: education report remark publish E2E`  
**File:** `patrol_test/workflows/education_remark_e2e_test.dart`

**Error (from Run 1 log):**

```
WaitUntilVisibleTimeoutException after 0:00:20.000000
Finder "Found 1 widget with text \"Report Remarks\"" did not find any visible (i.e. hit-testable) widgets
```

**Root cause:** Education `TabBar` is `isScrollable: true`. On mobile emulator width, **Report Remarks** tab exists in tree but is **off-screen / not hit-testable**. Text tap without scroll fails consistently.

**Fix:**

- Added `QaTestKeys.educationReportRemarksTab` on the Report Remarks `Tab`
- E2E uses `$(QaTestKeys.educationReportRemarksTab).scrollTo().tap()` (Patrol scroll pattern)

**Classification:** **C — real product/testability defect** (missing stable key + scroll). Not a flake.

---

## Historical failure (prior session) — **Configuration (A)**

| Symptom | Cause |
|---------|--------|
| ~2h 24m runtime | Full bundle + `generated_journeys_test.dart`, not 4 targets |
| `tail -30` truncated logs | Could not see first failing journey in captured output |
| Gradle exit 1 | At least one journey in full bundle failed (exact name lost to truncation) |

**Classification:** **A — Patrol configuration** (missing `--target` flags). Correct invocation completes in **~2 minutes**, not hours.

---

## Widget test regression check

After key changes:

```bash
flutter test test/core/testing/qa_test_keys_test.dart \
  test/features/transport/transport_screens_test.dart \
  test/features/final_completion/phase1_workflow_widget_test.dart
```

**Result:** 20/20 passed.

---

## Files changed

| File | Change |
|------|--------|
| `lib/core/testing/qa_test_keys.dart` | Route-scoped activate key; `educationReportRemarksTab` |
| `lib/features/transport/routes/transport_routes_screen.dart` | Per-route activate button keys |
| `lib/features/education/education_screen.dart` | Tab key on Report Remarks |
| `patrol_test/helpers/transport_journey_helpers.dart` | Target `route_101` after create |
| `patrol_test/workflows/education_remark_e2e_test.dart` | Scroll-to-tab |
| `test/features/transport/transport_screens_test.dart` | Assert `route_15` key |
| `test/features/final_completion/phase1_workflow_widget_test.dart` | Same |
| `test/core/testing/qa_test_keys_test.dart` | Key stability for new keys |

---

## CI recommendation

Ensure `.github/workflows/flutter_ci.yml` Phase 1 job **always** uses `--target` per workflow file (already correct). Never use bare positional paths or pipe Patrol output through `tail` in automation.

**Expected CI Phase 1 Patrol duration:** ~2–3 minutes wall time on macOS emulator (plus build cache).

---

## Log archive

All complete logs (no truncation):

```
qa/patrol/reports/phase1_verification/
├── run_20260614_142122.log          # Initial 4-target run (2 fail)
├── rerun_transport_education_*.log  # Post-fix 2-suite run (pass)
├── final_all_four_20260614_142658.log  # Final 4/4 pass
├── final_summary.txt
└── rerun_summary.txt
```

HTML report (device): `build/app/reports/androidTests/connected/debug/index.html`
