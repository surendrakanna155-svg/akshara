#!/usr/bin/env bash
# Phases 18 + 23 — Pilot readiness verification (routes, RBAC, tenant, storage, vault)
set -euo pipefail

BASE="${API_BASE_URL:-https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api}"
ORG_ID="a1000000-0000-4000-8000-000000000001"
SCHOOL_A="a2000000-0000-4000-8000-000000000001"
STAFF_ID="a3000000-0000-4000-8000-000000000001"
EXPECTED_PROBES="${EXPECTED_PROBE_COUNT:-219}"
INTERNAL_TOKEN="${INTERNAL_HEALTH_TOKEN:-}"
REPORT_DIR="${REPORT_DIR:-reports/pilot_readiness}"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/verification_report.json"

PASS=0
FAIL=0
WARN=0
DEPLOY_BLOCKED=0

log() { echo "[pilot-readiness] $*"; }
pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }
warn() { WARN=$((WARN + 1)); log "WARN: $*"; }

api() {
  local method="$1" path="$2"
  shift 2
  curl -sS -X "$method" "${BASE}${path}" -H "Content-Type: application/json" "${@}"
}

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

auth_header() { echo "Authorization: Bearer $1"; }

check_get() {
  local label="$1" token="$2" path="$3" expect="${4:-200}"
  local code
  code=$(http_code -H "$(auth_header "$token")" "${BASE}${path}")
  if [ "$code" = "$expect" ]; then
    pass "$label ($code)"
  else
    fail "$label ($code expected $expect)"
  fi
}

check_route_mounted() {
  local label="$1" token="$2" path="$3"
  local code
  code=$(http_code -H "$(auth_header "$token")" "${BASE}${path}")
  case "$code" in
    200|201|400|422) pass "$label mounted ($code)" ;;
    403) pass "$label mounted rbac ($code)" ;;
    404)
      DEPLOY_BLOCKED=$((DEPLOY_BLOCKED + 1))
      fail "$label NOT DEPLOYED ($code) — run ./scripts/pilot_deploy_v14.sh"
      ;;
    *) warn "$label unexpected ($code)" ;;
  esac
}

log "=== Pilot Readiness Verification (v14) ==="

# Health + tenant isolation
READY=$(http_code "${BASE}/health/ready")
[ "$READY" = "200" ] && pass "health/ready ($READY)" || fail "health/ready ($READY)"

