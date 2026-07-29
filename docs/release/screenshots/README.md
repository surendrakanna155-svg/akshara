# Play Store screenshots — NIKSHA OS

**Status: 1 current and verified. Play requires a minimum of 2, so this set is
NOT submittable yet.** Read §3 before publishing anything from here.

## 1. How these were produced

Every PNG here is a real screen capture of the real app running on a real
Android device. Nothing is mocked, composited, upscaled, or drawn by hand.

| Property | Value |
|---|---|
| Device | Android emulator, `sdk_gphone64_arm64`, **Android 16 (API 36)** |
| Capture size | **1080 × 2160** (`adb shell wm size 1080x2160`) |
| Density | **420** (`adb shell wm density 420`) → 411 dp logical width |
| Build | `flutter build apk --profile --dart-define=ENABLE_DEMO_AUTH=true` |
| Data | The app's built-in demo school |
| Captured | 2026-07-29, from `release/v1.0-playstore` |

**Why 1080×2160 and not the emulator's native 1080×2400.** Play requires each
side to be 320–3840px AND the long side to be **at most twice** the short side.
2400 / 1080 = 2.22, which fails. 2160 / 1080 = 2.00 exactly, which passes.

**Set the density explicitly.** The emulator was found carrying a 480 density
override, and at one point a 1170×2532 size override — ratio 2.16, which would
have failed Play outright. 480 gives a 360 dp logical width; a real phone of
this size is 411 dp, and layouts switch breakpoint between the two. Pin density
**before** size: changing density restarts SystemUI and silently drops the size
override.

**Why a profile build and not a release build.** A release binary *cannot* run
here: `Environment.guardForRelease` refuses to start unless `APP_ENV=production`
AND `ENABLE_API_MODE=true` — i.e. against the live backend, whose credentials are
owner-held. That guard is deliberate (SEC-1/SEC-2) and is not being worked
around. A profile build is the same compiled Dart and the same widget tree; only
the data source differs.

**Why `ENABLE_DEMO_AUTH` and not `QA_AUTOMATION`.** `QA_AUTOMATION=true` enables
the QA persona picker, which paints a QA banner across every screen, and it also
force-enables the floating AI dock (`enableQaLogin` → `floatingBubbleEnabled`).
Neither exists in a shipping build, so a screenshot containing either would
misrepresent the app. Demo auth gives the same screens with no QA chrome.

## 2. What is here

| File | Screen | Notes |
|---|---|---|
| `01-parent-dashboard.png` | Parent home | Signed in as Parent. The hero pills and the three KPI cards — Attendance / Homework / Fees — now agree and all carry real values. |

## 3. What is NOT here, and why — read before publishing

### The three previous screenshots are quarantined in `stale/`. Do not upload them.

Captured 2026-07-28 and now superseded:

- **They predate the brand rename.** They render the demo school as *"Akshara
  Demo School"*; the product now reads **"NIKSHA Demo School"** everywhere. A
  listing whose screenshots show a retired brand is both a policy problem and a
  trust problem.
- **`02-teacher-dashboard.png` shows a state this build cannot reach.** It reads
  *"Checked in · 9:02 AM · Geo+Face verified"*. Face check-in needs
  `assets/models/mobilefacenet.tflite`, which is an owner build item and is not
  bundled — so the shipping app **blocks** that check-in (correctly, failing
  closed). Publishing it would advertise a capability a buyer cannot use.
- **The dashboards changed underneath them.** The fabricated-data remediation
  removed invented KPI rows, and re-based the school-health ring that had been
  reporting a confident **100** for a school at 68% collection / 31.6% margin.
- **`03-mark-attendance.png`'s "known issue" is fixed.** Its AI-button overlap
  was real, but that capture predates its own fix by 46 minutes (`b2041ad7`).
  This file previously recorded it as an open owner decision — "either the AI
  affordance yields on screens with a bottom action bar, or those screens
  reserve space for it". That decision was made and implemented: **they reserve
  space.** Verified not to reproduce at phone width on current HEAD.

### The remaining shots are blocked on a quiet device, not on the product.

Capture was attempted repeatedly on 2026-07-29 and could not be finished: the
emulator is in concurrent use, and `com.akshara.erp` was **uninstalled by another
process three times** mid-session (`deletePackageX` / `pkg removed` in logcat),
with SystemUI ANRing under build load. That is an environment problem, not a
product one — the product was verified on-device during the windows that held.

Recommended order when a quiet device is available (per `../PLAY_STORE_LISTING_V1.md` §5):

1. ✅ Parent home *(captured)*
2. ⬜ **Student 360** — the differentiator; the whole reason a principal buys
3. ⬜ Principal Admin Hub
4. ⬜ Teacher dashboard — **re-shoot without the Geo+Face-verified state**
5. ⬜ Teacher attendance — exception-first marking
6. ⬜ Marks entry — the speed story
7. ⬜ Parent — fees and receipt
8. ⬜ Dark mode — any of the above

## 4. Repeatable capture procedure

Drive it **step by step, checking each screen before the next tap.** A blind
`adb shell input tap` chain does not survive here: the notification permission
dialog appears on a fresh install but not after `install -r`, so every later tap
lands one screen out. Every capture kept below was looked at before being kept.

```bash
flutter build apk --profile --dart-define=ENABLE_DEMO_AUTH=true
adb install -r build/app/outputs/flutter-apk/app-profile.apk

adb shell wm density 420      # FIRST — this restarts SystemUI
sleep 8
adb shell wm size 1080x2160   # THEN this, or it gets dropped
sleep 8
adb shell wm density; adb shell wm size   # verify BOTH before launching

adb shell monkey -p com.akshara.erp -c android.intent.category.LAUNCHER 1
# first frame takes ~25s; screenshot and LOOK before every tap
adb exec-out screencap -p > shot.png
```

Demo sign-in: pick a persona chip → Continue → OTP `123456` → Verify & continue.

Afterwards: `adb shell wm size reset && adb shell wm density reset`.

Confirm each capture really is 1080×2160 before keeping it — the overrides drop
silently:

```bash
python3 -c "import struct,sys;d=open(sys.argv[1],'rb').read();\
w,h=struct.unpack('>II',d[16:24]);print(w,h,round(h/w,3))" shot.png
```

## 5. Rules for anything added here

- **Never** ship a frame captured mid-animation or mid-transition.
- **Never** include the QA persona banner, a debug banner, or a devtools overlay.
- **Never** retouch, upscale, or composite. If a screen looks wrong, fix the
  screen — that is what happened here: capturing the parent dashboard is what
  exposed the truncated `₹4,20…` fee figure and the AI button sitting on top of
  "Pay Now", both since fixed.
- Demo data is fine and expected. Invented numbers presented as a real school's
  results are not — and neither is a screenshot of a capability the shipping
  build cannot perform.
