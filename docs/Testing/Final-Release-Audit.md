# Final Release Audit — Device Testing Readiness

**Release:** v16.7-device-testing-preparation  
**Date:** June 2026  
**Auditor:** Automated + manual code scan  
**Verdict:** **READY for Android pilot** · **iOS blocked on Xcode setup**

---

## Executive summary

| Area | Status | Score |
|------|--------|------:|
| Android APK distribution | ✅ Ready | 100 |
| Android AAB (Play internal) | ✅ Ready | 100 |
| iOS IPA / TestFlight | ⚠️ Blocked | 25 |
| Demo data package | ✅ Ready | 100 |
| Device test documentation | ✅ Ready | 100 |
| Release UX audit | ⚠️ Minor findings | 92 |
| Quality gates | ✅ Pass | 100 |
| **Overall device testing readiness** | **✅ Android / ⚠️ iOS** | **88** |

---

## Phase 1 — iOS environment

| Check | Result |
|-------|--------|
| Flutter | ✅ 3.44.1 stable |
| Android toolchain | ✅ SDK 36, licenses accepted |
| Full Xcode.app | ❌ Not installed |
| xcodebuild | ❌ Requires full Xcode (CLI tools only active) |
| CocoaPods | ❌ Not installed |
| `ios/Podfile` | ⏳ Generated on first `pod install` |

**Blockers:** Install Xcode from App Store → `xcode-select --switch` → `gem install cocoapods` → `pod install`

**Guide:** `docs/Testing/iOS-Build-Guide.md`

---

## Phase 2 — IPA readiness

| Item | Status |
|------|--------|
| Bundle ID configured | ✅ `com.akshara.erp.aksharaErp` |
| Display name | ✅ Akshara ERP |
| Deployment target | ✅ iOS 13.0 |
| Signing documented | ✅ iOS-Build-Guide.md |
| IPA artifact | ❌ Not built (environment) |
| TestFlight workflow | ✅ Documented |

---

## Phase 3 — Demo data readiness

**Source:** `reports/demo_school/validation_report.json`

| Check | Result |
|-------|--------|
| Total validation steps | 58 passed, 0 failed |
| Principal / admin | ✅ `9876543210` |
| Teachers | ✅ `9000000001+` |
| Parents | ✅ `9000100001+` |
| Students | ✅ 500 seeded |
| Attendance | ✅ |
| Homework | ✅ |
| Exams | ✅ |
| Fees | ✅ |
| Inventory | ✅ |
| Intelligence / dashboards | ✅ |
| Lesson logs | ✅ |

**Guide:** `docs/Testing/Demo-Accounts.md`

---

## Phase 4 — Device test plan

| Deliverable | Path |
|-------------|------|
| Full test matrix | `docs/Testing/Device-Test-Plan.md` |
| Android + iPhone + tablet cases | ✅ |
| Regression smoke checklist | ✅ |

---

## Phase 5 — Bug collection

| Deliverable | Path |
|-------------|------|
| Markdown template | `docs/Testing/Bug-Report-Template.md` |
| Spreadsheet TSV/CSV format | ✅ |

---

## Phase 6 — Release UX audit

### Pass

| Check | Evidence |
|-------|----------|
| Debug banner disabled | `lib/app/app.dart` → `debugShowCheckedModeBanner: false` |
| Core mobile routes wired | Navigation pilot tests pass (parent/teacher/student) |
| Management dashboard live | `management_navigation.dart` → real screens (not placeholder) |
| Error states with retry | v16.5 `AksharaSectionError` on dashboards |
| Empty states | v16.5 `AksharaSectionEmpty` on subsections |
| No raw exception text to users | Global error handler + friendly async states |
| Staging API configured in release script | `scripts/build_release.sh` |

### Findings (non-blocking for pilot)

| ID | Severity | Location | Finding |
|----|----------|----------|---------|
| RA-01 | Minor | `admin_content_scaffold.dart` | ERP app bar: "Notifications coming soon" / "Profile coming soon" snackbars |
| RA-02 | Minor | `student_profile_screen.dart` | Settings section labeled "coming soon" |
| RA-03 | Minor | `transport_tracking_screen.dart` | GPS map placeholder (not in core mobile pilot path) |
| RA-04 | Minor | Secondary ERP modules | Alumni/transport/library report labels include "placeholder" |
| RA-05 | Minor | `sis_academic_assignment_screen.dart` | "Bulk assignment (placeholder)" button label |
| RA-06 | Info | `admin_navigation.dart` | `adminHubRouteBuilder` still uses module placeholder (admin hub only) |
| RA-07 | Info | Pilot API probe | 16/51 pilot validation steps fail on RBAC scope when using admin token for teacher-only endpoints — use persona-correct accounts for device testing |

### Not found (pass)

- No debug banners in release build
- No `TODO` visible in core mobile dashboard UI
- No development environment labels in release staging build
- Core parent/teacher/student journeys have no dead-end routes (pilot nav tests)

---

## Phase 7 — Tester distribution package

| Deliverable | Path |
|-------------|------|
| Android sideload instructions | `docs/Testing/Tester-Instructions.md` |
| TestFlight instructions | Same doc § iPhone |
| Demo credentials | `docs/Testing/Demo-Accounts.md` |

---

## Quality gates

| Gate | Result |
|------|--------|
| `flutter analyze` | 0 issues |
| `flutter test` | 1283 passed, 1 skipped |
| Android release APK | ✅ Builds (73.3 MB) |
| Android release AAB | ✅ Builds (67.8 MB) |

---

## Recommendations

1. **Android:** Distribute APK to friends immediately; use AAB for Play internal track.
2. **iOS:** Complete Xcode + CocoaPods setup on a Mac, run `./scripts/build_release.sh ipa`, upload to TestFlight.
3. **Testing:** Assign each tester one persona from `Demo-Accounts.md`.
4. **Bugs:** Collect via `Bug-Report-Template.md` → `reports/pilot_validation/bugs/`.
5. **Post-pilot:** Address RA-01–RA-05 cosmetic items in a future polish release (not blocking v16.7).

---

## Testing package index

| Document | Purpose |
|----------|---------|
| `docs/Testing/iOS-Build-Guide.md` | Xcode, signing, IPA, TestFlight |
| `docs/Testing/Demo-Accounts.md` | Credentials + data coverage |
| `docs/Testing/Device-Test-Plan.md` | Full test matrix |
| `docs/Testing/Bug-Report-Template.md` | Issue reporting |
| `docs/Testing/Tester-Instructions.md` | Friend/pilot tester onboarding |
| `docs/Testing/Device-Testing-Guide.md` | Original pilot guide (v16.6) |
| `docs/ArchitectureReview/v16.7-Device-Testing-Preparation.md` | Architecture sign-off |
