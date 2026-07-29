#!/usr/bin/env bash
#
# Marketing screenshot capture for nikshaos.in.
#
#   scripts/marketing/capture_shots.sh phone
#   scripts/marketing/capture_shots.sh tablet
#   scripts/marketing/capture_shots.sh desktop
#
# Captures the REAL app with REAL fonts and the app's built-in demo school
# (1,248 students / 86 staff) and writes PNGs plus a provenance manifest.
#
# ---------------------------------------------------------------------------
# Why the device gets resized
# ---------------------------------------------------------------------------
# Which layout the app renders is decided by LOGICAL width, per
# lib/theme/breakpoints.dart:
#
#     mobile  <= 767      tablet  768..1199      desktop >= 1200
#
# and logical width = physical / (density / 160). So the tier is chosen by
# `wm size` + `wm density` together — changing one without the other silently
# captures the wrong layout at the right resolution, which is the failure mode
# most likely to go unnoticed. Density is set to 320 (2x) for tablet/desktop so
# captures stay crisp enough to publish.
#
# The device is ALWAYS restored on exit, including on failure — a resized
# emulator left behind breaks every later manual test.
#
# ---------------------------------------------------------------------------
# What this never does
# ---------------------------------------------------------------------------
# Never touches the live pilot. Capture runs entirely against local demo auth
# with mock repositories (enableApiMode: false).
#
# This holds regardless of the pilot's security posture. Commit 8050eda2 recorded
# a confirmed unauthenticated exposure and 521b7e57 resolved it (9/9 live checks),
# but the rule is not conditional on that: a marketing screenshot must never be
# able to contain real school data, so it never reads from a real deployment.
set -euo pipefail

TIER="${1:-phone}"
DEVICE="${DEVICE:-emulator-5554}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Per-tier output. A shared directory would mean each tier wiped the previous
# one, so a full phone+tablet+desktop set could never exist at the same time —
# and the loss would be silent, because every run still ends "captured N shots".
OUT="$REPO/build/marketing-capture/$TIER"

# tier -> physical size, density, resulting logical size, expected app tier
case "$TIER" in
  # 1080 wide, not 1170: this emulator clamps the framebuffer to its native
  # 1080px width, so a 1170 request silently captured 1080x2160 -> logical 360,
  # the TIGHTEST phone layout rather than the intended 390. Density 443 derives
  # the target logical width from the width the device will actually give us
  # (1080 * 160 / 443 = 390).
  phone)   WM_SIZE=1080x2160; WM_DENSITY=443; LOGICAL="390x780"   ;;
  tablet)  WM_SIZE=1668x2388; WM_DENSITY=320; LOGICAL="834x1194"  ;;
  desktop) WM_SIZE=2880x2048; WM_DENSITY=320; LOGICAL="1440x1024" ;;
  *) echo "usage: $0 {phone|tablet|desktop}" >&2; exit 2 ;;
esac

if ! adb -s "$DEVICE" get-state >/dev/null 2>&1; then
  echo "error: device '$DEVICE' not available. Start an emulator, or set DEVICE=." >&2
  exit 1
fi

restore() {
  echo "→ restoring device display"
  adb -s "$DEVICE" shell wm size reset    >/dev/null 2>&1 || true
  adb -s "$DEVICE" shell wm density reset >/dev/null 2>&1 || true
}
trap restore EXIT

echo "→ tier=$TIER  physical=$WM_SIZE  density=$WM_DENSITY  logical=$LOGICAL"
adb -s "$DEVICE" shell wm size "$WM_SIZE"
adb -s "$DEVICE" shell wm density "$WM_DENSITY"

rm -rf "$OUT"
mkdir -p "$OUT"

# Debug, deliberately — and it is the ONLY mode available here.
#
# `docs/release/screenshots/README.md` uses --profile, and a plain
# `flutter build apk --profile` does succeed. But `flutter drive` also compiles
# the integration_test target, which imports `flutter_test`; that cannot be
# AOT-compiled, so `--profile` fails at :app:compileFlutterBuildProfile. Verified
# both ways rather than assumed.
#
# This costs nothing visually: `lib/app/app.dart:102` sets
# debugShowCheckedModeBanner: false, and debug renders the same widget tree with
# the same fonts and the same layout. Only JIT-vs-AOT and assertions differ, and
# neither is visible in a still capture.
#
# A release binary cannot run here at all in any case —
# Environment.guardForRelease refuses to start outside APP_ENV=production with
# ENABLE_API_MODE=true (SEC-1/SEC-2). That guard is deliberate and is not being
# worked around.
echo "→ running capture"
export MARKETING_OUT_DIR="$OUT"
( cd "$REPO" && flutter drive \
    --driver=test_driver/marketing_capture_driver.dart \
    --target=integration_test/marketing_capture_test.dart \
    -d "$DEVICE" \
    --dart-define=ENABLE_DEMO_AUTH=true )

