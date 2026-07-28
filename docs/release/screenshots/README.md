# Play Store screenshots — NIKSHA OS

**Status: 3 captured — above Play's minimum of 2, below the recommended 8.** Read §3 before publishing.

## 1. How these were produced

Every PNG here is a real screen capture of the real app running on a real
Android device. Nothing is mocked, composited, upscaled, or drawn by hand.

| Property | Value |
|---|---|
| Device | Android emulator, `sdk_gphone64_arm64`, **Android 16 (API 36)** |
| Capture size | **1080 × 2160** (`adb shell wm size 1080x2160`) |
| Build | `flutter build apk --profile --dart-define=ENABLE_DEMO_AUTH=true` |
| Data | The app's built-in demo school (1,248 students, 86 staff) |
| Captured | 2026-07-28, from commit on `release/v1.0-playstore` |

**Why 1080×2160 and not the emulator's native 1080×2400.** Play requires each
side to be 320–3840px AND the long side to be **at most twice** the short side.
2400 / 1080 = 2.22, which fails. 2160 / 1080 = 2.00 exactly, which passes.
Reset the device afterwards with `adb shell wm size reset`.

**Why a profile build and not a release build.** A release binary *cannot* run
here: `Environment.guardForRelease` refuses to start unless `APP_ENV=production`
AND `ENABLE_API_MODE=true` — i.e. against the live backend, whose credentials are
owner-held. That guard is deliberate (SEC-1/SEC-2) and is not being worked
around. A profile build is the same compiled Dart and the same widget tree; only
the data source differs.

**Why `ENABLE_DEMO_AUTH` and not `QA_AUTOMATION`.** `QA_AUTOMATION=true` enables
the QA persona picker, which paints a **"QA visual test — tap to switch persona"**
banner across the top of every screen. That banner does not exist in a shipping
build, so a screenshot containing it would misrepresent the app. Demo auth gives
the same screens with no QA chrome.

## 2. What is here

| File | Screen | Notes |
|---|---|---|
| `01-admin-hub.png` | Admin Hub — School Administration workspace | Signed in as Principal. Workspace header (students / staff / attendance) + authorised-module list. |
| `02-teacher-dashboard.png` | Teacher home | Check-in state (Geo+Face verified), an actionable "attendance not marked" nudge, 89% present ring, today's classes. |
| `03-mark-attendance.png` | Mark Attendance — exception-first | P/A/L badges, All-present / All-absent / Fill-remaining shortcuts, live "1 present · 1 absent · 1 late" tally. **See the known issue below before using this one in the listing.** |

## 3. What is still needed — and why it stopped here

Play requires **a minimum of 2** phone screenshots and allows up to 8. Three are
captured, so the set is *submittable* — but thin, and missing Student 360, which
is the single strongest screen the product has.

**Known issue affecting `03-mark-attendance.png`:** the raised centre AI button
(`CopilotBottomNavAiSlot`, docked above the bottom nav by design — see UXR-G2)
overlaps the screen's own "Save draft / N unmarked" action bar. It is real, not a
capture artifact, and it is an owner decision rather than an obvious bug: either
the AI affordance yields on screens with a bottom action bar, or those screens
reserve space for it. Until that is decided, prefer screens without a bottom
action bar for the listing.

The remaining shots need UI navigation that is best done by hand — driving them
blind through `adb shell input tap` produces mid-animation frames (a drawer
caught half-open was discarded rather than shipped). The order below is the one
recommended in `../PLAY_STORE_LISTING_V1.md` §5, chosen to tell the buying story:

1. ✅ Admin Hub *(captured)*
2. ✅ Teacher dashboard *(captured)*
3. ✅ Teacher attendance — exception-first marking *(captured)*
4. ⬜ **Student 360** — the differentiator; the whole reason a principal buys
5. ⬜ Marks entry — the speed story
5. ⬜ Parent — marks / report card
6. ⬜ Parent — fees and receipt
7. ⬜ Ask-anything search (DAI)
8. ⬜ Dark mode — any of the above

## 4. Repeatable capture procedure

```bash
flutter build apk --profile --dart-define=ENABLE_DEMO_AUTH=true
adb install -r build/app/outputs/flutter-apk/app-profile.apk
adb shell wm size 1080x2160

adb shell monkey -p com.akshara.erp -c android.intent.category.LAUNCHER 1
# Allow the notification prompt on first run.
# Sign in: pick a Testing account chip → Continue → OTP 123456 → Verify.
# Navigate to the screen you want, let animations settle, then:

adb exec-out screencap -p > docs/release/screenshots/NN-name.png

adb shell wm size reset      # ALWAYS — otherwise the emulator stays resized
```

Verify every capture is exactly 1080×2160 before adding it:

```bash
sips -g pixelWidth -g pixelHeight docs/release/screenshots/*.png
```

## 5. Rules for anything added here

- **Never** ship a frame captured mid-animation or mid-transition.
- **Never** include the QA persona banner, a debug banner, or a devtools overlay.
- **Never** retouch, upscale, or composite. If a screen looks wrong, fix the
  screen — that is what happened to the Admin Hub, whose module cards were
  leaving ~46% of the width empty until the capture exposed it.
- Demo data is fine and expected; invented numbers presented as a real school's
  results are not.
