# Akshara Patrol — Setup & Usage

**Release:** v18.4-patrol-platform  
**Patrol CLI:** 4.4.0+  
**Patrol package:** 4.6.1

## Prerequisites

1. Flutter 3.35+ (project uses 3.44.1)
2. Android SDK with `adb` on `PATH`
3. Patrol CLI:

```bash
dart pub global activate patrol_cli
export PATH="$PATH:$HOME/.pub-cache/bin"
patrol doctor
```

4. Android emulator or device:

```bash
flutter emulators --launch Medium_Phone_API_36.0
adb devices
```

## Project configuration

| Item | Location |
|------|----------|
| Patrol config | `pubspec.yaml` → `patrol:` section |
| Test directory | `patrol_test/` |
| Android runner | `android/app/build.gradle.kts` |
| Native test entry | `android/app/src/androidTest/.../MainActivityTest.java` |
| QA dart-defines | `ENABLE_QA_LOGIN=true`, `ENABLE_DEMO_AUTH=true` |

## Verify setup

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
patrol test \
  --target patrol_test/smoke/smoke_launch_test.dart \
  --dart-define=ENABLE_QA_LOGIN=true \
  --dart-define=ENABLE_DEMO_AUTH=true \
  --dart-define=APP_ENV=development
```

Expected capabilities verified by smoke tests:

- Launch app (splash → QA login)
- Tap widgets (persona buttons)
- Enter text (login / OTP forms)
- Navigate screens (role dashboards)
- Capture screenshot markers (`qa/patrol/screenshots/`)
- Assert UI state (dashboard anchors)

## Test layout

```
patrol_test/
  helpers/          # App bootstrap + QA login helpers
  smoke/            # Launch smoke
  auth/             # Login, logout, session, routing
  dashboards/       # All persona dashboards
  journeys/         # 81 generated business journeys
  forms/            # Validation & OTP forms
  navigation/       # Routes, drawer, back nav
  performance/      # Launch & settle timings
  screenshots/      # Regression baseline markers
```

## Regenerate journeys

```bash
python3 scripts/qa/generate_patrol_journeys.py
```

## One-command runners

```bash
chmod +x qa/patrol/*.sh
./qa/patrol/run_patrol_smoke.sh    # fast gate
./qa/patrol/run_patrol_all.sh      # full regression + flutter gates
./qa/patrol/generate_patrol_report.sh <run_id> <exit_code>
./qa/patrol/compare_screenshots.sh
```

## Testability keys

Stable keys live in `lib/core/testing/qa_test_keys.dart`:

- `qa_login_screen`, `qa_persona_<name>`
- `login_phone_field`, `login_continue_button`
- `otp_verification_field`, `otp_verify_button`
- `auth_logout_button`, `auth_logout_confirm`

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `patrol: command not found` | Add `$HOME/.pub-cache/bin` to PATH |
| No devices | Start emulator; `adb devices` |
| Tests skip instantly | Ensure `MainActivityTest.java` package matches app |
| Splash timeout | Increase `aksharaPatrolConfig()` timeouts in helpers |
| QA login not shown | Pass `--dart-define=ENABLE_QA_LOGIN=true` or use helper overrides |

## Quality gates

```bash
flutter analyze   # 0 issues
flutter test      # all unit/widget tests
patrol test       # integration on device/emulator
```
