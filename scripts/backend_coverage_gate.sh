#!/usr/bin/env bash
# QW4 · QA-B-074 — backend Deno line-coverage floor.
#
# Runs the full backend test tree under coverage and fails if overall LINE
# coverage regresses below the floor, so newly-added routers/handlers can't
# silently drop coverage. The floor is intentionally just under the measured
# baseline (41.4% as of QW4) and is meant to be RATCHETED UP as DB-backed
# handler tests land — never lowered. Override with BACKEND_COVERAGE_FLOOR.
#
# Usage:  scripts/backend_coverage_gate.sh
set -euo pipefail

FLOOR="${BACKEND_COVERAGE_FLOOR:-40}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COVDIR="$(mktemp -d)"
trap 'rm -rf "$COVDIR"' EXIT

deno test --allow-env --allow-read --coverage="$COVDIR" "$ROOT/supabase/functions/" >/dev/null 2>&1

# Sum LF (lines found) / LH (lines hit) across the lcov report for an overall %.
PCT="$(deno coverage "$COVDIR" --lcov 2>/dev/null \
  | awk -F: '/^LF:/{f+=$2} /^LH:/{h+=$2} END{ if (f==0) print "0"; else printf "%.1f", (h/f)*100 }')"

echo "Backend line coverage: ${PCT}%  (floor ${FLOOR}%)"

if awk -v p="$PCT" -v f="$FLOOR" 'BEGIN{ exit !(p+0 >= f+0) }'; then
  echo "PASS — backend coverage at or above floor."
else
  echo "FAIL — backend line coverage ${PCT}% is below the ${FLOOR}% floor." >&2
  echo "Add tests for the new/changed backend code, or justify + lower the floor deliberately." >&2
  exit 1
fi