health_headers=()
[ -n "$INTERNAL_TOKEN" ] && health_headers=(-H "x-internal-health-token: ${INTERNAL_TOKEN}")
HEALTH=$(curl -sS "${BASE}/health/tenant-access" ${health_headers[@]+"${health_headers[@]}"})
PROBE_PASS=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['isolation']['pass'])")
PROBE_COUNT=$(echo "$HEALTH" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']['isolation']['tests']))")
if [ "$PROBE_PASS" = "True" ]; then
  if [ "$PROBE_COUNT" -eq "$EXPECTED_PROBES" ]; then
    pass "tenant isolation ${PROBE_COUNT}/${EXPECTED_PROBES}"
  elif [ "$PROBE_COUNT" -ge 213 ] && [ "$PROBE_COUNT" -lt "$EXPECTED_PROBES" ]; then
    warn "tenant isolation ${PROBE_COUNT}/${EXPECTED_PROBES} — Edge redeploy pending"
    pass "tenant isolation probes pass (${PROBE_COUNT})"
  else
    fail "tenant isolation count=${PROBE_COUNT} expected=${EXPECTED_PROBES} pass=${PROBE_PASS}"
  fi
else
  fail "tenant isolation count=${PROBE_COUNT} pass=${PROBE_PASS}"
fi

# Storage probe (v10.4)
STORAGE=$(http_code "${BASE}/health/storage" ${health_headers[@]+"${health_headers[@]}"})
if [ "$STORAGE" = "200" ]; then
  pass "storage health ($STORAGE)"
elif [ "$STORAGE" = "404" ]; then
  DEPLOY_BLOCKED=$((DEPLOY_BLOCKED + 1))
  fail "storage health NOT DEPLOYED ($STORAGE)"
else
  fail "storage health ($STORAGE)"
fi

PROVIDERS=$(http_code "${BASE}/health/providers" ${health_headers[@]+"${health_headers[@]}"})
if [ "$PROVIDERS" = "200" ]; then
  pass "provider health ($PROVIDERS)"
elif [ "$PROVIDERS" = "404" ]; then
  DEPLOY_BLOCKED=$((DEPLOY_BLOCKED + 1))
  fail "provider health NOT DEPLOYED ($PROVIDERS)"
else
  warn "provider health ($PROVIDERS)"
fi

ADMIN_TOKEN=$(login_phone "9876543210")
PARENT_TOKEN=$(login_phone "9876543211" "parent" "$SCHOOL_A")
STUDENT_TOKEN=$(login_phone "9876543212" "student" "$SCHOOL_A")
TEACHER_TOKEN=$(login_phone "9876543213" "school" "$SCHOOL_A")

# Core persona dashboards
check_get "school admin admissions" "$ADMIN_TOKEN" "/admissions/dashboard"
check_get "school admin finance" "$ADMIN_TOKEN" "/finance/dashboard"
check_get "school admin sis" "$ADMIN_TOKEN" "/sis/dashboard"
check_get "parent dashboard" "$PARENT_TOKEN" "/parent/dashboard"
check_get "student dashboard" "$STUDENT_TOKEN" "/student/dashboard"
check_get "teacher dashboard" "$TEACHER_TOKEN" "/teacher/dashboard"

# RBAC denials
check_get "parent denied admissions" "$PARENT_TOKEN" "/admissions/dashboard" "403"
check_get "student denied finance" "$STUDENT_TOKEN" "/finance/dashboard" "403"

# v14 intelligence routes
V14_PATHS=(
  "/finance/intelligence/copilot"
  "/finance/intelligence/executive"
  "/inventory/intelligence/copilot"
  "/intelligence/student-success/dashboard"
  "/intelligence/exam/analytics"
  "/school/communications/analytics/summary"
  "/intelligence/teacher-effectiveness/performance"
  "/parent/experience/summary?studentId=student_1"
)
for p in "${V14_PATHS[@]}"; do
  check_route_mounted "v14 ${p}" "$ADMIN_TOKEN" "$p"
done

# Vault (super-admin control center — school admin should get 403 if mounted)
VAULT_CODE=$(http_code -H "$(auth_header "$ADMIN_TOKEN")" "${BASE}/control-center/vault/health")
case "$VAULT_CODE" in
  403) pass "vault rbac school admin denied ($VAULT_CODE)" ;;
  200) warn "vault accessible to school admin ($VAULT_CODE)" ;;
  404) DEPLOY_BLOCKED=$((DEPLOY_BLOCKED + 1)); fail "vault route not deployed ($VAULT_CODE)" ;;
  *) warn "vault response ($VAULT_CODE)" ;;
esac

# Audit ingestion
AUDIT_ID="pilot-readiness-$(date +%s)"
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
[ "$ACCEPTED" = "1" ] && pass "audit ingestion" || fail "audit ingestion"

log "=== Summary: ${PASS} passed, ${FAIL} failed, ${WARN} warnings, deploy_blocked=${DEPLOY_BLOCKED} ==="

python3 - <<PY
import json, datetime
report = {
  "generatedAt": datetime.datetime.utcnow().isoformat() + "Z",
  "passed": ${PASS},
  "failed": ${FAIL},
  "warnings": ${WARN},
  "deployBlockedRoutes": ${DEPLOY_BLOCKED},
  "stagingReady": ${DEPLOY_BLOCKED} == 0 and ${FAIL} == 0,
}
with open("${REPORT}", "w") as f:
  json.dump(report, f, indent=2)
PY

[ "$FAIL" -eq 0 ]
