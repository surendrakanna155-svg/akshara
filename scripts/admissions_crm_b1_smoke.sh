#!/usr/bin/env bash
# B1 Admissions CRM completion — live-cert smoke for the lead-management loop:
# assignment, stage transitions, follow-ups, notes, WhatsApp/call logging and
# the persisted activity timeline + follow-up history. Real auth + real DB.
#
# Usage:
#   API_BASE_URL=http://127.0.0.1:54321/functions/v1/api scripts/admissions_crm_b1_smoke.sh   # local
#   API_BASE_URL=https://api.nikshaos.in    scripts/admissions_crm_b1_smoke.sh   # live VPS (root)
set -euo pipefail

BASE="${API_BASE_URL:-http://127.0.0.1:54321/functions/v1/api}"
ORG_ID="a1000000-0000-4000-8000-000000000001"
SCHOOL_A="a2000000-0000-4000-8000-000000000001"
LEAD_SCHOOL_B="b5000000-0000-4000-8000-000000000002"
ADMIN_PHONE="${ADMIN_PHONE:-9876543210}"
PARENT_PHONE="${PARENT_PHONE:-9876543211}"
PASS=0
FAIL=0

log() { echo "[b1-smoke] $*"; }
pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }

api() { local method="$1" path="$2"; shift 2; curl -sS -X "$method" "${BASE}${path}" -H "Content-Type: application/json" "${@}"; }
auth_header() { echo "Authorization: Bearer $1"; }
jqp() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)"; }

login_phone() {
  local phone="$1" scope="${2:-}" school_id="${3:-}" resp otp session_id body
  resp=$(api POST /auth/login -d "{\"identifier\":\"${phone}\",\"type\":\"phone\"}")
  otp=$(echo "$resp" | python3 -c "import sys,json,re; d=json.load(sys.stdin)['data']; print(d.get('otp') or re.search(r'(\\d{4,8})', d.get('message','')).group(1))")
  session_id=$(echo "$resp" | jqp "d['data']['sessionId']")
  body="{\"identifier\":\"${phone}\",\"type\":\"phone\",\"otp\":\"${otp}\",\"sessionId\":\"${session_id}\""
  [ -n "$scope" ] && body="${body},\"scope\":\"${scope}\"" && [ -n "$school_id" ] && body="${body},\"schoolId\":\"${school_id}\""
  body="${body}}"
  api POST /auth/verify-otp -d "$body" | jqp "d['data']['accessToken']"
}

log "Base: ${BASE}"
ADMIN_TOKEN=$(login_phone "$ADMIN_PHONE")
[ -n "$ADMIN_TOKEN" ] && pass "admin login" || { fail "admin login"; exit 1; }

# ─── Create a fresh lead ─────────────────────────────────────────────────────
LEAD_RESP=$(api POST /admissions/leads -H "$(auth_header "$ADMIN_TOKEN")" -d '{
  "parent_name": "CRM Smoke Parent", "student_name": "CRM Smoke Student",
  "class_label": "6", "phone": "9999900042", "source": "walk_in", "counselor": "Initial Counselor"
}')
LEAD_ID=$(echo "$LEAD_RESP" | jqp "d.get('data',{}).get('id','')")
[ -n "$LEAD_ID" ] && pass "create lead ($LEAD_ID)" || { fail "create lead: $LEAD_RESP"; exit 1; }

# ─── Assign counselor (PATCH /assign) ────────────────────────────────────────
ASSIGN=$(api PATCH "/admissions/leads/${LEAD_ID}/assign" -H "$(auth_header "$ADMIN_TOKEN")" -d '{"counselor":"Meera N."}')
echo "$ASSIGN" | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('data',{}).get('counselor')=='Meera N.' else 1)" \
  && pass "assign counselor" || fail "assign counselor: $ASSIGN"

