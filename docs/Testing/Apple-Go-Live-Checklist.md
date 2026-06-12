# Apple Go-Live Checklist — Akshara ERP Pilot

**Release:** v17.1 (`v17.1-apple-distribution-readiness`)  
**Date:** June 2026

---

## 1. What is complete ✅

| Area | Status | Evidence |
|------|--------|----------|
| Android APK/AAB | ✅ | `scripts/build_release.sh apk\|aab` |
| Android pilot docs | ✅ | `Android-Tester-Pack.md` |
| Demo school validation | ✅ | 58/58 |
| Xcode + CocoaPods | ✅ | Flutter doctor green |
| iOS native assets build | ✅ | `scripts/ios/xcrun` wrapper |
| iOS archive | ✅ | `build/ios/archive/Runner.xcarchive` |
| Development signing | ✅ | Apple Development cert installed |
| Team ID configured | ✅ | `63YXKNM6UN` in Xcode project |
| Bundle ID consistent | ✅ | `com.akshara.erp.aksharaErp` |
| Version / build | ✅ | 17.1.0 (171) |
| Quality gates | ✅ | `flutter analyze` 0 · `flutter test` 1283 pass |
| TestFlight documentation | ✅ | Execution + upload guides |

---

## 2. Apple account actions required ⏳

**Owner must complete — cannot be automated:**

| # | Action | Portal |
|---|--------|--------|
| 1 | Confirm **paid Apple Developer Program** membership | developer.apple.com |
| 2 | Create **Apple Distribution** certificate | Certificates |
| 3 | Register Bundle ID (if missing) | Identifiers |
| 4 | Create **App Store** provisioning profile | Profiles |
| 5 | Create **App Store Connect** app record | appstoreconnect.apple.com |
| 6 | Upload archive → TestFlight | Xcode Organizer or Transporter |
| 7 | Answer **Export Compliance** | App Store Connect → TestFlight |
| 8 | Add **internal testers** | TestFlight → Internal Testing |

See [TestFlight-Execution-Guide.md](TestFlight-Execution-Guide.md) for step-by-step instructions.

---

## 3. What Cursor can no longer automate 🚫

| Item | Reason |
|------|--------|
| Apple Distribution certificate | Requires Account Holder Apple ID + Keychain CSR on owner Mac |
| App Store provisioning profile | Apple Developer portal — role-gated |
| App Store Connect app creation | Owner Apple ID login |
| TestFlight tester invites | Owner email list in App Store Connect |
| Beta App Review submission | Human judgment on test notes |
| Paid Developer Program enrollment | Payment + legal agreement |
| Custom app icon / launch brand assets | Design decision — documented only, not redesigned in v17.1 |

---

## 4. Exact next steps for owner

### Today (≈30 min)

1. Log in to [developer.apple.com](https://developer.apple.com) as Account Holder
2. Create **Apple Distribution** certificate (Execution Guide Phase 1)
3. Create **App Store** profile for `com.akshara.erp.aksharaErp` (Phase 2)
4. Verify: `security find-identity -v -p codesigning` shows Distribution

### Same day (≈20 min)

5. Create app in App Store Connect (Phase 3 setup)
6. Run:

   ```bash
   source scripts/setup_ios_env.sh
   ./scripts/build_release.sh ipa
   ```

   Or upload existing archive:

   ```bash
   open build/ios/archive/Runner.xcarchive
   ```

7. **Distribute App** → App Store Connect → Upload

### After processing (≈15 min)

8. TestFlight → Internal Testing → add yourself + 2 pilot testers
9. Install on iPhone via TestFlight app
10. Run P0 journeys from [Real-User-Journeys.md](Real-User-Journeys.md)

### Before public App Store (later — not pilot blocker)

11. Replace placeholder app icon and launch image — see [Release-Asset-Audit.md](Release-Asset-Audit.md)

---

## Readiness scores (v17.1)

| Metric | Score |
|--------|------:|
| **Apple readiness** | **88%** |
| **TestFlight readiness** | **75%** |
| **IPA export readiness** | **60%** |
| **Android pilot readiness** | **100%** |

**Remaining blockers:** Apple Distribution certificate · App Store provisioning profile · TestFlight upload

---

## Sign-off

| Role | iOS TestFlight | Android pilot |
|------|:--------------:|:-------------:|
| Engineering | ✅ Repo complete | ✅ Ready |
| Owner (Apple) | ⏳ Phases 1–4 pending | ✅ APK ready to send |
| QA | ⏳ After TestFlight install | ✅ Docs ready |
