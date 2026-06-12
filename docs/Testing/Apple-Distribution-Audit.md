# Apple Distribution Audit — Akshara ERP

**Release:** v17.1 (`v17.1-apple-distribution-readiness`)  
**Date:** June 2026  
**Build:** 17.1.0 (171)  
**Audit scope:** Signing, certificates, provisioning — **no code changes**

---

## Project configuration (verified)

| Item | Value | Status |
|------|-------|--------|
| Bundle identifier | `com.akshara.erp.aksharaErp` | ✅ Consistent in `Info.plist` + `project.pbxproj` |
| Display name | Akshara ERP | ✅ `ios/Runner/Info.plist` |
| Version | 17.1.0 | ✅ `pubspec.yaml` |
| Build number | 171 | ✅ `pubspec.yaml` |
| Deployment target | iOS 13.0 | ✅ Podfile + Xcode |
| Team ID | `63YXKNM6UN` | ✅ Set on Runner target |
| Team name | Surendra Kanna | ✅ Xcode automatic signing |
| Signing style | Automatic | ✅ `CODE_SIGN_STYLE = Automatic` |
| Archive artifact | `build/ios/archive/Runner.xcarchive` | ✅ Generated (v17.0 session) |

---

## Certificate status

Command: `security find-identity -v -p codesigning`

| Certificate type | Status | Details |
|------------------|--------|---------|
| **Apple Development** | ✅ Present | `Apple Development: surendra303@gmail.com (Q25TX7GAV7)` |
| **Apple Distribution** | ❌ **Missing** | Required for IPA export / TestFlight upload |
| iOS Distribution (legacy name) | ❌ Missing | Same requirement — App Store export |

**Impact:** Archive builds succeed with Development signing. `flutter build ipa` export step fails without Distribution.

---

## Provisioning profile status

| Profile type | Status | Details |
|--------------|--------|---------|
| Development (automatic) | ✅ Implicit | Xcode managed via Development cert |
| **App Store / Distribution** | ❌ **Missing** | No profile for `com.akshara.erp.aksharaErp` |
| Local profile cache | ❌ Empty | `~/Library/MobileDevice/Provisioning Profiles/` not present |

**Export errors observed (v17.0 IPA attempt):**

```
No signing certificate "iOS Distribution" found
Team "Surendra Kanna" does not have permission to create "iOS App Store" provisioning profiles
No profiles for 'com.akshara.erp.aksharaErp' were found
```

---

## Apple account requirements (exact)

These actions **must be performed by the Apple account owner** in Apple Developer / App Store Connect. Cursor cannot automate them.

### 1. Apple Developer Program membership

| Check | Action |
|-------|--------|
| Active paid membership ($99/yr) | Confirm at [developer.apple.com/account](https://developer.apple.com/account) |
| Account Holder or Admin role | Required to create Distribution certificates and App Store profiles |
| App Store Connect access | Required for TestFlight |

If the team lacks permission to create App Store profiles, the account may be on a **free Personal Team** or a role without certificate management. Upgrade or switch to the Account Holder Apple ID.

### 2. Register Bundle ID (if not done)

1. [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) → **Identifiers** → **+**
2. Type: **App IDs** → **App**
3. Bundle ID: **`com.akshara.erp.aksharaErp`**
4. Description: **Akshara ERP**
5. Enable only capabilities the app uses (none required for pilot — HTTPS only)

### 3. Create Apple Distribution certificate

1. **Certificates** → **+** → **Apple Distribution**
2. Follow CSR flow (Keychain Access → Certificate Assistant → Request Certificate)
3. Download and double-click to install in Keychain
4. Verify: `security find-identity -v -p codesigning` shows **Apple Distribution**

### 4. Create App Store provisioning profile

1. **Profiles** → **+** → **App Store Connect** (or **App Store**)
2. App ID: `com.akshara.erp.aksharaErp`
3. Certificate: select the **Apple Distribution** cert from step 3
4. Download profile (Xcode auto-imports on next archive if automatic signing enabled)

### 5. App Store Connect app record

1. [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+**
2. Platform: iOS · Name: **Akshara ERP** · Bundle ID: `com.akshara.erp.aksharaErp`
3. SKU: e.g. `akshara-erp-ios`

---

## Build pipeline status

| Stage | Automated? | Status |
|-------|:----------:|--------|
| `flutter doctor` / Xcode | ✅ | Green with `DEVELOPER_DIR` / xcrun wrapper |
| `pod install` | ✅ | Clean |
| Native assets (`objective_c`) | ✅ | Fixed via `scripts/ios/xcrun` wrapper |
| Xcode archive | ✅ | `Runner.xcarchive` builds |
| IPA export | ⏳ | Blocked on Distribution cert + profile |
| TestFlight upload | ⏳ | Blocked on IPA or Organizer upload |

---

## Related docs

- [TestFlight-Execution-Guide.md](TestFlight-Execution-Guide.md) — step-by-step owner actions
- [TestFlight-Upload-Guide.md](TestFlight-Upload-Guide.md) — build commands reference
- [Apple-Go-Live-Checklist.md](Apple-Go-Live-Checklist.md) — final sign-off
