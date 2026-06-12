# iOS Build Guide — Akshara ERP Pilot

**Release:** v17.0 (`v17.0-ios-release-readiness`)  
**Bundle ID:** `com.akshara.erp.aksharaErp`  
**Deployment target:** iOS 13.0  
**Display name:** Akshara ERP  
**Version:** 17.0.0 (170)

---

## Mac environment status (audit — v17.0)

Run on your build Mac:

```bash
source scripts/setup_ios_env.sh
flutter doctor -v
xcodebuild -version
pod --version
```

| Requirement | Status on build machine | Action |
|-------------|-------------------------|--------|
| Flutter stable | ✅ 3.44.1 | — |
| Android toolchain | ✅ Ready | APK/AAB builds work |
| **Full Xcode.app** | ✅ Installed (26.5) | — |
| **Xcode CLI tools** | ⚠️ May point to CLT only | `sudo xcode-select --switch` or use `xcode.env.local` |
| **CocoaPods** | ✅ 1.16.2 (Homebrew) | — |
| **Pod install** | ✅ Clean | `cd ios && pod install` |
| Apple Developer account | ⏳ Manual | Required for TestFlight / IPA |
| Code signing certificates | ❌ **Blocker** | Sign in to Xcode → select Team |

### Blocker: Command Line Tools vs full Xcode

If `xcodebuild -version` returns:

```
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' ...
```

Fix:

```bash
# 1. Install Xcode from App Store (~15 GB)
# 2. Point developer tools to Xcode
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# 3. Accept license
sudo xcodebuild -license accept

# 4. Verify
xcodebuild -version
# Expected: Xcode 16.x, Build ...
```

### Install CocoaPods

```bash
sudo gem install cocoapods
pod --version
```

---

## One-time iOS project setup

From repo root:

```bash
cd ios
pod install
cd ..
```

This generates `ios/Podfile` and `ios/Podfile.lock` on first run. Commit `Podfile.lock` after a successful install for reproducible builds.

---

## IPA build commands

### Option A — Flutter CLI (recommended)

Uses the same staging dart-defines as Android pilot builds:

```bash
./scripts/build_release.sh ipa
```

Or manually:

```bash
flutter build ipa --release \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api \
  --dart-define=ENABLE_API_MODE=true \
  --dart-define=ADMISSIONS_API_ENABLED=true \
  --dart-define=FINANCE_API_ENABLED=true \
  --dart-define=SIS_API_ENABLED=true \
  --dart-define=ACADEMIC_API_ENABLED=true \
  --dart-define=ACADEMIC_TIMETABLE_API_ENABLED=true \
  --dart-define=ANALYTICS_INTELLIGENCE_API_ENABLED=true \
  --dart-define=AI_COPILOT_ENABLED=true \
  --dart-define=PAYMENT_API_ENABLED=true \
  --dart-define=COMMUNICATION_API_ENABLED=true \
  --dart-define=AUDIT_API_ENABLED=true \
  --dart-define=ONBOARDING_API_ENABLED=true \
  --dart-define=PARENT_API_ENABLED=true \
  --dart-define=TEACHER_API_ENABLED=true \
  --dart-define=STUDENT_API_ENABLED=true \
  --dart-define=PHASE5_API_ENABLED=true \
  --dart-define=INVENTORY_FINANCE_API_ENABLED=true \
  --dart-define=SCHOOL_COMPLETION_API_ENABLED=true
```

**Output:** `build/ios/ipa/*.ipa`

### Option B — Xcode archive

1. Open `ios/Runner.xcworkspace` (not `.xcodeproj`)
2. Select **Any iOS Device (arm64)** as destination
3. Product → Archive
4. Window → Organizer → Distribute App

---

## Apple Developer requirements

| Item | Value |
|------|-------|
| Bundle ID | `com.akshara.erp.aksharaErp` |
| App name | Akshara ERP |
| Team | Your Apple Developer Program team |
| Signing | Automatic (Development) or Manual (Distribution) |
| Capabilities | None required for pilot (no push entitlement in v16.7) |

### Register bundle ID

1. [Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Add App ID: `com.akshara.erp.aksharaErp`
3. Enable only capabilities you need (none for basic pilot)

### Signing in Xcode

1. Open `ios/Runner.xcworkspace`
2. Select **Runner** target → **Signing & Capabilities**
3. Check **Automatically manage signing**
4. Select your **Team**
5. Confirm bundle identifier matches

For CI/CD later, use `ExportOptions.plist` with `method: app-store` or `ad-hoc`.

---

## TestFlight workflow

### 1. Archive and upload

```bash
flutter build ipa --release [dart-defines...]
# Or upload via Xcode Organizer
```

Or with Xcode:

1. Archive (Product → Archive)
2. Organizer → **Distribute App**
3. **App Store Connect** → Upload
4. Wait for processing (~5–30 min)

### 2. App Store Connect setup

1. Create app: **Akshara ERP**
2. SKU: `akshara-erp-pilot`
3. Primary language: English
4. Bundle ID: `com.akshara.erp.aksharaErp`

### 3. Internal testing

1. App Store Connect → TestFlight → Internal Testing
2. Add build from processed upload
3. Add internal testers (up to 100, same team)
4. Testers install **TestFlight** app and accept invite

### 4. External testing (friends / pilot school)

1. TestFlight → External Testing → Create group
2. Add build + complete **Beta App Review** questionnaire
3. Add tester emails (up to 10,000)
4. Share public link optional

### 5. Tester install steps

1. Install **TestFlight** from App Store
2. Open invite email or public link
3. Install **Akshara ERP**
4. Follow `docs/Testing/Tester-Instructions.md`

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Application not configured for iOS` | Run `cd ios && pod install` |
| `No signing certificate` | Add Apple ID in Xcode → Settings → Accounts |
| Plugin Swift Package Manager warning | Safe to ignore for `printing`, `flutter_secure_storage` in v16.7 |
| Build fails on M1/M2 | Use `arch -arm64 pod install` if Rosetta conflicts |

---

## Readiness checklist

- [ ] Full Xcode installed and selected via `xcode-select`
- [ ] CocoaPods installed
- [ ] `pod install` succeeds in `ios/`
- [ ] Bundle ID registered in Apple Developer portal
- [ ] Signing team configured in Xcode
- [ ] `flutter build ipa --release` completes
- [ ] Build uploaded to TestFlight
- [ ] Internal tester can install and reach login screen

---

## Reference

- Android builds: `scripts/build_release.sh`
- Device testing: `docs/Testing/Device-Testing-Guide.md`
- Demo accounts: `docs/Testing/Demo-Accounts.md`
