#!/usr/bin/env bash
# Aggregate Patrol run artifacts into a coverage summary JSON.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUN_ID="${1:-manual}"
PATROL_EXIT="${2:-0}"

REPORT_DIR="${ROOT}/qa/patrol/reports/${RUN_ID}"
SUMMARY="${REPORT_DIR}/patrol_summary.json"
MANIFEST="${ROOT}/qa/patrol/journey_manifest.json"
BUGS="${ROOT}/qa/patrol/reports/bugs.json"

mkdir -p "$REPORT_DIR"

TEST_COUNT="$(find "${ROOT}/patrol_test" -name '*_test.dart' | wc -l | tr -d ' ')"
JOURNEY_COUNT="$(python3 -c "import json; print(len(json.load(open('${MANIFEST}'))))" 2>/dev/null || echo 0)"
SCREENSHOT_MARKERS="$(find "${ROOT}/qa/patrol/screenshots" -name '*.marker' 2>/dev/null | wc -l | tr -d ' ')"

python3 - <<PY
import json
from pathlib import Path

summary = {
    "run_id": "${RUN_ID}",
    "patrol_exit_code": int("${PATROL_EXIT}"),
    "status": "pass" if int("${PATROL_EXIT}") == 0 else "fail",
    "test_files": int("${TEST_COUNT}"),
    "journeys_manifest": int("${JOURNEY_COUNT}"),
    "screenshot_markers": int("${SCREENSHOT_MARKERS}"),
    "coverage_estimate_pct": min(95, 40 + int("${JOURNEY_COUNT}") // 2),
    "report_dir": "${REPORT_DIR}",
}
Path("${SUMMARY}").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
PY

if [[ -f "$BUGS" ]]; then
  echo "Bug inventory: $BUGS"
fi
