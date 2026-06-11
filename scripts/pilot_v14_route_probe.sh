#!/usr/bin/env bash
# Probe v14.0 intelligence routes on staging
set -euo pipefail
BASE="${API_BASE_URL:-https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api}"

api() { curl -sS -X "$1" "${BASE}$2" -H "Content-Type: application/json" "${@:3}"; }
http_code() { curl -sS -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" "${@}"; }

resp=$(api POST /auth/login -d '{"identifier":"9876543210","type":"phone"}')
otp=$(echo "$resp" | python3 -c "import sys,json,re; m=json.load(sys.stdin)['data']['message']; print(re.search(r'Use code (\\d+)', m).group(1))")
sid=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['sessionId'])")
TOKEN=$(api POST /auth/verify-otp -d "{\"identifier\":\"9876543210\",\"type\":\"phone\",\"otp\":\"${otp}\",\"sessionId\":\"${sid}\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['accessToken'])")

PATHS=(
  "/finance/intelligence/copilot"
  "/finance/intelligence/executive"
  "/inventory/intelligence/copilot"
  "/intelligence/student-success/dashboard"
  "/intelligence/exam/analytics"
  "/school/communications/analytics/summary"
  "/intelligence/teacher-effectiveness/performance"
  "/control-center/vault/health"
  "/parent/experience/summary?studentId=student_1"
)

for p in "${PATHS[@]}"; do
  code=$(http_code -H "Authorization: Bearer ${TOKEN}" "${BASE}${p}")
  echo "${code} ${p}"
done
