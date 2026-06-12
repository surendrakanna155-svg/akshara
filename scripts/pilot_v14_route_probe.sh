#!/usr/bin/env bash
# Probe v14.0 intelligence routes on staging
set -euo pipefail
BASE="${API_BASE_URL:-https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api}"
SCHOOL_A="a2000000-0000-4000-8000-000000000001"

api() { curl -sS -X "$1" "${BASE}$2" -H "Content-Type: application/json" "${@:3}"; }
http_code() { curl -sS -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" "${@}"; }

login_phone() {
  local phone="$1" scope="${2:-}" school_id="${3:-}"
  local resp otp session_id body
  resp=$(api POST /auth/login -d "{\"identifier\":\"${phone}\",\"type\":\"phone\"}")
  otp=$(echo "$resp" | python3 -c "import sys,json,re; m=json.load(sys.stdin)['data']['message']; print(re.search(r'Use code (\\d+)', m).group(1))")
  session_id=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['sessionId'])")
  body="{\"identifier\":\"${phone}\",\"type\":\"phone\",\"otp\":\"${otp}\",\"sessionId\":\"${session_id}\""
  if [ -n "$scope" ]; then
    body="${body},\"scope\":\"${scope}\""
    [ -n "$school_id" ] && body="${body},\"schoolId\":\"${school_id}\""
  fi
  api POST /auth/verify-otp -d "${body}}" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['accessToken'])"
}

ADMIN_TOKEN=$(login_phone "9876543210" "school" "$SCHOOL_A")
PARENT_TOKEN=$(login_phone "9876543211" "parent" "$SCHOOL_A")

PATHS=(
  "/finance/intelligence/copilot"
  "/finance/intelligence/executive"
  "/inventory/intelligence/copilot"
  "/intelligence/student-success/dashboard"
  "/intelligence/exam/analytics"
  "/school/communications/analytics/summary"
  "/intelligence/teacher-effectiveness/performance"
  "/control-center/vault/health"
)

for p in "${PATHS[@]}"; do
  code=$(http_code -H "Authorization: Bearer ${ADMIN_TOKEN}" "${BASE}${p}")
  echo "${code} ${p}"
done

PROBE_STUDENT_ID=$(PARENT_TOKEN="$PARENT_TOKEN" ADMIN_TOKEN="$ADMIN_TOKEN" python3 <<'PY'
import os, sys
sys.path.insert(0, "scripts")
from demo_school_lib import resolve_probe_student_id, parent_experience_summary_path
sid = resolve_probe_student_id(
    parent_token=os.environ.get("PARENT_TOKEN") or None,
    admin_token=os.environ.get("ADMIN_TOKEN") or None,
)
if sid:
    print(parent_experience_summary_path(sid))
PY
)
if [ -z "$PROBE_STUDENT_ID" ]; then
  echo "SKIP /parent/experience/summary — probe student not found"
else
  code=$(http_code -H "Authorization: Bearer ${PARENT_TOKEN}" "${BASE}${PROBE_STUDENT_ID}")
  echo "${code} ${PROBE_STUDENT_ID}"
fi
