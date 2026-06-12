# Device Testing Guide — Akshara ERP Pilot Builds

**Release:** v16.6 (`v16.6-release-build`)  
**Build version:** 16.6.0 (166)  
**Environment:** Staging API with demo-auth fallback for offline QA

---

## Install artifacts

| Platform | Path | Use case |
|----------|------|----------|
| Android APK | `build/app/outputs/flutter-apk/app-release.apk` | Direct sideload to phones/tablets |
| Android AAB | `build/app/outputs/bundle/release/app-release.aab` | Play Console internal testing |
| iOS IPA | `build/ios/ipa/*.ipa` | TestFlight / Ad Hoc (requires signing) |

Regenerate:

```bash
chmod +x scripts/build_release.sh
./scripts/build_release.sh all
```

---

## Demo personas & credentials

### Staging API login (recommended)

OTP is returned in the login API response when staging dev mode is enabled.

| Persona | Phone | Notes |
|---------|-------|-------|
| **Principal / School admin** | `9876543210` | ERP web shell after staff login |
| **Teacher 1** | `9000000001` | Teacher mobile app |
| **Teacher 2** | `9000000002` | Alternate teacher |
| **Parent (student 1)** | `9000100001` | Parent mobile app |
| **Parent (student 2)** | `9000100002` | Second parent account |

After OTP verify, the app routes to the correct persona shell (ERP admin vs mobile).

### Offline / mock fallback

When API is unreachable, use the role selector on the login screen:

| Persona | Mock OTP | Role selector |
|---------|----------|---------------|
| Principal | `123456` (or any 6 digits) | Staff → set ERP role to **Principal** |
| Teacher | `123456` | **Teacher** |
| Parent | `123456` | **Parent** |
| Student | `123456` | **Student** |

Mock mode uses local demo data; staging API mode uses seeded demo school data.

---

## Key workflows to test

### Principal (ERP web / tablet)

1. Login → Management dashboard
2. **Intelligence hub** — principal summary, risk cards
3. **Finance** — executive KPIs, defaulters
4. **Operations** — admissions, SIS registry

**Screens:** Management dashboard, Intelligence hub, Finance dashboard, Admissions enrollment.

### Teacher (mobile)

1. Dashboard → greeting, today schedule, attendance summary
2. **Attendance** — mark present/absent
3. **Homework** — assigned list
4. **Lesson logs** — school completion entry

**Screens:** Teacher dashboard, Attendance, Homework, AI Copilot (if enabled).

### Parent (mobile)

1. Dashboard → child summary, notices, events
2. **Attendance** — monthly view
3. **Fees** — payment status
4. **Progress** — academic summary / experience hub
5. **Inventory** — book kit status (if assigned)

**Screens:** Parent dashboard, Parent Experience Hub, Notifications.

### Student (mobile)

1. Dashboard → schedule strip, homework due
2. **Homework** — assignments list
3. **Timetable** — weekly view
4. **Exams** — upcoming papers

**Screens:** Student dashboard, Homework, Timetable, Exams.

---

## Pre-flight checklist

- [ ] Device has network (Wi‑Fi or mobile data)
- [ ] APK installed from release build (not debug)
- [ ] No debug banner visible on launch
- [ ] Splash → login screen within 3 seconds
- [ ] OTP flow completes for at least one persona
- [ ] Back navigation returns to dashboard (no dead ends)
- [ ] Rotate device on dashboard — no overflow errors

---

## iOS signing requirements

IPA generation requires a Mac with:

1. **Xcode** (App Store or full install) — `xcode-select --switch /Applications/Xcode.app/Contents/Developer`
2. **CocoaPods** — `sudo gem install cocoapods` then `cd ios && pod install`
3. **Apple Developer account** — Team ID for signing
4. **Bundle ID:** `com.akshara.erp.aksharaErp` (registered in Apple Developer portal)
5. **Provisioning profile** — Development or Ad Hoc for pilot testers

```bash
# After Xcode setup:
flutter build ipa --release \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api \
  --dart-define=ENABLE_API_MODE=true
```

For TestFlight: archive via Xcode → Organizer → Distribute App.

**Current CI machine note:** If Xcode is not installed, only Android artifacts are produced locally; iOS builds must run on a signed Mac.

---

## Reporting issues

Include:

- Device model + OS version
- Build version (Settings → About → 16.6.0)
- Persona + phone used
- Steps to reproduce
- Screenshot or screen recording

File under `reports/pilot_validation/` or project issue tracker.

---

## Reference

- Demo seed phones: `docs/Operations/Pilot/Demo-Data-Guide.md`
- Deployment flags: `docs/Operations/Deployment-Guide.md`
- UI stress coverage: `docs/Releases/v16.5-UI-Stress-Test.md`
