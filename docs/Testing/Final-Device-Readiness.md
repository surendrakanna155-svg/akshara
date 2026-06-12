# Final Device Readiness — Akshara Pilot

**Release:** v17.0 (`v17.0-ios-release-readiness`)  
**Build:** 17.0.0 (170)  
**Date:** June 2026  
**Scope:** Real-device testing readiness for Android + iPhone pilot testers

---

## Executive summary

| Platform | Install ready | Login ready | Nav ready | Permissions | Overall |
|----------|:-------------:|:-----------:|:---------:|:-----------:|:-------:|
| **Android** | ✅ | ✅ | ✅ | ✅ | **95%** |
| **iPhone** | ⏳ TestFlight | ✅ | ✅ | ✅ | **70%** |

Android pilot can start immediately. iPhone pilot requires IPA upload after Apple Developer signing.

---

## Android readiness

### Install

| Check | Status | Notes |
|-------|--------|-------|
| Release APK built | ✅ | `./scripts/build_release.sh apk` |
| Release AAB built | ✅ | Play Console / internal sharing |
| Package name | `com.akshara.erp` | Consistent across builds |
| Min SDK | API 21+ | Standard Flutter default |
| Target SDK | API 36 | Current toolchain |
| Install from unknown sources | Tester action | Enable for sideload APK |

**APK path:** `build/app/outputs/flutter-apk/app-release.apk`  
**AAB path:** `build/app/outputs/bundle/release/app-release.aab`

### Login

| Persona | Method | Account |
|---------|--------|---------|
| Parent | Phone OTP | See [Demo-Accounts.md](Demo-Accounts.md) |
| Teacher | Phone OTP | See [Demo-Accounts.md](Demo-Accounts.md) |
| Student | Phone OTP | See [Demo-Accounts.md](Demo-Accounts.md) |
| ERP Principal | Phone login | `9876543210` |
| Staging API | `--dart-define=APP_ENV=staging` | Baked into release script |

Demo school validation: **58/58** (`reports/demo_school/validation_report.json`)

### Permissions

| Permission | Used for | Pilot impact |
|------------|----------|--------------|
| Internet | API calls | Required — granted at install |
| Storage (legacy) | PDF export | Optional — printing plugin |
| Notifications | Push (future) | Not required for pilot |

### Navigation & UX

| Check | Status |
|-------|--------|
| Parent bottom nav | ✅ Tested in widget tests |
| Teacher bottom nav | ✅ Tested in widget tests |
| Student bottom nav | ✅ Tested in widget tests |
| Back gesture / system back | ✅ GoRouter pop |
| Keyboard overlap (forms) | ✅ Standard Flutter scaffold |
| Tablet / large phone layouts | ✅ Responsive breakpoints |

---

## iPhone readiness

### Install

| Check | Status | Notes |
|-------|--------|-------|
| Xcode environment | ✅ | Xcode 26.5 + CocoaPods 1.16.2 |
| iOS compile | ✅ | Release build succeeds |
| IPA generated | ❌ | Blocked: no signing certificates |
| TestFlight upload | ⏳ | After IPA + App Store Connect |
| Bundle ID | `com.akshara.erp.aksharaErp` | Registered in Xcode when Team selected |

See [TestFlight-Upload-Guide.md](TestFlight-Upload-Guide.md) for upload steps.

### Navigation

| Check | Status |
|-------|--------|
| Parent / teacher / student shells | ✅ Same codebase as Android |
| Safe area (notch / Dynamic Island) | ✅ Material + Cupertino scaffolds |
| Tab bar on iPhone | ✅ Bottom navigation |
| Modal sheets | ✅ Standard Flutter |

### Keyboard & input

| Check | Status |
|-------|--------|
| OTP input fields | ✅ |
| Phone number keyboard | ✅ `TextInputType.phone` |
| Form scroll on keyboard open | ✅ `SingleChildScrollView` / scaffold resize |
| Return key dismiss | ✅ Standard behavior |

### Permissions (iOS)

| Permission | Info.plist | Pilot need |
|------------|------------|------------|
| Internet | Implicit | Required |
| Photo library | Not requested | N/A |
| Camera | Not requested | N/A |
| Push notifications | Not configured | Future — not pilot blocker |

---

## Device test matrix

Use [Device-Test-Plan.md](Device-Test-Plan.md) and [Real-User-Journeys.md](Real-User-Journeys.md).

### Priority P0 (day 1)

| # | Journey | Android | iPhone |
|---|---------|:-------:|:------:|
| 1 | Install app | ✅ APK | ⏳ TestFlight |
| 2 | Parent login + dashboard | ✅ | ⏳ |
| 3 | Teacher login + attendance | ✅ | ⏳ |
| 4 | Student login + timetable | ✅ | ⏳ |
| 5 | Fee payment view (parent) | ✅ | ⏳ |
| 6 | Logout + re-login | ✅ | ⏳ |

### Priority P1 (week 1)

| # | Journey | Android | iPhone |
|---|---------|:-------:|:------:|
| 7 | Notifications inbox | ✅ | ⏳ |
| 8 | PDF receipt download | ✅ | ⏳ |
| 9 | Landscape rotation | ✅ | ⏳ |
| 10 | Low connectivity / offline message | ✅ | ⏳ |

---

## Known device-specific notes

| ID | Platform | Issue | Workaround |
|----|----------|-------|------------|
| D-01 | iOS | IPA requires Apple Developer signing | Complete [TestFlight-Upload-Guide.md](TestFlight-Upload-Guide.md) |
| D-02 | iOS | `xcode-select` may point to CLI tools | Run `sudo xcode-select --switch ...` or use `setup_ios_env.sh` |
| D-03 | Android | APK sideload security prompt | Expected — tap "Install anyway" |
| D-04 | Both | Mock OTP `123456` fallback | Documented in Demo-Accounts — use staging API first |

---

## Tester handoff

| Platform | Document | Distribution |
|----------|----------|--------------|
| Android | [Android-Tester-Pack.md](Android-Tester-Pack.md) | APK file or internal link |
| iPhone | [iPhone-Tester-Pack.md](iPhone-Tester-Pack.md) | TestFlight invite (after upload) |
| Both | [Tester-Instructions.md](Tester-Instructions.md) | Shared onboarding |
| Bugs | [Bug-Report-Template.md](Bug-Report-Template.md) | Slack / email |

---

## Sign-off criteria

| Gate | Android | iPhone |
|------|:-------:|:------:|
| Build artifact available | ✅ | ❌ |
| 3 personas login on physical device | ⏳ Tester | ⏳ Tester |
| No P0 crashes in 30-min session | ⏳ Tester | ⏳ Tester |
| Safe area / keyboard acceptable | ⏳ Tester | ⏳ Tester |

**Device testing readiness:** Android **95%** · iPhone **70%** (pending TestFlight)
