# Release Go-Live Audit — Akshara Pilot Execution

**Release tag:** `v17.0-ios-release-readiness`  
**Baseline build:** 17.0.0 (170)  
**Development status:** **FROZEN** — execution only  
**Date:** June 2026

---

## Verdict

| Channel | Go-live? | Notes |
|---------|----------|-------|
| **Android APK distribution** | ✅ **GO** | APK/AAB rebuilt at v17.0 |
| **Android pilot school** | ✅ **GO** | Demo school 58/58; journeys documented |
| **iPhone TestFlight** | ⚠️ **NO-GO** | Compile ✅ · IPA blocked on Apple signing |
| **Friend testing (Android)** | ✅ **GO** | Immediate |
| **Friend testing (iOS)** | ⚠️ **HOLD** | Complete [TestFlight-Upload-Guide.md](TestFlight-Upload-Guide.md) |

**Overall execution readiness: 88/100**

---

## Quality gates

| Gate | Result | Evidence |
|------|--------|----------|
| `flutter analyze` | ✅ 0 issues | v17.0 run |
| `flutter test` | ✅ All passing | v17.0 run |
| Staging demo validation | ✅ 58/58 | `validation_report.json` |
| UI readiness | ✅ 99/100 | v16.5 stress test |
| Android release build | ✅ | v17.0 rebuild |
| iOS compile | ✅ | Xcode release build succeeds |
| iOS IPA | ❌ | No code signing certificates |

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
| GL-01 | ERP profile menu "coming soon" snackbar | Low — notifications now wired (v17.0) |
| GL-02 | Student profile settings "coming soon" | Low |
| GL-03 | Default Flutter launcher icons | Cosmetic — pre-store |
| GL-04 | Android release signed with debug keystore | OK for sideload; replace for Play production |
| GL-05 | iOS IPA not built | Blocks TestFlight — signing certificates required (v17.0) |

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
| TestFlight upload guide | `docs/Testing/TestFlight-Upload-Guide.md` | ✅ v17.0 |
| Final device readiness | `docs/Testing/Final-Device-Readiness.md` | ✅ v17.0 |
| iOS env setup script | `scripts/setup_ios_env.sh` | ✅ v17.0 |

---

## Remaining blockers

| # | Blocker | Blocks | Resolution |
|---|---------|--------|------------|
| 1 | Apple Developer code signing | TestFlight IPA | Xcode → Accounts → Team → `./scripts/build_release.sh ipa` |
| 2 | `xcode-select` → CLI tools (optional) | `flutter doctor` without env | `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` |
| 3 | IPA not uploaded | iPhone friends | [TestFlight-Upload-Guide.md](TestFlight-Upload-Guide.md) |
| 4 | Production signing keystore | Play Store public release | Out of pilot scope |

---

## Sign-off

| Role | Android pilot | iOS TestFlight |
|------|---------------|----------------|
| Engineering | ✅ Ready | ✅ Compile ready · ⏳ Signing |
| QA | ✅ Docs + gates green | ⏳ Pending device smoke |
| Release manager | ✅ Approve APK send | ⏳ Approve after IPA + TestFlight |

---

## Reference index

All testing docs: `docs/Testing/`  
Release history: `../archive/completed/releases/v17.0-iOS-Release-Readiness.md`
