# Maestro Setup — Akshara ERP

**Platform:** v18.1 Autonomous QA  
**App ID:** `com.akshara.erp`

---

## Install Maestro

```bash
./scripts/qa/setup_maestro.sh
export PATH="${HOME}/.maestro/bin:${PATH}"
maestro --version   # expect 2.x
```

Maestro is installed to `~/.maestro/bin`.

---

## Android emulator

List emulators:

```bash
flutter emulators
```

Launch default Android AVD:

```bash
flutter emulators --launch Medium_Phone_API_36.0
adb devices   # must show one device in "device" state
```

Physical device: enable USB debugging, connect USB, accept RSA prompt.

---

## Build & install QA APK

QA builds use **demo auth** (`ENABLE_DEMO_AUTH=true`) and **mock repositories** for offline deterministic flows.

```bash
./scripts/qa/build_qa_apk.sh
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

| OTP type | Code |
|----------|------|
| Mobile (Parent/Teacher/Student/Principal chip) | `123456` |
| Staff ERP portal | `654321` |

---

## Verify Maestro controls

```bash
maestro test -c qa/maestro/config.yaml qa/journeys/smoke_launch.yaml
```

Expected:

1. App launches (splash → login)
2. `Welcome back` visible
3. Screenshot saved under `qa/screenshots/`

Manual checks Maestro supports:

| Action | Journey step |
|--------|--------------|
| Launch app | `launchApp` |
| Tap | `tapOn: "Continue"` |
| Text entry | `inputText: "123456"` |
| Navigate | `tapOn: "Fees"` |
| Screenshot | `takeScreenshot:` |
| Back | `tapOn: { icon: ArrowBack }` |

---

## Full regression

```bash
./qa/run_all_qa.sh
```

Smoke only:

```bash
SMOKE_ONLY=1 ./qa/run_all_qa.sh
```

---

## Screenshot storage

Maestro writes to `--test-output-dir` (set by `run_all_qa.sh`):

```
qa/screenshots/<run_id>/
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `maestro: command not found` | Add `~/.maestro/bin` to PATH |
| No devices | Launch emulator or connect phone |
| App not installed | Run `build_qa_apk.sh` + `adb install -r` |
| OTP fails on staging APK | Use QA APK (demo auth), not staging release |
| ERP drawer not opening | Journey uses top-left tap `7%,7%` — adjust for device DPI |

---

## CI integration (future)

```bash
maestro test --format junit --output qa/reports/ci.junit.xml qa/journeys/smoke_*.yaml
```
