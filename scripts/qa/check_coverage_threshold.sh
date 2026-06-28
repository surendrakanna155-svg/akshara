#!/usr/bin/env bash
# QW1 QA-X-038 — Coverage minimum-threshold enforcement.
#
# Parses coverage/lcov.info and fails if total line coverage falls below a floor.
# Previously CI only asserted that lcov.info *existed* — so coverage could decay
# silently and untested code could ship without a failing gate.
#
# The floor is env-overridable so it can be ratcheted UP as coverage improves
# (it must never be lowered without owner sign-off):
#   COVERAGE_MIN     total line-coverage floor, percent (default below)
#   LCOV_FILE        path to the lcov report (default coverage/lcov.info)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

LCOV_FILE="${LCOV_FILE:-coverage/lcov.info}"
# Floor pinned just below the measured baseline (60.24% = 51600/85653 lines,
# 2504/0 tests, 2026-06-28 — see QW1 CI certification). Raise as coverage grows;
# never lower without owner approval.
COVERAGE_MIN="${COVERAGE_MIN:-60}"

if [ ! -f "$LCOV_FILE" ]; then
  echo "::error::coverage gate: $LCOV_FILE not found — run 'flutter test --coverage' first."
  exit 1
fi

read -r covered total pct < <(
  awk -F: '
    /^LF:/ { f += $2 }
    /^LH:/ { h += $2 }
    END {
      if (f == 0) { print "0 0 0.00"; exit }
      printf "%d %d %.2f\n", h, f, (h / f) * 100
    }
  ' "$LCOV_FILE"
)

if [ "$total" -eq 0 ]; then
  echo "::error::coverage gate: no line records (LF) in $LCOV_FILE — empty/invalid report."
  exit 1
fi

echo "[coverage-gate] total line coverage: ${covered}/${total} = ${pct}% (floor: ${COVERAGE_MIN}%)"

# Integer-safe comparison (avoid float arithmetic in bash): compare pct*100 vs floor*100.
pct_scaled="$(awk -v p="$pct" 'BEGIN{printf "%d", p*100}')"
min_scaled="$(awk -v m="$COVERAGE_MIN" 'BEGIN{printf "%d", m*100}')"

if [ "$pct_scaled" -lt "$min_scaled" ]; then
  echo "::error::coverage gate FAILED: ${pct}% < ${COVERAGE_MIN}% floor. Add tests or justify with owner sign-off before lowering the floor."
  exit 1
fi

echo "[coverage-gate] PASS"
