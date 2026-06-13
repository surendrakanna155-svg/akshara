# Patrol + Maestro QA Strategy

**Release:** v18.4-patrol-platform

## Division of responsibility

| Layer | Tool | Scope |
|-------|------|-------|
| Deep Flutter validation | **Patrol** | Widget keys, form validation, auth lifecycle, dashboard KPIs, navigation guards, performance timings, screenshot markers |
| End-to-end business flows | **Maestro** | Cross-app journeys, YAML-readable flows, stakeholder demos, device farm YAML |
| Fast feedback | **flutter test** | Unit, widget, provider, contract, security, golden |
| CI gate | **All three** | analyze → flutter test → patrol smoke → maestro smoke |

## Patrol responsibilities

- QA persona login (7 roles) with route assertions
- Session restore and logout
- Dashboard rendering (Principal, Teacher, Parent, Student, Finance, Inventory, Super Admin, Intelligence)
- 81+ business journey smoke (module open + anchor text)
- Form validation (phone, OTP, error messages)
- Navigation (bottom nav, ERP drawer, back stack)
- Performance budgets (launch, login, settle)
- Screenshot regression markers under `qa/patrol/screenshots/`

## Maestro responsibilities

- Readable YAML journeys for product/QA review (`qa/journeys/*.yaml`)
- Device-level gestures and extended waits
- Full ERP workflow scripts (school setup, fee collect, attendance submit)
- Screenshot capture on failure (`qa/screenshots/`)
- JUnit report for CI (`qa/reports/`)

## Recommended execution order

1. `flutter analyze`
2. `flutter test`
3. `./qa/patrol/run_patrol_smoke.sh` — ~5 min on emulator
4. `./qa/journeys/smoke_launch.yaml` + `smoke_qa_personas.yaml` via Maestro
5. `./qa/patrol/run_patrol_all.sh` — full Patrol regression (nightly)
6. `./qa/run_all_qa.sh` — Maestro full suite (weekly / pre-pilot)

## When to add tests where

| Scenario | Add to |
|----------|--------|
| New ValueKey / semantics for testability | lib + Patrol |
| New persona dashboard anchor | Patrol auth + dashboard tests |
| Multi-step business workflow (10+ taps) | Maestro YAML + Patrol journey anchor |
| Form validation rule | Patrol forms |
| API contract / RBAC unit | flutter test |
| Native OS dialog (permissions) | Patrol native automation |

## Build alignment

Both tools use the same QA APK profile:

```bash
./scripts/qa/build_qa_apk.sh
```

Dart-defines: `ENABLE_QA_LOGIN=true`, `ENABLE_DEMO_AUTH=true`, `ENABLE_API_MODE=false`.

Patrol passes the same defines via `--dart-define` flags; helpers also override `environmentProvider` for widget-level consistency in tests.
