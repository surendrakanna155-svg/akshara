#!/usr/bin/env bash
# Phase 5 / v10.4 staging verification
set -euo pipefail

BASE="${API_BASE_URL:-https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api}"
SCHOOL_A="a2000000-0000-4000-8000-000000000001"
STUDENT_A="a4000000-0000-4000-8000-000000000001"
REPORT_DIR="${REPORT_DIR:-reports/phase5_validation}"
PASS=0
FAIL=0
SKIP=0
DEPLOY_BLOCK=0

mkdir -p "$REPORT_DIR"
LOG="$REPORT_DIR/phase5_staging_verify.log"
: > "$LOG"

log() { echo "[phase5-verify] $*" | tee -a "$LOG"; }
pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }
skip() { SKIP=$((SKIP + 1)); log "SKIP: $*"; }

api() {
  local method="$1" path="$2"
  shift 2
  curl -sS -X "$method" "${BASE}${path}" \
    -H "Content-Type: application/json" \
    "${@}"
}

login_phone() {
  local phone="$1"
  local scope="${2:-}"
  local school_id="${3:-}"
  local resp otp session_id body
  resp=$(api POST /auth/login -d "{\"identifier\":\"${phone}\",\"type\":\"phone\"}")
  otp=$(echo "$resp" | python3 -c "import sys,json,re; m=json.load(sys.stdin)['data']['message']; print(re.search(r'Use code (\\d+)', m).group(1))")
  session_id=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['sessionId'])")
  body="{\"identifier\":\"${phone}\",\"type\":\"phone\",\"otp\":\"${otp}\",\"sessionId\":\"${session_id}\""
  if [ -n "$scope" ]; then
    body="${body},\"scope\":\"${scope}\""
    if [ -n "$school_id" ]; then
      body="${body},\"schoolId\":\"${school_id}\""
    fi
  fi
  body="${body}}"
  api POST /auth/verify-otp -d "$body" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['accessToken'])"
}

auth_header() { echo "Authorization: Bearer $1"; }
http_code() {
  curl -sS -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" "${@}"
}

route_deployed() {
  local path="$1"
  local code
  code=$(http_code "${BASE}${path}")
  # Deployed protected routes return 401 without token; missing routes return 404.
  [ "$code" = "401" ] || [ "$code" = "403" ]
}

log "Phase 5 staging verification starting..."
log "API base: $BASE"

# Preflight — detect stale Edge deployment (Phase 5 routes missing)
PHASE5_PROBE_PATHS=(
  "/parent/experience/hub"
  "/operations/hub"
  "/memories/events"
  "/employees/intelligence/dashboard"
)
for probe in "${PHASE5_PROBE_PATHS[@]}"; do
  code=$(http_code "${BASE}${probe}")
  if [ "$code" = "404" ]; then
    log "DEPLOY REQUIRED: $probe returns 404 (route not on staging Edge bundle)"
    DEPLOY_BLOCK=1
  else
    log "Route probe $probe → HTTP $code (present)"
  fi
done

if [ "$DEPLOY_BLOCK" -eq 1 ]; then
  log "BLOCKED: Run ./scripts/deploy_staging.sh then re-run this script"
  python3 - <<PY > "$REPORT_DIR/summary.json"
import json
print(json.dumps({
  "pass": $PASS,
  "fail": $FAIL,
  "skip": $SKIP,
  "deployBlocked": True,
  "log": "$LOG",
  "action": "Run scripts/deploy_staging.sh with SUPABASE_ACCESS_TOKEN"
}, indent=2))
PY
  exit 2
fi

ADMIN_TOKEN=$(login_phone "9876543210")
PARENT_TOKEN=$(login_phone "9876543211" "parent" "$SCHOOL_A")

check_get() {
  local label="$1" path="$2" token="$3" expect="${4:-200}"
  local code
  code=$(http_code -H "$(auth_header "$token")" "${BASE}${path}")
  if [ "$code" = "$expect" ]; then pass "$label ($code)"; else fail "$label expected $expect got $code"; fi
}

# Parent Experience
check_get "parent experience hub" "/parent/experience/hub?studentId=${STUDENT_A}" "$PARENT_TOKEN"

# Employee Intelligence
check_get "employee intelligence dashboard" "/employees/intelligence/dashboard" "$ADMIN_TOKEN"

# Operations Hub
check_get "operations hub" "/operations/hub" "$ADMIN_TOKEN"

# School Memories
check_get "memories events list" "/memories/events" "$ADMIN_TOKEN"
check_get "memories analytics" "/memories/analytics" "$ADMIN_TOKEN"

# Promotion
check_get "promotions list" "/promotions" "$ADMIN_TOKEN"
check_get "parent experience hub student B" "/parent/experience/hub?studentId=a4000000-0000-4000-8000-000000000002" "$PARENT_TOKEN"

# Memories detail (when events exist)
EVENT_ID=$(curl -sS -H "$(auth_header "$ADMIN_TOKEN")" "${BASE}/memories/events" | python3 -c "import sys,json; items=json.load(sys.stdin).get('data',{}).get('items',[]); print(items[0]['id'] if items else '')" 2>/dev/null || true)
if [ -n "$EVENT_ID" ]; then
  check_get "memories event detail" "/memories/events/${EVENT_ID}" "$ADMIN_TOKEN"
else
  skip "memories event detail (no events in staging)"
fi

# Inventory reports
check_get "distribution reports" "/inventory/distribution/reports" "$ADMIN_TOKEN"

# RBAC denial — parent cannot access operations hub
code=$(http_code -H "$(auth_header "$PARENT_TOKEN")" "${BASE}/operations/hub")
if [ "$code" = "403" ]; then pass "parent denied operations hub (403)"; else fail "parent operations hub expected 403 got $code"; fi

python3 - <<PY > "$REPORT_DIR/summary.json"
import json
print(json.dumps({
  "pass": $PASS,
  "fail": $FAIL,
  "skip": $SKIP,
  "deployBlocked": False,
  "log": "$LOG"
}, indent=2))
PY

log "Results: $PASS passed, $FAIL failed, $SKIP skipped"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
