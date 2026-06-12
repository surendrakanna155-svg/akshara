# TestFlight Execution Guide — Akshara ERP

**Release:** v17.1 (`v17.1-apple-distribution-readiness`)  
**Bundle ID:** `com.akshara.erp.aksharaErp`  
**Team ID:** `63YXKNM6UN`  
**Version:** 17.1.0 (171)  
**Prerequisite:** Xcode archive already builds — see [Apple-Distribution-Audit.md](Apple-Distribution-Audit.md)

---

## Overview

| Phase | Who | Outcome |
|-------|-----|---------|
| 1 Distribution certificate | **Owner (Apple ID)** | Apple Distribution cert in Keychain |
| 2 App Store profile | **Owner (Apple ID)** | Provisioning profile for bundle ID |
| 3 Archive upload | **Owner or build Mac** | Build in App Store Connect |
| 4 Internal testing | **Owner** | Team testers install via TestFlight |
| 5 External testing | **Owner** | Friends / pilot school (Beta App Review) |

Cursor has completed all repo-side automation. Remaining steps are **Apple account actions only**.

---

## Phase 1 — Create Apple Distribution certificate

### Prerequisites

- Active **Apple Developer Program** membership (paid)
- Logged in as **Account Holder** or **Admin**
- Mac with Keychain Access

### Steps

1. Open [developer.apple.com/account/resources/certificates/list](https://developer.apple.com/account/resources/certificates/list)
2. Click **+** (Create Certificate)
3. Select **Apple Distribution** → Continue
4. On Mac: **Keychain Access** → **Certificate Assistant** → **Request a Certificate From a Certificate Authority**
   - Email: your Apple ID email
   - Common Name: `Akshara ERP Distribution`
   - Save to disk → `CertificateSigningRequest.certSigningRequest`
5. Upload CSR on Apple Developer portal → **Continue** → **Download** certificate
6. Double-click `.cer` file → installs in Keychain (**login** keychain)

### Verify

```bash
security find-identity -v -p codesigning
```

Expected line:

```
"Apple Distribution: Surendra Kanna (63YXKNM6UN)"
```

---

## Phase 2 — Create App Store provisioning profile

### Register Bundle ID (one-time)

If `com.akshara.erp.aksharaErp` is not listed under **Identifiers**:

1. **Identifiers** → **+** → **App IDs** → **App**
2. Bundle ID: **Explicit** → `com.akshara.erp.aksharaErp`
3. Register

### Create profile

1. [Profiles](https://developer.apple.com/account/resources/profiles/list) → **+**
2. Select **App Store Connect** (distribution to App Store / TestFlight)
3. App ID: **com.akshara.erp.aksharaErp**
4. Certificate: select **Apple Distribution** from Phase 1
5. Profile name: `Akshara ERP App Store`
6. **Generate** → **Download**

Xcode imports automatically on next build, or double-click the `.mobileprovision` file.

### Verify in Xcode

```bash
open ios/Runner.xcworkspace
```

1. **Runner** target → **Signing & Capabilities**
2. **Release** configuration → Team: **Surendra Kanna (63YXKNM6UN)**
3. **Automatically manage signing** = ON
4. No red provisioning errors

---

## Phase 3 — Archive upload flow

### Option A — Re-export IPA (CLI)

After Distribution cert + profile are installed:

```bash
source scripts/setup_ios_env.sh
./scripts/build_release.sh ipa
```

Expected:

```
✓ Built build/ios/ipa/akshara_erp.ipa
```

Upload via **Transporter** app or:

```bash
open -a Transporter build/ios/ipa/akshara_erp.ipa
```

### Option B — Xcode Organizer (recommended first upload)

If an archive already exists:

```bash
open build/ios/archive/Runner.xcarchive
```

Or: Xcode → **Window** → **Organizer** → select latest archive.

1. **Distribute App**
2. **App Store Connect** → **Upload**
3. **Automatically manage signing**
4. Upload includes symbols (recommended: yes)
5. Wait for processing in App Store Connect (5–30 min)

### App Store Connect — first-time setup

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**
2. Platform: **iOS**
3. Name: **Akshara ERP**
4. Primary language: English
5. Bundle ID: **com.akshara.erp.aksharaErp**
6. SKU: `akshara-erp-ios`

---

## Phase 4 — Internal testing flow

Internal testers = up to 100 App Store Connect users with Admin/Developer/Marketing roles. **No Beta App Review.**

1. App Store Connect → **Akshara ERP** → **TestFlight** tab
2. Wait until build status = **Ready to Test**
3. Complete **Export Compliance**:
   - Uses encryption? → Typically **No** (HTTPS only, no custom crypto)
4. **Internal Testing** → **+** → create group e.g. `Akshara Pilot Internal`
5. Add build **17.1.0 (171)**
6. Add internal testers by email (must have App Store Connect access)
7. Testers receive email → install **TestFlight** app → install Akshara ERP

**Tester doc:** [iPhone-Tester-Pack.md](iPhone-Tester-Pack.md)  
**Demo accounts:** [Demo-Accounts.md](Demo-Accounts.md)

---

## Phase 5 — External testing flow

External testers = friends, pilot school staff, anyone with an email. Requires **Beta App Review** (usually 24–48 h first time).

1. **TestFlight** → **External Testing** → **+** → create group e.g. `Akshara Pilot Friends`
2. Add build **17.1.0 (171)**
3. Complete **Test Information**:
   - Beta app description: school ERP pilot — parent, teacher, student apps
   - Feedback email: owner support address
   - What to test: link to [Real-User-Journeys.md](Real-User-Journeys.md)
4. Submit for **Beta App Review**
5. After approval, add testers by email or public link
6. Testers install via TestFlight (no App Store Connect account needed)

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `No signing certificate "iOS Distribution" found` | Complete Phase 1 |
| `No profiles for 'com.akshara.erp.aksharaErp'` | Complete Phase 2 |
| `does not have permission to create App Store provisioning profiles` | Use Account Holder Apple ID or upgrade to paid Developer Program |
| Build stuck "Processing" | Wait 30 min; check email for Apple compliance issues |
| TestFlight install fails | Tester must accept invite; iOS 13+ required |

---

## Checklist summary

- [ ] Apple Developer Program active (paid)
- [ ] Apple Distribution certificate in Keychain
- [ ] App Store provisioning profile for `com.akshara.erp.aksharaErp`
- [ ] App record in App Store Connect
- [ ] Archive uploaded (Organizer or Transporter)
- [ ] Export compliance answered
- [ ] Internal TestFlight group + testers added
- [ ] (Optional) External group submitted for Beta Review

---

## Related docs

- [Apple-Distribution-Audit.md](Apple-Distribution-Audit.md)
- [TestFlight-Upload-Guide.md](TestFlight-Upload-Guide.md)
- [Apple-Go-Live-Checklist.md](Apple-Go-Live-Checklist.md)
- [Final-Device-Readiness.md](Final-Device-Readiness.md)
