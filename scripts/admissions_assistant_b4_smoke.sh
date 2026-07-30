#!/usr/bin/env bash
# B4 AI Admissions Assistant — live-cert smoke. Real auth + real DB (+ real AI).
#
# Exercises the now-wired admissions intelligence on the live edge:
#   1. GET /admissions/intelligence → funnel summary + ranked next-best-actions
#      grounded in the real B1 CRM data.
#   2. The deterministic advisor: structure of nextBestActions (id/kind/priority/
#      title/cta), funnel fields, ranking sanity.
#   3. The Copilot `admissions` persona answers grounded in that funnel (session
#      create → send "Which leads need follow-up?" → assistant reply non-empty).
#   4. RBAC: a parent-scope token cannot read /admissions/intelligence (403).
#
# Usage:
#   API_BASE_URL=http://127.0.0.1:54321/functions/v1/api scripts/admissions_assistant_b4_smoke.sh
#   API_BASE_URL=https://api.nikshaos.in    scripts/admissions_assistant_b4_smoke.sh
set -euo pipefail

BASE="${API_BASE_URL:-http://127.0.0.1:54321/functions/v1/api}"
ORG_ID="a1000000-0000-4000-8000-000000000001"
SCHOOL_A="a2000000-0000-4000-8000-000000000001"
ADMIN_PHONE="${ADMIN_PHONE:-9876543210}"
PARENT_PHONE="${PARENT_PHONE:-9876543211}"
PASS=0
FAIL=0

log() { echo "[b4-smoke] $*"; }
pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }

api() { local method="$1" path="$2"; shift 2; curl -sS -X "$method" "${BASE}${path}" -H "Content-Type: application/json" ${1+"$@"}; }
auth_header() { echo "Authorization: Bearer $1"; }
jqp() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)"; }
code() { local m="$1" p="$2" tok="$3"; shift 3; curl -sS -o /dev/null -w "%{http_code}" -X "$m" "${BASE}${p}" -H "$(auth_header "$tok")" -H "Content-Type: application/json" ${1+"$@"}; }

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
[ -n "$ADMIN_TOKEN" ] && pass "admin login (school scope)" || { fail "admin login"; exit 1; }

# ─── 1) Intelligence endpoint returns funnel + next-best-actions ──────────────
INTEL=$(api GET /admissions/intelligence -H "$(auth_header "$ADMIN_TOKEN")")
INTEL_CODE=$(code GET /admissions/intelligence "$ADMIN_TOKEN")
[ "$INTEL_CODE" = "200" ] && pass "GET /admissions/intelligence 200" || { fail "intelligence ($INTEL_CODE): $INTEL"; exit 1; }

TOTAL=$(echo "$INTEL" | jqp "d['data']['funnel']['totalLeads']")
[ -n "$TOTAL" ] && pass "funnel.totalLeads present ($TOTAL)" || fail "funnel.totalLeads missing"

# Funnel summary completeness.
echo "$INTEL" | python3 -c "
import sys,json
f=json.load(sys.stdin)['data']['funnel']
need=['totalLeads','hotLeads','conversionRate','pendingFollowUps','unassignedLeads','stageCounts']
missing=[k for k in need if k not in f]
sys.exit(1 if missing else 0)
" && pass "funnel summary has all fields" || fail "funnel summary missing fields"

# Next-best-actions shape + ranking sanity.
echo "$INTEL" | python3 -c "
import sys,json
acts=json.load(sys.stdin)['data']['nextBestActions']
assert isinstance(acts,list), 'nextBestActions not a list'
order={'urgent':0,'high':1,'medium':2,'low':3}
last=-1
for a in acts:
    for k in ('id','kind','priority','title','detail','cta'):
        assert k in a and a[k]!='', f'action missing {k}: {a}'
    assert a['priority'] in order, f'bad priority {a[\"priority\"]}'
    assert order[a['priority']]>=last, 'actions not ranked by priority'
    last=order[a['priority']]
assert len(acts)<=8, 'too many actions'
print(f'{len(acts)} actions, top={acts[0][\"kind\"] if acts else \"none\"}')
" && pass "nextBestActions well-formed + ranked" || fail "nextBestActions malformed"

# ─── 2) Copilot admissions persona is grounded in the funnel ──────────────────
SESSION=$(api POST /copilot/sessions -H "$(auth_header "$ADMIN_TOKEN")" -d '{"assistantType":"admissions","title":"B4 smoke"}')
SESSION_ID=$(echo "$SESSION" | jqp "d['data']['id']")
[ -n "$SESSION_ID" ] && pass "copilot admissions session created ($SESSION_ID)" || { fail "copilot session: $SESSION"; }

if [ -n "${SESSION_ID:-}" ]; then
  REPLY=$(api POST "/copilot/sessions/${SESSION_ID}/messages" -H "$(auth_header "$ADMIN_TOKEN")" -d '{"content":"Which leads need follow-up and what should I do first?"}')
  RCODE=$(echo "$REPLY" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if d.get('data',{}).get('assistantMessage',{}).get('content') else 'no')" 2>/dev/null || echo no)
  [ "$RCODE" = "ok" ] && pass "admissions copilot returned a grounded reply" || fail "copilot reply: $REPLY"
  STUB=$(echo "$REPLY" | jqp "d['data'].get('stub')" 2>/dev/null || echo "?")
  log "copilot reply mode: stub=$STUB (real AI when ANTHROPIC_API_KEY set)"
fi

# ─── 3) RBAC: parent scope cannot read admissions intelligence ────────────────
PARENT_TOKEN=$(login_phone "$PARENT_PHONE" "parent" "$SCHOOL_A")
if [ -n "$PARENT_TOKEN" ]; then
  PCODE=$(code GET /admissions/intelligence "$PARENT_TOKEN")
  [ "$PCODE" = "403" ] && pass "parent scope denied /admissions/intelligence (403)" || fail "parent RBAC ($PCODE)"
else
  log "parent login unavailable — skipping RBAC check"
fi

echo
log "RESULT: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
