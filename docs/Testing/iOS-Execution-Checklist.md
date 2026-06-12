# iOS Execution Checklist — Akshara ERP

**Release:** v16.8 (`v16.8-testing-execution-readiness`)  
**Build:** 16.6.0 (166) · **Bundle ID:** `com.akshara.erp.aksharaErp`  
**Audit date:** June 2026

---

## Current environment audit (`flutter doctor`)

| Component | Status | Notes |
|-----------|--------|-------|
| Flutter 3.44.1 | ✅ Pass | Stable channel |
| Android toolchain | ✅ Pass | SDK 36, licenses accepted |
| **Xcode.app** | ❌ **Blocker** | Not installed |
| **CocoaPods** | ❌ **Blocker** | `pod` not found |
| Chrome / web | ✅ Pass | Not used for pilot |
| Network | ✅ Pass | — |

### Blocker detail

```
[!] Xcode - develop for iOS and macOS
    ✗ Xcode installation is incomplete
    ! CocoaPods not installed
```

`xcodebuild` exists at `/usr/bin/xcodebuild` but fails because only **Command Line Tools** are active — full **Xcode.app** is required.

---

## Phase 1 — Install Xcode (required)

### Checklist

- [ ] **1.1** Install **Xcode** from Mac App Store (~15 GB)
- [ ] **1.2** Open Xcode once → accept license → install additional components
- [ ] **1.3** Point developer directory to Xcode:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
```

- [ ] **1.4** Verify:

```bash
xcodebuild -version
# Expected: Xcode 16.x ...
flutter doctor
# Xcode row should show ✓
```

---

## Phase 2 — Install CocoaPods (required)

- [ ] **2.1** Install CocoaPods:

```bash
sudo gem install cocoapods
pod --version
```

- [ ] **2.2** Install iOS dependencies:

```bash
cd ios
pod install
cd ..
```

- [ ] **2.3** Confirm `ios/Podfile` and `ios/Podfile.lock` exist
- [ ] **2.4** Commit `Podfile.lock` after successful install

---

## Phase 3 — Signing readiness

- [ ] **3.1** Apple Developer Program membership active
- [ ] **3.2** Register App ID: `com.akshara.erp.aksharaErp`
- [ ] **3.3** Open `ios/Runner.xcworkspace` in Xcode
- [ ] **3.4** Runner target → **Signing & Capabilities**
- [ ] **3.5** Enable **Automatically manage signing**
- [ ] **3.6** Select **Team**
- [ ] **3.7** Confirm **Bundle Identifier** = `com.akshara.erp.aksharaErp`
- [ ] **3.8** Build once on device or simulator from Xcode (sanity check)

| Setting | Expected value |
|---------|----------------|
| Display name | Akshara ERP |
| Deployment target | iOS 13.0 |
| Version | 16.6.0 (166) from `pubspec.yaml` |

---

## Phase 4 — IPA build execution

- [ ] **4.1** From repo root:

```bash
./scripts/build_release.sh ipa
```

- [ ] **4.2** Confirm output:

```
build/ios/ipa/*.ipa
```

- [ ] **4.3** Record IPA size and build timestamp in release notes

### Manual alternative

```bash
flutter build ipa --release \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api \
  --dart-define=ENABLE_API_MODE=true \
  --dart-define=PARENT_API_ENABLED=true \
  --dart-define=TEACHER_API_ENABLED=true \
  --dart-define=STUDENT_API_ENABLED=true \
  --dart-define=PHASE5_API_ENABLED=true
```

(Full dart-define list: `scripts/build_release.sh`)

---

## Phase 5 — TestFlight readiness

### App Store Connect

- [ ] **5.1** Create app **Akshara ERP** (if not exists)
- [ ] **5.2** Upload IPA via Xcode Organizer **or** `xcrun altool`
- [ ] **5.3** Wait for processing (5–30 min)
- [ ] **5.4** Complete **Export Compliance** (typically no encryption beyond HTTPS)
- [ ] **5.5** Add **Test Information** (what to test, contact email)

### Internal testing

- [ ] **5.6** TestFlight → Internal Testing → add build
- [ ] **5.7** Add internal testers (team members)
- [ ] **5.8** Verify install on at least one iPhone

### External testing (friends / pilot)

- [ ] **5.9** Create external group (e.g. "Pilot Friends")
- [ ] **5.10** Submit for Beta App Review (first external build)
- [ ] **5.11** Add tester emails or share public link
- [ ] **5.12** Send [iPhone-Tester-Pack.md](iPhone-Tester-Pack.md)

---

## Phase 6 — Post-upload smoke test

On a physical iPhone via TestFlight:

- [ ] **6.1** Install from TestFlight
- [ ] **6.2** Launch → no crash
- [ ] **6.3** No debug banner
- [ ] **6.4** Login with parent `9000100001` → dashboard loads
- [ ] **6.5** Safe area correct (notch / Dynamic Island)
- [ ] **6.6** Logout works

---

## Execution status summary

| Gate | Ready? |
|------|--------|
| Xcode installed | ❌ |
| CocoaPods + pod install | ❌ |
| Signing configured | ⏳ Manual |
| IPA built | ❌ |
| TestFlight uploaded | ❌ |
| Internal tester verified | ❌ |

**iOS execution readiness: 0/6 gates complete on build Mac** — Android path is unblocked.

---

## Remaining blockers

| # | Blocker | Owner | Resolution |
|---|---------|-------|------------|
| B1 | Full Xcode.app not installed | Build Mac admin | App Store install + xcode-select |
| B2 | CocoaPods missing | Build Mac admin | `gem install cocoapods` |
| B3 | Pod install not run | Build Mac admin | `cd ios && pod install` |
| B4 | Apple Developer signing | Release manager | Xcode team + App Store Connect |
| B5 | IPA not yet produced | Build Mac admin | `./scripts/build_release.sh ipa` |

---

## Reference

- Detailed guide: [iOS-Build-Guide.md](iOS-Build-Guide.md)
- iPhone testers: [iPhone-Tester-Pack.md](iPhone-Tester-Pack.md)
- Demo logins: [Demo-Accounts.md](Demo-Accounts.md)
