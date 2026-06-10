#!/usr/bin/env bash
# SIS 5A0–5A4 staging verification
set -euo pipefail

BASE="${API_BASE_URL:-https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api}"
ORG_ID="a1000000-0000-4000-8000-000000000001"
SCHOOL_A="a2000000-0000-4000-8000-000000000001"
SCHOOL_B="a2000000-0000-4000-8000-000000000002"
STUDENT_A="a4000000-0000-4000-8000-000000000001"
STUDENT_B="a4000000-0000-4000-8000-000000000002"
ENROLLMENT_A="bc100000-0000-4000-8000-000000000001"
ENROLLMENT_B="bc100000-0000-4000-8000-000000000002"
ADM_ENROLLMENT_A="bd000000-0000-4000-8000-000000000001"
PASS=0
FAIL=0

log() { echo "[sis-verify] $*"; }
pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }

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

# ─── Probes ───────────────────────────────────────────────────────────────────
log "Checking tenant-access probes..."
HEALTH=$(curl -sS "${BASE}/health/tenant-access")
PROBE_COUNT=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['data']['isolation']['tests']))")
PROBE_PASS=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['isolation']['pass'])")
PROBE_FAILS=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print([t['name'] for t in d['data']['isolation']['tests'] if not t['pass']])")

if [ "$PROBE_PASS" = "True" ] && [ "$PROBE_COUNT" = "85" ]; then
  pass "tenant-access 85/85 probes"
else
  fail "tenant-access probes count=$PROBE_COUNT pass=$PROBE_PASS fails=$PROBE_FAILS"
fi

# ─── Auth tokens ──────────────────────────────────────────────────────────────
ADMIN_TOKEN=$(login_phone "9876543210")
PARENT_TOKEN=$(login_phone "9876543211" "parent" "$SCHOOL_A")
STUDENT_TOKEN=$(login_phone "9876543212" "student" "$SCHOOL_A")
ORG_TOKEN=$(api POST /auth/context/switch -H "$(auth_header "$ADMIN_TOKEN")" -d "{\"scope\":\"organization\",\"organizationId\":\"${ORG_ID}\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['accessToken'])")

# ─── SIS routes (school admin) ────────────────────────────────────────────────
check_route() {
  local label="$1" method="$2" path="$3"
  local code
  if [ "$method" = "GET" ]; then
    code=$(http_code -H "$(auth_header "$ADMIN_TOKEN")" "${BASE}${path}")
  else
    code=$(http_code -X "$method" -H "$(auth_header "$ADMIN_TOKEN")" "${BASE}${path}")
  fi
  if [ "$code" = "200" ] || [ "$code" = "201" ]; then
    pass "$label ($code)"
  else
    fail "$label ($code)"
  fi
}

check_route "GET dashboard" GET "/sis/dashboard"
check_route "GET students" GET "/sis/students"
check_route "GET student detail" GET "/sis/students/${STUDENT_A}"
check_route "GET enrollments" GET "/sis/enrollments"

# Create manual student
CREATE_RESP=$(api POST /sis/students -H "$(auth_header "$ADMIN_TOKEN")" -d '{
  "displayName": "SIS Verify Student",
  "admissionNumber": "ADM-VERIFY-'"$(date +%s)"'",
  "gender": "male",
  "dateOfBirth": "2014-01-01"
}')
NEW_STUDENT=$(echo "$CREATE_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}).get('student',{}); print(d.get('id',''))" 2>/dev/null || true)
if [ -n "$NEW_STUDENT" ]; then
  pass "POST /sis/students creates student"
else
  fail "POST /sis/students: $CREATE_RESP"
fi

if [ -n "$NEW_STUDENT" ]; then
  code=$(http_code -X PUT -H "$(auth_header "$ADMIN_TOKEN")" -d '{"displayName":"SIS Verify Updated"}' "${BASE}/sis/students/${NEW_STUDENT}")
  [ "$code" = "200" ] && pass "PUT /sis/students/:id ($code)" || fail "PUT /sis/students/:id ($code)"

  code=$(http_code -X PATCH -H "$(auth_header "$ADMIN_TOKEN")" -d '{"status":"inactive"}' "${BASE}/sis/students/${NEW_STUDENT}/status")
  [ "$code" = "200" ] && pass "PATCH /sis/students/:id/status ($code)" || fail "PATCH status ($code)"
fi

