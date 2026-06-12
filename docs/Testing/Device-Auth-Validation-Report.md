# Device Auth Validation Report — v17.4

**Tag:** `v17.4-device-auth-validation`  
**Build:** 17.3.0+173 (v17.3 authentication-hardening artifacts)  
**Date:** June 2026  
**API:** Staging (`oeicxjpewrumkfgyqnnj.supabase.co`)

Machine-readable summary: `reports/device_auth_v17_4/summary.json`

---

## Build configuration

| Flag | Value |
|------|-------|
| `APP_ENV` | `staging` |
| `ENABLE_API_MODE` | `true` |
| `AUTH_API_ENABLED` | `true` |
| `ENABLE_DEMO_AUTH` | `false` (default hardened) |

Artifacts:

| Platform | Path |
|----------|------|
| Android APK | `build/app/outputs/flutter-apk/app-release.apk` |
| iOS device app | `build/ios/iphoneos/Runner.app` |

---

## Install status

### Android — OnePlus7 (`014e7e76`)

| Step | Result |
|------|--------|
| Uninstall `com.akshara.erp` | Failed (`DELETE_FAILED_INTERNAL_ERROR`) |
| Install APK (`adb install -r`) | **Success** |
| Launch | **Success** (monkey launcher) |

### iPhone — Kanna's iPhone (`00008120-001131801A60201E`)

| Step | Result |
|------|--------|
| Build + install (`ios_device_install.sh`) | **Success** |
| Automated launch (`devicectl`) | **Blocked** — device locked |
| Manual launch | Requires home-screen tap after developer trust |

---

## Authentication results

### Negative tests (API)

| Test | Expected | Result |
|------|----------|--------|
| Random phone `9999999999` → wrong OTP `000000` | Rejected | **PASS** — `OTP_INVALID` |
| Seeded phones → wrong OTP `000000` | Rejected | **PASS** — `OTP_INVALID` for all personas |

**Note:** Staging dev mode still **sends OTP for arbitrary phones** on `/auth/login`. Hardened mobile app rejects invalid OTP at verify; full rejection at send requires production SMS policy or backend allow-list (out of scope for this validation).

### Seeded accounts (API verify-otp)

| Persona | Phone | OTP from API | Wrong OTP | Correct OTP / scope |
|---------|-------|--------------|-----------|---------------------|
| Parent | `9000100001` | Yes | Rejected | **PASS** — `scope=parent` |
| Teacher | `9000000001` | Yes | Rejected | **FAIL** — `scope=teacher` → `MEMBERSHIP_NOT_FOUND`; no scope → `scope=school`, role `principal` |
| Student | `9876543212` | Yes | Rejected | **PASS** — `scope=student` |
| Principal | `9876543210` | Yes | Rejected | **PASS** — `scope=school` (Staff ERP portal) |

Mobile client calls verify without explicit scope (matches parent/student; teacher blocked by backend membership).

### Device UI (Android)

Fresh install shows hardened login screen:

- Copy: *"Enter your registered mobile number. OTP is verified by the staging server."*
- No demo role chips (correct for `ENABLE_DEMO_AUTH=false`)
- **Staff ERP portal** link visible below Continue

Screenshot: `reports/device_auth_v17_4/android_splash_or_login.png`

iPhone UI OTP walkthrough not captured — device locked during automated launch.

---

## First-screen audit

| Item | Finding |
|------|---------|
| **First screen after install** | `SplashScreen` (~2s) → `LoginScreen` when no valid session |
| **Login flow** | Phone → OTP screen → API verify → role dashboard via server scope |
| **Onboarding paths (mobile)** | None on first run |
| **School creation path** | Not exposed on mobile splash/login |
| **Super admin bootstrap** | Not on mobile; Staff ERP at `/staff/login` with ERP role selection in testing mode only |
| **ERP onboarding hub** | `/sis/onboarding` — post-auth ERP shell only (`OnboardingHubScreen`) |

---

## Screenshots

| Platform | File |
|----------|------|
| Android login (post-install) | `reports/device_auth_v17_4/android_splash_or_login.png` |
| Android lock screen (ambient capture) | `reports/device_auth_v17_4/android_first_screen.png` |
| iPhone | *Pending — unlock device and capture manually* |

---

## Recommendation

**Next phase: onboarding routing fixes** (not greenfield onboarding implementation).

Reasons:

1. Mobile first-run routing is correct after v17.3 hardening (splash → login, no mock bypass).
2. Teacher persona cannot reach teacher mobile dashboard — backend scope/membership gap.
3. School onboarding exists only inside authenticated ERP (`/sis/onboarding`), not as a first-run mobile path.
4. No super-admin bootstrap wizard on mobile; staff uses separate portal.

---

## Remaining blockers

1. Teacher mobile login — `MEMBERSHIP_NOT_FOUND` for `scope=teacher` on all probed teacher phones.
2. Teacher phone without scope resolves to principal/school — wrong dashboard if verify succeeds.
3. Principal must use **Staff ERP portal**, not mobile login.
4. iPhone manual validation — trust developer cert, unlock, complete OTP flows on device.
5. Production OTP — staging returns OTP in API body (`AUTH_OTP_DEV_MODE`); SMS required for go-live.