# ---------------------------------------------------------------------------
# Fail loudly on an empty capture.
#
# `flutter drive` can exit 0 having produced nothing (a failed install, a driver
# handshake that never completed, every shot erroring). Without this guard the
# script sailed on to write a well-formed manifest with "shots": [] and exit 0 —
# a run that FAILED while reporting success, which is the single most dangerous
# outcome for an evidence pipeline. Observed, not hypothetical.
# ---------------------------------------------------------------------------
SHOT_COUNT="$(ls -1 "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')"
if [ "$SHOT_COUNT" -eq 0 ]; then
  echo >&2
  echo "error: capture produced 0 shots — NOT writing a manifest." >&2
  echo "       The drive exited without producing images. Check the output above" >&2
  echo "       for a build failure, a failed install, or per-shot timeouts." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Provenance manifest
#
# Mirrors this repository's evidence culture: an asset with no recorded origin
# cannot be published. build_site.mjs already fails loudly on a missing brand
# asset; the website build should fail the same way on an unmanifested capture.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Record MEASURED reality, and verify it matches intent.
#
# The manifest previously recorded the size we *asked* for. A run was observed
# where the device reported the override correctly yet every PNG came out
# 1080x2160 instead of the requested 1170x2532 — so the manifest asserted a
# resolution its own images contradicted.
#
# This matters beyond tidiness: logical width (= pixels / (density/160)) is what
# selects the layout tier, so a silent size mismatch means the captured layout
# may not be the tier the filename and manifest claim. Measure the PNGs, and
# fail if the measured logical width lands outside the intended tier.
# ---------------------------------------------------------------------------
FIRST_PNG="$(ls -1 "$OUT"/*.png 2>/dev/null | head -1)"
MEASURED="$(sips -g pixelWidth -g pixelHeight "$FIRST_PNG" 2>/dev/null \
            | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')"
MEASURED_W="${MEASURED%%x*}"
MEASURED_LOGICAL_W=$(( MEASURED_W * 160 / WM_DENSITY ))

case "$TIER" in
  phone)   TIER_OK=$([ "$MEASURED_LOGICAL_W" -le 767 ] && echo yes || echo no) ;;
  tablet)  TIER_OK=$([ "$MEASURED_LOGICAL_W" -ge 768 ] && [ "$MEASURED_LOGICAL_W" -le 1199 ] && echo yes || echo no) ;;
  desktop) TIER_OK=$([ "$MEASURED_LOGICAL_W" -ge 1200 ] && echo yes || echo no) ;;
esac

if [ "$TIER_OK" != "yes" ]; then
  echo >&2
  echo "error: captured images are ${MEASURED} → logical width ${MEASURED_LOGICAL_W}px," >&2
  echo "       which is NOT the '$TIER' tier this run claims to have captured." >&2
  echo "       The device did not render at the requested size. Not writing a manifest." >&2
  exit 1
fi

if [ "$MEASURED" != "$WM_SIZE" ]; then
  echo "warning: requested $WM_SIZE but captured $MEASURED (still within the" >&2
  echo "         '$TIER' tier, so the layout is correct). Recording measured." >&2
fi

COMMIT="$(cd "$REPO" && git rev-parse HEAD)"
BRANCH="$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)"
# Clean == no porcelain output at all. The earlier `head -c1 | wc -c` form was
# INVERTED: a dirty tree yields 1 and a clean tree 0, so it recorded every dirty
# capture as clean. A provenance manifest that lies about its own inputs is worse
# than no manifest.
if [ -z "$(cd "$REPO" && git status --porcelain)" ]; then CLEAN=true; else CLEAN=false; fi
ANDROID="$(adb -s "$DEVICE" shell getprop ro.build.version.release | tr -d '\r')"
MODEL="$(adb -s "$DEVICE" shell getprop ro.product.model | tr -d '\r')"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
  echo "{"
  echo "  \"tier\": \"$TIER\","
  echo "  \"physicalSize\": \"$MEASURED\","
  echo "  \"logicalWidth\": $MEASURED_LOGICAL_W,"
  echo "  \"density\": $WM_DENSITY,"
  echo "  \"requestedPhysicalSize\": \"$WM_SIZE\","
  echo "  \"requestedLogicalSize\": \"$LOGICAL\","
  echo "  \"device\": \"$MODEL · Android $ANDROID\","
  echo "  \"build\": \"debug · ENABLE_DEMO_AUTH=true · mock repositories\","
  echo "  \"data\": \"app built-in demo school (1,248 students / 86 staff)\","
  echo "  \"commit\": \"$COMMIT\","
  echo "  \"branch\": \"$BRANCH\","
  echo "  \"workingTreeClean\": $CLEAN,"
  echo "  \"capturedUtc\": \"$STAMP\","
  echo "  \"shots\": ["
  first=1
  for f in "$OUT"/*.png; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .png)"
    px="$(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null \
          | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"x"h}')"
    [ $first -eq 0 ] && echo ","
    first=0
    printf '    {"name": "%s", "file": "%s.png", "pixels": "%s"}' "$name" "$name" "$px"
  done
  echo
  echo "  ]"
  echo "}"
} > "$OUT/manifest.json"

echo
echo "→ captured $SHOT_COUNT shots to $OUT"
echo "→ manifest: $OUT/manifest.json"
echo
echo "NEXT: review every capture against §6.6 data hygiene before promoting it"
echo "      into deploy/nikshaos/src/product-shots/. Nothing is published from"
echo "      build/ — promotion is a deliberate, reviewed step."