# Enrollment create
if [ -n "$NEW_STUDENT" ]; then
  ENR_RESP=$(api POST /sis/enrollments -H "$(auth_header "$ADMIN_TOKEN")" -d "{
    \"studentId\": \"${NEW_STUDENT}\",
    \"academicYear\": \"2026-27\",
    \"className\": \"7\",
    \"sectionName\": \"Z\",
    \"rollNumber\": \"99\",
    \"isCurrent\": true
  }")
  NEW_ENR=$(echo "$ENR_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('enrollmentId',''))" 2>/dev/null || true)
  if [ -n "$NEW_ENR" ]; then
    pass "POST /sis/enrollments"
    code=$(http_code -X PUT -H "$(auth_header "$ADMIN_TOKEN")" -d '{"rollNumber":"100"}' "${BASE}/sis/enrollments/${NEW_ENR}")
    [ "$code" = "200" ] && pass "PUT /sis/enrollments/:id ($code)" || fail "PUT enrollments ($code)"
  else
    fail "POST /sis/enrollments: $ENR_RESP"
  fi
fi

# Duplicate admission number → 409
DUP_RESP=$(http_code -X POST -H "$(auth_header "$ADMIN_TOKEN")" -d '{
  "displayName": "Dup Test",
  "admissionNumber": "ADM-2026-PROBE001"
}' "${BASE}/sis/students")
[ "$DUP_RESP" = "409" ] && pass "duplicate admission number → 409" || fail "duplicate admission ($DUP_RESP)"

# Duplicate academic year → 409
DUP_YR=$(http_code -X POST -H "$(auth_header "$ADMIN_TOKEN")" -d "{
  \"studentId\": \"${STUDENT_A}\",
  \"academicYear\": \"2026-27\",
  \"className\": \"5\"
}" "${BASE}/sis/enrollments")
[ "$DUP_YR" = "409" ] && pass "duplicate academic year → 409" || fail "duplicate year ($DUP_YR)"

# Invalid status transition → 422 (terminal alumni → active)
BAD_STATUS=$(http_code -X PATCH -H "$(auth_header "$ADMIN_TOKEN")" -d '{"status":"active"}' "${BASE}/sis/students/${STUDENT_A}/status")
if [ "$BAD_STATUS" = "422" ]; then
  pass "invalid status transition → 422"
else
  # Ensure probe student is terminal before re-testing
  http_code -X PATCH -H "$(auth_header "$ADMIN_TOKEN")" -d '{"status":"graduated"}' "${BASE}/sis/students/${STUDENT_A}/status" >/dev/null
  BAD_STATUS=$(http_code -X PATCH -H "$(auth_header "$ADMIN_TOKEN")" -d '{"status":"active"}' "${BASE}/sis/students/${STUDENT_A}/status")
  [ "$BAD_STATUS" = "422" ] && pass "invalid status transition → 422" || fail "bad status ($BAD_STATUS)"
fi

# Cross-school update → 404
CROSS_STU=$(http_code -X PUT -H "$(auth_header "$ADMIN_TOKEN")" -d '{"displayName":"Hack"}' "${BASE}/sis/students/${STUDENT_B}")
[ "$CROSS_STU" = "404" ] && pass "cross-school student update → 404" || fail "cross-school student ($CROSS_STU)"

CROSS_ENR=$(http_code -X PUT -H "$(auth_header "$ADMIN_TOKEN")" -d '{"className":"X"}' "${BASE}/sis/enrollments/${ENROLLMENT_B}")
[ "$CROSS_ENR" = "404" ] && pass "cross-school enrollment update → 404" || fail "cross-school enrollment ($CROSS_ENR)"

# Admissions conversion
STUDENTS_BEFORE=$(export SUPABASE_ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:?Set SUPABASE_ACCESS_TOKEN}" && cd "$(dirname "$0")/.." && supabase db query --linked "SELECT count(*)::text AS c FROM students WHERE school_id = '${SCHOOL_A}'" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['rows'][0]['c'])" 2>/dev/null || echo "0")

CONV1=$(api POST /sis/admissions-conversion -H "$(auth_header "$ADMIN_TOKEN")" -d "{
  \"enrollmentId\": \"${ADM_ENROLLMENT_A}\",
  \"academicYear\": \"2027-28\",
  \"className\": \"6\",
  \"sectionName\": \"A\",
  \"rollNumber\": \"15\"
}")
CONV_ID=$(echo "$CONV1" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}); print(d.get('studentId',''))" 2>/dev/null || true)
CONV_CODE1=$(echo "$CONV1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('meta',{}).get('status',200))" 2>/dev/null || echo "0")
IDEMP=$(echo "$CONV1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('idempotent',False))" 2>/dev/null || echo "False")

