# TestFlight Upload Guide — Akshara ERP Pilot

**Release:** v17.0 (`v17.0-ios-release-readiness`)  
**Bundle ID:** `com.akshara.erp.aksharaErp`  
**Display name:** Akshara ERP  
**Version:** 17.0.0 (build 170)  
**Deployment target:** iOS 13.0  
**Staging API:** `https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api`

---

## Prerequisites checklist

| Requirement | Status | Action if missing |
|-------------|--------|-------------------|
| Full Xcode.app installed | ✅ | App Store → Xcode |
| `xcode-select` → Xcode.app | ⚠️ Manual | See § Environment below |
| CocoaPods 1.16+ | ✅ | `brew install cocoapods` |
| `pod install` clean | ✅ | `cd ios && pod install` |
| Apple Developer Program ($99/yr) | ⏳ Required for TestFlight | [developer.apple.com](https://developer.apple.com) |
| Code signing certificate | ❌ **Blocker** | Sign in to Xcode with Apple ID |
| App Store Connect app record | ⏳ | Create with matching Bundle ID |

---

## Environment setup (build Mac)

### 1. Point developer tools to full Xcode

If `flutter doctor` shows Command Line Tools instead of Xcode:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
```

Verify:

```bash
source scripts/setup_ios_env.sh
flutter doctor -v
```

Expected: `[✓] Xcode - develop for iOS and macOS (Xcode 26.5)`

### 2. Session environment (when sudo not yet run)

```bash
source scripts/setup_ios_env.sh
# or rely on ios/Flutter/xcode.env.local (committed)
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Without this, native-asset hooks (`objective_c`) fail with `xcrun: SDK "iphonesimulator" cannot be located`.

### 3. CocoaPods

```bash
cd ios && pod install && cd ..
```

---

## Signing configuration (Xcode)

1. Open workspace: `open ios/Runner.xcworkspace`
2. Select **Runner** project → **Runner** target → **Signing & Capabilities**
3. Check **Automatically manage signing**
4. Select your **Team** (Apple Developer account)
5. Confirm **Bundle Identifier:** `com.akshara.erp.aksharaErp`
6. Resolve any provisioning profile errors (Xcode → Register Device if needed)

Verify certificates:

```bash
security find-identity -v -p codesigning
# Expected: at least one "Apple Development" or "Apple Distribution" identity
```

---

## Build IPA

### Option A — release script (recommended)

```bash
source scripts/setup_ios_env.sh
./scripts/build_release.sh ipa
```

### Option B — Flutter CLI

```bash
source scripts/setup_ios_env.sh
flutter pub get
flutter build ipa --release \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api \
  --dart-define=ENABLE_API_MODE=true \
  --dart-define=ADMISSIONS_API_ENABLED=true \
  --dart-define=FINANCE_API_ENABLED=true \
  --dart-define=SIS_API_ENABLED=true \
  --dart-define=ACADEMIC_API_ENABLED=true
```

**Expected output:** `build/ios/ipa/akshara_erp.ipa`

---

## Upload to TestFlight

### Option A — Xcode Organizer (easiest)

1. After successful `flutter build ipa`, open Xcode → **Window → Organizer**
2. Select the archive → **Distribute App**
3. Choose **App Store Connect** → **Upload**
4. Follow prompts (automatic signing, bitcode off, symbols upload)

### Option B — Transporter app

1. Download [Transporter](https://apps.apple.com/app/transporter/id1450874784) from Mac App Store
2. Drag `build/ios/ipa/*.ipa` into Transporter
3. Click **Deliver**

### Option C — altool / xcrun (CI)

```bash
xcrun altool --upload-app -f build/ios/ipa/akshara_erp.ipa \
  -t ios -u YOUR_APPLE_ID -p @keychain:AC_PASSWORD
```

---

## App Store Connect steps

1. [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+** → New App
2. Platform: iOS · Name: **Akshara ERP** · Bundle ID: `com.akshara.erp.aksharaErp`
3. After upload processing (~5–30 min): **TestFlight** tab
4. Add **Internal Testing** group → invite testers by email
5. Complete **Export Compliance** (typically "No" for standard HTTPS-only app)
6. Add **What to Test** notes from [iPhone-Tester-Pack.md](iPhone-Tester-Pack.md)

---

## Metadata audit (v17.0)

| Field | Value | Location |
|-------|-------|----------|
| Bundle ID | `com.akshara.erp.aksharaErp` | `ios/Runner.xcodeproj` |
| Display name | Akshara ERP | `ios/Runner/Info.plist` |
| Version | 17.0.0 | `pubspec.yaml` |
| Build number | 170 | `pubspec.yaml` |
| Icons | ✅ Full set incl. 1024×1024 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| Launch screen | ✅ LaunchImage | `ios/Runner/Assets.xcassets/LaunchImage.imageset/` |
| Orientations | Portrait + landscape | `Info.plist` |
| Signing | ❌ Not configured | Requires Apple Developer login |

---

## Current build status (v17.0)

| Step | Result |
|------|--------|
| `flutter doctor` (with `DEVELOPER_DIR`) | ✅ All green |
| `pod install` | ✅ 3 pods |
| iOS release compile | ✅ Xcode build succeeds |
| `flutter build ipa` | ❌ **No code signing certificates** |
| IPA artifact | ❌ Not generated — complete signing first |

**Next action:** Sign in to Xcode → select Team → re-run `./scripts/build_release.sh ipa`

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `No valid code signing certificates` | Xcode → Settings → Accounts → add Apple ID → select Team on Runner target |
| `xcrun: SDK cannot be located` | `source scripts/setup_ios_env.sh` or fix `xcode-select` |
| `objective_c` native assets fail | Same as above — `DEVELOPER_DIR` must point to Xcode.app |
| `IPHONEOS_DEPLOYMENT_TARGET` 9.0 warning | Fixed in `ios/Podfile` post_install (13.0) |
| Swift Package Manager plugin warning | Informational for `printing` / `flutter_secure_storage` — not blocking |

---

## Related docs

- [iOS-Build-Guide.md](iOS-Build-Guide.md)
- [iOS-Execution-Checklist.md](iOS-Execution-Checklist.md)
- [iPhone-Tester-Pack.md](iPhone-Tester-Pack.md)
- [Demo-Accounts.md](Demo-Accounts.md)
