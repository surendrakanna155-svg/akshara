#!/usr/bin/env bash
# PRA S0/T2-H — mock/demo-scaffolding import recurrence guard (ratchet).
#
# Root cause (PRA audit): there is no architectural boundary preventing a live
# Flutter provider/screen from importing demo scaffolding (mock repositories or
# in-memory demo stores), which is how several P0s shipped — mock data reaching
# production surfaces with no flag guard.
#
# This guard is a RATCHET, not a big-bang gate, because existing violations are
# still being burned down across Stages S2–S4:
#
#   • HARD GATE (zero baseline): no production Dart file may import the parent
#     communication inbox FALLBACK. Its only production consumer was removed in
#     S0/T2-E (PRA-N-10, "fail closed"). Baseline is zero, so any hit is a NEW
#     regression and fails CI.
#
#   • BURNDOWN METER (non-failing): reports how many lib/features files still
#     import the broader demo-scaffolding set. These are known, tracked PRA
#     violations being removed in Stages S2–S4. When the count reaches zero this
#     meter should be promoted to a hard gate (see PRA_FIX_STRATEGY §12.1 T2-H).
#
# Exemptions: lib/core/repositories/mock/** (the mocks themselves) and test/**.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

FAIL=0

# ── Hard gate: parent_communication_inbox_fallback (PRA-N-10, zero baseline) ──
FALLBACK_HITS=$(grep -rln --include='*.dart' "parent_communication_inbox_fallback" lib \
  | grep -v "lib/core/repositories/mock/" \
  | grep -v "lib/core/communication/parent_communication_inbox_fallback.dart" || true)
if [ -n "$FALLBACK_HITS" ]; then
  echo "[mock-guard] FAIL — production code must not import the comms inbox fallback"
  echo "            (PRA-N-10, fail-closed). Offending files:"
  echo "$FALLBACK_HITS" | sed 's/^/              /'
  FAIL=1
fi

# ── Burndown meter: broader demo scaffolding in lib/features (non-failing) ──
SCAFFOLD=$(grep -rln --include='*.dart' \
  -e "repositories/mock/" \
  -e "exams/exam_administration_store.dart" \
  -e "teaching/teacher_assignment_registry.dart" \
  -e "timetable/mock_daily_timetable_store.dart" \
  lib/features 2>/dev/null | wc -l | tr -d ' ')
echo "[mock-guard] burndown: ${SCAFFOLD} lib/features files still import demo scaffolding"
echo "            (tracked PRA S2–S4; target 0, then promote the meter to a hard gate)."

if [ "$FAIL" -ne 0 ]; then
  echo "[mock-guard] recurrence guard FAILED."
  exit 1
fi
echo "[mock-guard] OK — no new mock-import regressions."
