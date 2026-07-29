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
# Never touches the live pilot. `release/v1.0-playstore` HEAD (8050eda2) records
# confirmed unauthenticated exposure there; marketing capture runs entirely
# against local demo auth with mock repositories (enableApiMode: false).
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
  phone)   WM_SIZE=1170x2532; WM_DENSITY=480; LOGICAL="390x844"   ;;
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

# --profile matches the Play Store capture procedure: same compiled Dart and the
# same widget tree as release, but a release binary cannot run here at all —
# Environment.guardForRelease refuses to start outside APP_ENV=production with
# ENABLE_API_MODE=true (SEC-1/SEC-2). That guard is deliberate and is not being
# worked around.
echo "→ running capture"
export MARKETING_OUT_DIR="$OUT"
( cd "$REPO" && flutter drive \
    --driver=test_driver/marketing_capture_driver.dart \
    --target=integration_test/marketing_capture_test.dart \
    -d "$DEVICE" \
    --profile \
    --dart-define=ENABLE_DEMO_AUTH=true )

# ---------------------------------------------------------------------------
# Provenance manifest
#
# Mirrors this repository's evidence culture: an asset with no recorded origin
# cannot be published. build_site.mjs already fails loudly on a missing brand
# asset; the website build should fail the same way on an unmanifested capture.
# ---------------------------------------------------------------------------
COMMIT="$(cd "$REPO" && git rev-parse HEAD)"
BRANCH="$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)"
DIRTY="$(cd "$REPO" && git status --porcelain | head -c1 | wc -c | tr -d ' ')"
ANDROID="$(adb -s "$DEVICE" shell getprop ro.build.version.release | tr -d '\r')"
MODEL="$(adb -s "$DEVICE" shell getprop ro.product.model | tr -d '\r')"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
  echo "{"
  echo "  \"tier\": \"$TIER\","
  echo "  \"logicalSize\": \"$LOGICAL\","
  echo "  \"physicalSize\": \"$WM_SIZE\","
  echo "  \"density\": $WM_DENSITY,"
  echo "  \"device\": \"$MODEL · Android $ANDROID\","
  echo "  \"build\": \"profile · ENABLE_DEMO_AUTH=true · mock repositories\","
  echo "  \"data\": \"app built-in demo school (1,248 students / 86 staff)\","
  echo "  \"commit\": \"$COMMIT\","
  echo "  \"branch\": \"$BRANCH\","
  echo "  \"workingTreeClean\": $([ "$DIRTY" -eq 1 ] && echo true || echo false),"
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
echo "→ captured $(ls -1 "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ') shots to $OUT"
echo "→ manifest: $OUT/manifest.json"
echo
echo "NEXT: review every capture against §6.5 data hygiene before promoting it"
echo "      into deploy/nikshaos/src/product-shots/. Nothing is published from"
echo "      build/ — promotion is a deliberate, reviewed step."