# ─── Change stage (PATCH /stage) ─────────────────────────────────────────────
STAGE=$(api PATCH "/admissions/leads/${LEAD_ID}/stage" -H "$(auth_header "$ADMIN_TOKEN")" -d '{"stage":"school_visit"}')
echo "$STAGE" | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('data',{}).get('stage')=='school_visit' else 1)" \
  && pass "change stage" || fail "change stage: $STAGE"

# ─── Add follow-up (POST /followups) ─────────────────────────────────────────
FU=$(api POST "/admissions/leads/${LEAD_ID}/followups" -H "$(auth_header "$ADMIN_TOKEN")" -d '{
  "task":"Discuss fee plan","scheduled_label":"Tomorrow 10:00 AM","outcome":"Scheduled","counselor":"Meera N."}')
echo "$FU" | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('data',{}).get('task')=='Discuss fee plan' else 1)" \
  && pass "add follow-up" || fail "add follow-up: $FU"

# ─── Add note / WhatsApp / call (POST /notes) ────────────────────────────────
NOTE=$(api POST "/admissions/leads/${LEAD_ID}/notes" -H "$(auth_header "$ADMIN_TOKEN")" -d '{"content":"Parent prefers morning batch"}')
echo "$NOTE" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}); exit(0 if d.get('type')=='note' and d.get('description') else 1)" \
  && pass "add note" || fail "add note: $NOTE"
WA=$(api POST "/admissions/leads/${LEAD_ID}/notes" -H "$(auth_header "$ADMIN_TOKEN")" -d '{"content":"Shared brochure on WhatsApp","activity_type":"whatsapp"}')
echo "$WA" | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('data',{}).get('type')=='whatsapp' else 1)" \
  && pass "log WhatsApp activity" || fail "log WhatsApp: $WA"
CALL=$(api POST "/admissions/leads/${LEAD_ID}/notes" -H "$(auth_header "$ADMIN_TOKEN")" -d '{"content":"Called, will visit Sat","activity_type":"call"}')
echo "$CALL" | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('data',{}).get('type')=='call' else 1)" \
  && pass "log call activity" || fail "log call: $CALL"

# ─── Read back the persisted detail (timeline + follow-up history) ───────────
DETAIL=$(curl -sS -H "$(auth_header "$ADMIN_TOKEN")" "${BASE}/admissions/leads/${LEAD_ID}")
echo "$DETAIL" | python3 -c "
import sys,json
d=json.load(sys.stdin).get('data',{})
acts=d.get('activities',[]); fus=d.get('followUps',[])
types={a.get('type') for a in acts}
ok = len(acts)>=5 and len(fus)>=1 and {'assignment','stageChange','note','whatsapp','call'}.issubset(types)
print('activities=%d followUps=%d types=%s' % (len(acts), len(fus), sorted(types)))
sys.exit(0 if ok else 1)
" && pass "lead detail returns persisted timeline + follow-up history" || fail "lead detail timeline: $DETAIL"

# ─── RBAC: non-admin scopes denied on assignment ─────────────────────────────
PARENT_TOKEN=$(login_phone "$PARENT_PHONE" "parent" "$SCHOOL_A")
PCODE=$(curl -sS -o /dev/null -w "%{http_code}" -X PATCH -H "$(auth_header "$PARENT_TOKEN")" -H "Content-Type: application/json" \
  "${BASE}/admissions/leads/${LEAD_ID}/assign" -d '{"counselor":"x"}')
[ "$PCODE" = "403" ] && pass "parent scope denied assign (403)" || fail "parent assign RBAC ($PCODE)"

# ─── Cross-school isolation ──────────────────────────────────────────────────
XCODE=$(curl -sS -o /dev/null -w "%{http_code}" -H "$(auth_header "$ADMIN_TOKEN")" "${BASE}/admissions/leads/${LEAD_SCHOOL_B}")
[ "$XCODE" = "404" ] && pass "cross-school lead read denied (404)" || fail "cross-school isolation ($XCODE)"

log "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
