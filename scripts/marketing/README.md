# Marketing screenshot pipeline — NIKSHA OS

Produces real, reproducible, versioned captures of the real app for `nikshaos.in`.

Design rationale and the shot list live in
[`docs/website/NIKSHAOS_SITE_REDESIGN_PROPOSAL.md`](../../docs/website/NIKSHAOS_SITE_REDESIGN_PROPOSAL.md) §6.

```bash
scripts/marketing/capture_shots.sh phone     # logical 390x844   → mobile layout
scripts/marketing/capture_shots.sh tablet    # logical 834x1194  → tablet layout
scripts/marketing/capture_shots.sh desktop   # logical 1440x1024 → desktop layout
```

Output: `build/marketing-capture/<tier>/*.png` + `manifest.json`. Git-ignored.

## What it is

| Piece | Role |
|---|---|
| `integration_test/marketing_capture_test.dart` | Declarative shot list. Boots the app, signs in per demo persona, asserts an anchor rendered, captures. |
| `test_driver/marketing_capture_driver.dart` | Host side. Receives bytes over the driver channel and writes the PNG. |
| `scripts/marketing/capture_shots.sh` | Sets the layout tier, runs the drive, writes the provenance manifest, always restores the device. |

## Why not Patrol

Two blocking facts, both verified:

1. **The `patrol` package has no screenshot API** (checked against `patrol-4.6.1`).
2. **`capturePatrolScreenshot` is a no-op on device.** `patrol_test/helpers/patrol_helpers.dart:47`
   returns early on Android/iOS and otherwise writes a `.marker` file with a timestamp. So
   `patrol_test/screenshots/screenshot_regression_test.dart` — which reads as a seven-persona
   screenshot suite — **has never produced an image.** It records intent for regression tooling,
   which is a fine thing to be and is not a capture pipeline.

Capture needs `IntegrationTestWidgetsFlutterBinding`, the only binding that can ship bytes to the
host; `PatrolBinding` and it cannot coexist. No captured path involves a native dialog, so nothing
is lost. `PatrolTester({tester, config})` is constructible standalone if a shot ever needs it.

## Adding a shot

Add a `MarketingShot` to `kPersonaShots`:

```dart
MarketingShot(
  name: 'parent-fees',          // stable — the website references this filename
  account: 'Parent',            // a label from the app's own kTestingLoginAccounts
  anchor: 'Fees',               // text that proves the screen actually rendered
),
```

`anchor` must be text that appears **only once the intended screen has rendered its content** —
not a nav label that is also present while loading, or the shutter fires on a half-built screen.

When a shot times out, the harness prints every visible `Text` in the tree. That output is how the
principal's real landing screen (**Admin Hub**, not a dashboard) was found. Fix the shot; never
loosen the assertion.

## Rules (non-negotiable)

**Allowed:** crop, scale, convert format, add a device bezel around an unmodified capture,
blur/replace personal data.

**Forbidden:** retouching UI · compositing across screens · inventing or editing any number, name
or state · upscaling · a mid-animation frame · any QA/debug chrome.

Two rules that are easy to miss:

- **Never the live pilot.** `release/v1.0-playstore` HEAD (`8050eda2`) records confirmed
  unauthenticated exposure on the deployed pilot. Capture runs against local demo auth with mock
  repositories only.
- **Depicted-state rule.** A capture may only be published if the state it depicts is reachable in
  a build a customer could run. Demo *data* is fine; a demo-only *capability* shown as working is
  not. Concretely: `02-teacher-dashboard.png` shows "Geo+Face verified", but
  `assets/models/mobilefacenet.tflite` is not in the repo and `MobileFaceNetEmbedder` fails loud
  with `FACE_MODEL_MISSING`. Every pixel is real and the screenshot still makes a false claim.

## The run can fail; that is the point

The script exits non-zero and writes **no manifest** when a run produces no images, and fails when
the captured pixels imply a different layout tier than the one requested. Both were added after
being observed:

- `flutter drive` can exit 0 having produced nothing — a failed install, a driver handshake that
  never completed, or `ext.flutter.driver: Service has disappeared` (a flaky VM-service drop; just
  re-run). Without the guard the script wrote a well-formed manifest with `"shots": []` and exited
  0: a failed run reporting success.
- A run once reported `physicalSize: 1170x2532` while every PNG was `1080x2160`. Since
  `logical = pixels / (density/160)` selects the layout tier, a silent size mismatch means the
  captured layout may not be the tier the filename claims. The manifest now records **measured**
  size and keeps the requested one alongside.

## Gotchas already paid for

- **The session is in the Android Keystore, not SharedPreferences.** `prefs.clear()` does not sign
  you out. Without clearing `AuthSessionStorage` + `TokenStorage`, every shot after the first
  captures the previous persona's workspace while still looking like a valid screenshot.
- **`convertFlutterSurfaceToImage()` is once per _test_.** A process-wide flag makes the first
  capture pass and all later ones fail with *"Call convertFlutterSurfaceToImage() before taking a
  screenshot"*.
- **`pumpAndSettle` never returns.** Continuous animations (docked AI affordance, progress rings,
  shimmer) mean settling never completes. Use the bounded `settle()` helper.
- **Taps must scroll into view first.** A widget that sits mid-screen on a phone can fall below the
  fold on a tablet — present in the tree, not hit-testable, tap lands on nothing, run stalls on a
  screen that looks correct. Use `tapVisible`.
- **Tier = `wm size` AND `wm density`.** Logical width decides the layout
  (`logical = physical / (density / 160)`, `lib/theme/breakpoints.dart`). Changing size alone
  captures the wrong layout at the right resolution — the failure least likely to be noticed.

## Promotion

Nothing publishes from `build/`. Promotion into `deploy/nikshaos/src/product-shots/` is a reviewed
step gated on the data-hygiene review and the depicted-state rule. `build_site.mjs` then refuses to
render any shot without a manifest entry — the same fail-loud discipline it already applies to
brand assets.
