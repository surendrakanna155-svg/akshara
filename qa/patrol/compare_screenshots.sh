#!/usr/bin/env bash
# Compare Patrol screenshot markers against baseline directory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASELINE="${ROOT}/qa/patrol/screenshots/regression/baseline"
CURRENT="${ROOT}/qa/patrol/screenshots/regression/current"

mkdir -p "$BASELINE" "$CURRENT"

echo "Baseline: $BASELINE"
echo "Current:  $CURRENT"
echo ""
echo "Marker files (baseline):"
find "$BASELINE" -name '*.marker' 2>/dev/null | sort || true
echo ""
echo "Marker files (current):"
find "$CURRENT" -name '*.marker' 2>/dev/null | sort || true
echo ""
echo "Copy current run markers: cp qa/patrol/screenshots/regression/baseline/*.marker qa/patrol/screenshots/regression/current/"
