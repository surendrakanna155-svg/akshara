# Play Store + Notifications Readiness

**Date:** 2026-06-24  ·  **App:** `com.akshara.erp` v18.6.2+187

## A. Notifications

### Transactional SMS — **certified ready, one flag from go-live**
- Provider: Fast2SMS, configured on the VPS edge (`SMS_PROVIDER`, `SMS_PROVIDER_API_KEY`, `FAST2SMS_ROUTE`).
- Key is **live and funded**: wallet ₹234.40, 937 SMS credits (verified via Fast2SMS `/wallet`, no send).
- Hooks wired + gated by `transactionalSmsEnabled` (`TRANSACTIONAL_SMS_ENABLED`, currently unset → **off**):
  - **Fee receipt:** `Akshara: Payment of Rs {amount} received for {name}. Receipt available in the app.`
  - **Results published:** `Akshara: Results for {exam_title} are now published for {name}. View them in the app.`
- Unit tests: `sms_provider_test.ts` 11/11 green. Same sender already proves out via the live OTP path.
- **Go-live = one env flag** on the VPS, then recreate the edge:
  ```
  # in /opt/akshara/.env.akshara
  TRANSACTIONAL_SMS_ENABLED=true
  # then: docker compose -f docker-compose.akshara.yml up -d --force-recreate akshara-edge
  ```
  ⚠️ Owner decision: this sends **real, paid** SMS to real parents on every fee receipt / results
  publish. Recommend enabling once the pilot school is ready to receive them.

### Push notifications (Firebase/FCM) — **LIVE (Android)** ✅
- Superseded by `docs/FCM_PUSH_HTTP_V1_CERTIFICATION.md`: real push via modern FCM HTTP v1
  (service-account OAuth) is wired and live-certified. `firebase_core`/`firebase_messaging` are
  integrated, `POST_NOTIFICATIONS` is declared, device-token register/refresh + foreground/background
  handlers + deep-link routing (`data.route`) are in place. Per-event deep links are populated on the
  enqueue paths as of Wave 5 (NOT-1).
- VPS secret `FCM_SERVICE_ACCOUNT_JSON` (base64) is set; `google-services.json` is present for the app.
- iOS push remains deferred (needs `GoogleService-Info.plist` + APNs `.p8`) — Android-only by design (NOT-2).

## B. Play Store readiness

### Done ✅
- **applicationId** `com.akshara.erp`, version 18.6.2+187, display name "Akshara ERP".
- **targetSdk 36 / compileSdk 36 / minSdk 24** — pinned explicitly in `android/app/build.gradle.kts`
  (PLY-3), above Play's 2025 API-35 target requirement.
- **Permissions** minimal + justifiable: `INTERNET`, `POST_NOTIFICATIONS`. No location/contacts/storage.
- **R8 minify + resource shrink** enabled; `proguard-rules.pro` present.
- **Release build verified**: `bash scripts/build_release.sh aab` builds `app-release.aab` against the
  **live** backend (`config/live_release.json` → `APP_ENV=production`, `ENABLE_API_MODE=true`,
  `API_BASE_URL=https://akshara.veloraunisexsalon.com`). NOTE: a plain `flutter build --release` (no
  dart-defines) builds a localhost/mock app — always use the release script for store builds.
- **Privacy policy hosted**: <https://akshara.veloraunisexsalon.com/privacy> (200, text/html) and wired
  into the app (`LegalLinks.privacyPolicyUrl`).

### Owner-gated ⚠️
1. **Upload keystore** — run the `keytool` command in `android/key.properties.example`, fill
   `android/key.properties` (git-ignored), keep the `.jks` + passwords backed up safely. Enrol in
   Play App Signing on first upload. (I can generate it on request, but the owner must custody the secret.)
2. **Privacy policy legal details** — replace 5 placeholders in `docs/legal/PRIVACY_POLICY.md`
   (legal entity name, registered address, contact email, grievance officer) and I'll re-publish.
3. **Play Console** — developer account ($25 one-time), store listing (screenshots, feature graphic,
   descriptions), and the **Data Safety** form. App collects: name, phone, email, optional masked Aadhaar,
   academic/financial/family-linkage data, device/diagnostic data → declare as "collected, encrypted in
   transit, not sold, not for ads"; data deletion via the Institution.

### Not blocking
- App icon present (`ic_launcher`). Screenshots/feature-graphic = owner assets.
