#!/usr/bin/env bash
# v6.4 Sprint 6 — Pilot staging validation (read + audit + tenant isolation)
set -euo pipefail

BASE="${API_BASE_URL:-https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api}"
ORG_ID="a1000000-0000-4000-8000-000000000001"
SCHOOL_A="a2000000-0000-4000-8000-000000000001"
STAFF_ID="a3000000-0000-4000-8000-000000000001"
EXPECTED_PROBES="${EXPECTED_PROBE_COUNT:-213}"
INTERNAL_TOKEN="${INTERNAL_HEALTH_TOKEN:-}"
PASS=0
FAIL=0

log() { echo "[pilot-verify] $*"; }
pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }

api() {
  local method="$1" path="$2"
  shift 2
  curl -sS -X "$method" "${BASE}${path}" -H "Content-Type: application/json" "${@}"
}

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

auth_header() { echo "Authorization: Bearer $1"; }
http_code() { curl -sS -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" "${@}"; }

log "=== Pilot Staging Validation ==="

# Health
READY=$(http_code "${BASE}/health/ready")
[ "$READY" = "200" ] && pass "health/ready ($READY)" || fail "health/ready ($READY)"

# Tenant isolation probes (213 target — v7.6)
health_headers=()
if [ -n "$INTERNAL_TOKEN" ]; then
  health_headers=(-H "x-internal-health-token: ${INTERNAL_TOKEN}")
fi
HEALTH=$(curl -sS "${BASE}/health/tenant-access" ${health_headers[@]+"${health_headers[@]}"})
PROBE_PASS=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['isolation']['pass'])")
PROBE_COUNT=$(echo "$HEALTH" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']['isolation']['tests']))")
if [ "$PROBE_PASS" = "True" ] && [ "$PROBE_COUNT" -eq "$EXPECTED_PROBES" ]; then
  pass "tenant-access ${PROBE_COUNT}/${EXPECTED_PROBES} probes pass"
else
  fail "tenant-access count=${PROBE_COUNT} expected=${EXPECTED_PROBES} pass=${PROBE_PASS}"
fi

ADMIN_TOKEN=$(login_phone "9876543210")
PARENT_TOKEN=$(login_phone "9876543211" "parent" "$SCHOOL_A")
STUDENT_TOKEN=$(login_phone "9876543212" "student" "$SCHOOL_A")

check_get() {
  local label="$1" token="$2" path="$3" expect="${4:-200}"
  local code
  code=$(http_code -H "$(auth_header "$token")" "${BASE}${path}")
  [ "$code" = "$expect" ] && pass "$label ($code)" || fail "$label ($code)"
}

# Core ERP read surfaces
check_get "admissions dashboard" "$ADMIN_TOKEN" "/admissions/dashboard"
check_get "finance dashboard" "$ADMIN_TOKEN" "/finance/dashboard"
check_get "sis dashboard" "$ADMIN_TOKEN" "/sis/dashboard"
check_get "transport dashboard" "$ADMIN_TOKEN" "/transport/dashboard"
check_get "management dashboard" "$ADMIN_TOKEN" "/management/dashboard"

# Mobile read surfaces
check_get "parent dashboard" "$PARENT_TOKEN" "/parent/dashboard"
check_get "student dashboard" "$STUDENT_TOKEN" "/student/dashboard"
check_get "teacher dashboard" "$ADMIN_TOKEN" "/teacher/dashboard"

# RBAC: parent denied admissions
check_get "parent denied admissions" "$PARENT_TOKEN" "/admissions/dashboard" "403"

# Audit ingestion
AUDIT_ID="pilot-audit-$(date +%s)"
AUDIT_RESP=$(api POST /audit/events/batch -H "$(auth_header "$ADMIN_TOKEN")" -d "{
  \"events\": [{
    \"id\": \"${AUDIT_ID}\",
    \"type\": \"login\",
    \"timestamp\": \"2026-06-10T10:00:00Z\",
    \"tenantId\": \"${ORG_ID}\",
    \"schoolId\": \"${SCHOOL_A}\",
    \"userId\": \"${STAFF_ID}\",
    \"category\": \"auth\"
  }]
}")
ACCEPTED=$(echo "$AUDIT_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('acceptedCount',0))" 2>/dev/null || echo 0)
[ "$ACCEPTED" = "1" ] && pass "audit batch upload accepted" || fail "audit batch: $AUDIT_RESP"

# Idempotent replay
REPLAY=$(echo "$AUDIT_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('acceptedCount',0))" 2>/dev/null || echo 0)
REPLAY2=$(api POST /audit/events/batch -H "$(auth_header "$ADMIN_TOKEN")" -d "{
  \"events\": [{
    \"id\": \"${AUDIT_ID}\",
    \"type\": \"login\",
    \"timestamp\": \"2026-06-10T10:00:00Z\",
    \"tenantId\": \"${ORG_ID}\",
    \"userId\": \"${STAFF_ID}\"
  }]
}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('acceptedCount',0))" 2>/dev/null || echo 0)
[ "$REPLAY2" = "1" ] && pass "audit idempotent replay" || fail "audit replay accepted=$REPLAY2"

log "=== Summary: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ]
