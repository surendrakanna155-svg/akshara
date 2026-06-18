# Patrol Batch 02b — Certification Report

**Date:** 2026-06-18  
**Branch:** `feature/m15-theme`  
**Suite:** `patrol_test/workflows/patrol_batch2b_approval_chains_e2e_test.dart`  
**Status:** **IMPLEMENTED — Patrol cert pending stable emulator**

---

## Scope (4 cross-persona chains)

| # | Journey | Personas |
|---|---------|----------|
| 1 | Finance concession assign → principal approve | Finance → Principal |
| 2 | Parent attendance correction → principal approve | Parent → Principal |
| 3 | Inventory PO draft → principal approve | Inventory → Principal |
| 4 | Exam publish approval → parent sees results | Principal → Parent |

---

## Infrastructure delivered

| Item | Path |
|------|------|
| Cross-persona suite | `patrol_test/workflows/patrol_batch2b_approval_chains_e2e_test.dart` |
| `switchQaPersona` fix (logout before `/qa-login`) | `patrol_test/helpers/patrol_helpers.dart` |
| Persona switch smoke | `patrol_test/auth/qa_persona_switch_test.dart` |
| ERP coverage script | `qa/patrol/run_erp_coverage.sh` |

### `switchQaPersona` fix

Previously navigated to `/qa-login` while still authenticated; GoRouter redirected to the current persona home. Now calls `authProvider.notifier.logout()` before QA re-login.

---

## Patrol execution (2026-06-18)

| Run | Result | Notes |
|-----|--------|-------|
| Verbose run #1 | 1/2 discovered tests passed | Gradle `connectedDebugAndroidTest` aborted mid-suite |
| Subsequent runs | 0 tests (infra) | Emulator adb offline / flash-close after cold boot |

**Blocker:** Android emulator instability (`adb offline`, `connectedDebugAndroidTest` exit 1 with 0 tests). Re-run when `scripts/qa/start_emulator.sh` reports stable `emulator-5554 device`.

```bash
AKSHARA_EMULATOR_HEADLESS=1 scripts/qa/start_emulator.sh
export PATH="${PATH}:${HOME}/.pub-cache/bin"
patrol test -t patrol_test/workflows/patrol_batch2b_approval_chains_e2e_test.dart \
  -t patrol_test/auth/qa_persona_switch_test.dart \
  --device emulator-5554 \
  --dart-define=APP_ENV=development \
  --dart-define=ENABLE_QA_LOGIN=true \
  --dart-define=ENABLE_DEMO_AUTH=true \
  --dart-define=ENABLE_API_MODE=false
```

---

## Expected coverage delta (on cert)

| Metric | Before | After (target) | Δ |
|--------|--------|----------------|---|
| Certified Patrol journeys | 116 | **120** | +4 |
| Cross-persona approval chains | 0 | 4 | +4 |
| Overall QA coverage % | ~46% | **~48%** | +2% |

---

## Next

1. Certify Batch 02b when emulator stable (4/4 green + persona switch 2/2)
2. Batch 03 — director portal depth, tablet breakpoints, RBAC deny journeys
