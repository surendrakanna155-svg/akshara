# Release Go-Live Audit — Akshara Pilot Execution

**Release tag:** `v16.8-testing-execution-readiness`  
**Baseline build:** 16.6.0 (166)  
**Development status:** **FROZEN** — execution only  
**Date:** June 2026

---

## Verdict

| Channel | Go-live? | Notes |
|---------|----------|-------|
| **Android APK distribution** | ✅ **GO** | APK/AAB built; tester pack ready |
| **Android pilot school** | ✅ **GO** | Demo school 58/58; journeys documented |
| **iPhone TestFlight** | ⚠️ **NO-GO** | Xcode + CocoaPods not on build Mac |
| **Friend testing (Android)** | ✅ **GO** | Immediate |
| **Friend testing (iOS)** | ⚠️ **HOLD** | Complete [iOS-Execution-Checklist.md](iOS-Execution-Checklist.md) |

**Overall execution readiness: 85/100**

---

## Quality gates

| Gate | Result | Evidence |
|------|--------|----------|
| `flutter analyze` | ✅ 0 issues | v16.8 run |
| `flutter test` | ✅ 1283 passed, 1 skipped | v16.8 run |
| Staging demo validation | ✅ 58/58 | `validation_report.json` |
| UI readiness | ✅ 99/100 | v16.5 stress test |
| Android release build | ✅ | APK 73.3 MB, AAB 67.8 MB |

---

## Release blocker audit

### No debug UI ✅

| Check | Result |
|-------|--------|
| `debugShowCheckedModeBanner: false` | ✅ `lib/app/app.dart` |
| Debug overlay in release build | ✅ Not present |
| "Development" environment label in staging build | ✅ Shows staging via API only |

### No placeholder data in pilot paths ✅

| Check | Result |
|-------|--------|
| Parent/teacher/student dashboards | ✅ Repository + staging API |
| Demo school seeded | ✅ 500 students, fees, attendance |
| Mock-only when API off | ✅ Expected fallback; staging build uses API |

### No dead navigation (pilot paths) ✅

| Check | Result |
|-------|--------|
| Parent nav pilot tests | ✅ Pass |
| Teacher nav pilot tests | ✅ Pass |
| Student nav pilot tests | ✅ Pass |
| Real-user journeys documented | ✅ [Real-User-Journeys.md](Real-User-Journeys.md) |

### Mock-only routes NOT in pilot scope ✅

Core pilot uses staging API with demo school. Mock OTP (`123456`) is **documented fallback only**.

| Route / area | Pilot exposed? | Notes |
|--------------|----------------|-------|
| Parent mobile | API + fallback | Primary: staging login |
| Teacher mobile | API + fallback | Primary: staging login |
| Student mobile | API + fallback | Primary: staging login |
| ERP principal paths | API | `9876543210` |
| Admin hub placeholder | Low traffic | `/admin` hub only — not in mobile pilot |
| Transport GPS map placeholder | No | Not in tester journeys |
| Alumni finance placeholders | No | Not in tester journeys |

### Known non-blockers (documented, no fix in freeze)

| ID | Finding | Pilot impact |
|----|---------|--------------|
| GL-01 | ERP notifications/profile "coming soon" snackbars | Low — mobile pilot unaffected |
| GL-02 | Student profile settings "coming soon" | Low |
| GL-03 | Default Flutter launcher icons | Cosmetic — pre-store |
| GL-04 | Android release signed with debug keystore | OK for sideload; replace for Play production |
| GL-05 | iOS IPA not built | Blocks TestFlight only |

### No release blockers in scope ✅

No Critical items open. Android distribution approved.

---

## Execution package completeness

| Deliverable | Path | Status |
|-------------|------|--------|
| iOS execution checklist | `docs/Testing/iOS-Execution-Checklist.md` | ✅ |
| Demo school validation | `docs/Testing/Demo-School-Validation.md` | ✅ |
| Android tester pack | `docs/Testing/Android-Tester-Pack.md` | ✅ |
| iPhone tester pack | `docs/Testing/iPhone-Tester-Pack.md` | ✅ |
| Real user journeys | `docs/Testing/Real-User-Journeys.md` | ✅ |
| Bug triage process | `docs/Testing/Bug-Triage-Process.md` | ✅ |
| Bug report template | `docs/Testing/Bug-Report-Template.md` | ✅ (v16.7) |
| Build script | `scripts/build_release.sh` | ✅ (v16.6) |

---

## Remaining blockers

| # | Blocker | Blocks | Resolution |
|---|---------|--------|------------|
| 1 | Full Xcode.app not installed | TestFlight | App Store install + checklist Phase 1 |
| 2 | CocoaPods not installed | TestFlight | `gem install cocoapods` |
| 3 | IPA not uploaded | iPhone friends | `./scripts/build_release.sh ipa` → App Store Connect |
| 4 | Production signing keystore | Play Store public release | Out of pilot scope |

---

## Sign-off

| Role | Android pilot | iOS TestFlight |
|------|---------------|----------------|
| Engineering | ✅ Ready | ⏳ Environment pending |
| QA | ✅ Docs + gates green | ⏳ Pending device smoke |
| Release manager | ✅ Approve APK send | ⏳ Approve after IPA |

---

## Reference index

All testing docs: `docs/Testing/`  
Release history: `docs/Releases/v16.8-Testing-Execution-Readiness.md`
