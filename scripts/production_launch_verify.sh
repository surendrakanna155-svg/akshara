#!/usr/bin/env bash
# v7.7 — Production SaaS launch verification (post-deploy smoke)
set -euo pipefail

BASE="${API_BASE_URL:-https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api}"
ORG_ID="a1000000-0000-4000-8000-000000000001"
SCHOOL_A="a2000000-0000-4000-8000-000000000001"
STAFF_ID="a3000000-0000-4000-8000-000000000001"
EXPECTED_PROBES="${EXPECTED_PROBE_COUNT:-213}"
YEAR_ID="${ACADEMIC_YEAR_ID:-}"
INTERNAL_TOKEN="${INTERNAL_HEALTH_TOKEN:-}"

PASS=0
FAIL=0
WARN=0

log() { echo "[launch-verify] $*"; }
pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }
warn() { WARN=$((WARN + 1)); log "WARN: $*"; }

api() {
  local method="$1" path="$2"
  shift 2
  curl -sS -X "$method" "${BASE}${path}" -H "Content-Type: application/json" "${@}"
}

http_code() { curl -sS -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" "${@}"; }

health_headers=()
if [ -n "$INTERNAL_TOKEN" ]; then
  health_headers=(-H "x-internal-health-token: ${INTERNAL_TOKEN}")
fi

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

check_get() {
  local label="$1" token="$2" path="$3" expect="${4:-200}"
  local code
  code=$(http_code -H "$(auth_header "$token")" "${BASE}${path}")
  [ "$code" = "$expect" ] && pass "$label ($code)" || fail "$label ($code)"
}

log "=== Akshara ERP Production Launch Verification (v7.7) ==="
log "API base: ${BASE}"

# ── Core health ──────────────────────────────────────────────────────────────
READY=$(http_code "${BASE}/health/ready")
[ "$READY" = "200" ] && pass "health/ready ($READY)" || fail "health/ready ($READY)"

PUBLIC_TENANT=$(http_code "${BASE}/health/tenant-access")
if [ -n "$INTERNAL_TOKEN" ]; then
  [ "$PUBLIC_TENANT" = "403" ] && pass "tenant-access blocked without token ($PUBLIC_TENANT)" || fail "tenant-access should reject public access ($PUBLIC_TENANT)"
else
  warn "INTERNAL_HEALTH_TOKEN not set — skipping public lockdown check"
fi

HEALTH=$(curl -sS "${BASE}/health/tenant-access" ${health_headers[@]+"${health_headers[@]}"})
PROBE_PASS=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['isolation']['pass'])")
PROBE_COUNT=$(echo "$HEALTH" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']['isolation']['tests']))")
if [ "$PROBE_PASS" = "True" ] && [ "$PROBE_COUNT" -eq "$EXPECTED_PROBES" ]; then
  pass "tenant-access ${PROBE_COUNT}/${EXPECTED_PROBES} probes pass"
else
  fail "tenant-access count=${PROBE_COUNT} expected=${EXPECTED_PROBES} pass=${PROBE_PASS}"
fi

OPS=$(curl -sS "${BASE}/health/operations" ${health_headers[@]+"${health_headers[@]}"})
OPS_STATUS=$(echo "$OPS" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'].get('status',''))" 2>/dev/null || echo "")
[ "$OPS_STATUS" = "ok" ] && pass "health/operations snapshot ok" || fail "health/operations status=${OPS_STATUS}"

# ── Auth + core ERP ─────────────────────────────────────────────────────────
ADMIN_TOKEN=$(login_phone "9876543210")
check_get "admissions dashboard" "$ADMIN_TOKEN" "/admissions/dashboard"
check_get "finance dashboard" "$ADMIN_TOKEN" "/finance/dashboard"
check_get "sis dashboard" "$ADMIN_TOKEN" "/sis/dashboard"

# ── v7.4 AI Copilot ─────────────────────────────────────────────────────────
check_get "copilot assistants (v7.4)" "$ADMIN_TOKEN" "/copilot/assistants"

# ── v7.5 Smart Timetable ────────────────────────────────────────────────────
if [ -n "$YEAR_ID" ]; then
  check_get "timetable summary (v7.5)" "$ADMIN_TOKEN" "/academic/timetables/summary?academicYearId=${YEAR_ID}"
else
  TT_CODE=$(http_code -H "$(auth_header "$ADMIN_TOKEN")" "${BASE}/academic/timetables/summary")
  if [ "$TT_CODE" = "200" ] || [ "$TT_CODE" = "400" ] || [ "$TT_CODE" = "422" ]; then
    pass "timetable route mounted (v7.5) ($TT_CODE)"
  else
    fail "timetable route (v7.5) ($TT_CODE)"
  fi
fi

# ── v7.6 Analytics & Intelligence ───────────────────────────────────────────
check_get "analytics dashboard (v7.6)" "$ADMIN_TOKEN" "/analytics/dashboard"
check_get "analytics health (v7.6)" "$ADMIN_TOKEN" "/analytics/health"

# ── Audit ingestion ─────────────────────────────────────────────────────────
AUDIT_ID="launch-audit-$(date +%s)"
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

log "=== Summary: ${PASS} passed, ${FAIL} failed, ${WARN} warnings ==="
[ "$FAIL" -eq 0 ]