if [ -n "$CONV_ID" ]; then
  pass "POST /sis/admissions-conversion (studentId=$CONV_ID idempotent=$IDEMP)"
else
  fail "conversion: $CONV1"
fi

CONV2=$(api POST /sis/admissions-conversion -H "$(auth_header "$ADMIN_TOKEN")" -d "{
  \"enrollmentId\": \"${ADM_ENROLLMENT_A}\",
  \"academicYear\": \"2027-28\",
  \"className\": \"6\",
  \"sectionName\": \"A\",
  \"rollNumber\": \"15\"
}")
IDEMP2=$(echo "$CONV2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('idempotent',False))" 2>/dev/null || echo "False")
[ "$IDEMP2" = "True" ] && pass "conversion idempotency → idempotent=true" || fail "idempotency ($IDEMP2)"

STUDENTS_AFTER=$(export SUPABASE_ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:?Set SUPABASE_ACCESS_TOKEN}" && cd "$(dirname "$0")/.." && supabase db query --linked "SELECT count(*)::text AS c FROM students WHERE school_id = '${SCHOOL_A}'" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['rows'][0]['c'])" 2>/dev/null || echo "0")
[ "$STUDENTS_BEFORE" = "$STUDENTS_AFTER" ] && pass "conversion: students count unchanged ($STUDENTS_BEFORE)" || fail "students count changed $STUDENTS_BEFORE → $STUDENTS_AFTER"

CONV_ROW=$(export SUPABASE_ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:?Set SUPABASE_ACCESS_TOKEN}" && cd "$(dirname "$0")/.." && supabase db query --linked "SELECT conversion_status, (converted_at IS NOT NULL) AS has_at, (converted_by IS NOT NULL) AS has_by FROM admissions_enrollments WHERE id = '${ADM_ENROLLMENT_A}'" 2>/dev/null | python3 -c "import sys,json; r=json.load(sys.stdin)['rows'][0]; print(r['conversion_status'], r['has_at'], r['has_by'])" 2>/dev/null || echo "missing")
echo "$CONV_ROW" | grep -q "converted True True" && pass "conversion_status=converted with audit columns" || fail "conversion audit: $CONV_ROW"

# Dashboard payload shape
DASH_RESP=$(api GET /sis/dashboard -H "$(auth_header "$ADMIN_TOKEN")")
echo "$DASH_RESP" | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
required = ['totalStudents', 'kpis', 'classDistribution', 'genderDistribution', 'recentEnrollments', 'aiInsight']
missing = [k for k in required if k not in d]
if missing:
    raise SystemExit('missing keys: ' + ', '.join(missing))
print('ok')
" >/dev/null 2>&1 && pass "GET /sis/dashboard payload shape" || fail "dashboard payload: $DASH_RESP"

# Scope denials 403 for all SIS routes
SIS_ROUTES=(
  "GET /sis/dashboard"
  "GET /sis/students"
  "GET /sis/students/${STUDENT_A}"
  "POST /sis/students"
  "PUT /sis/students/${STUDENT_A}"
  "PATCH /sis/students/${STUDENT_A}/status"
  "GET /sis/enrollments"
  "POST /sis/enrollments"
  "PUT /sis/enrollments/${ENROLLMENT_A}"
  "POST /sis/admissions-conversion"
)

check_scope_denial() {
  local scope_label="$1" token="$2" method="$3" path="$4"
  local code
  if [ "$method" = "GET" ]; then
    code=$(http_code -H "$(auth_header "$token")" "${BASE}${path}")
  else
    code=$(http_code -X "$method" -H "$(auth_header "$token")" -d '{}' "${BASE}${path}")
  fi
  if [ "$code" = "403" ]; then
    pass "${scope_label} denied ${method} ${path} → 403"
  else
    fail "${scope_label} ${method} ${path} → $code (expected 403)"
  fi
}

for route in "${SIS_ROUTES[@]}"; do
  method="${route%% *}"
  path="${route#* }"
  check_scope_denial "org" "$ORG_TOKEN" "$method" "$path"
  check_scope_denial "parent" "$PARENT_TOKEN" "$method" "$path"
  check_scope_denial "student" "$STUDENT_TOKEN" "$method" "$path"
done

log "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
