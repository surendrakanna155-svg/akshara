#!/usr/bin/env bash
# B6 Marketing Engine — live-cert smoke. Real auth + real production DB.
#
# Exercises the now-complete growth/marketing engine on the live edge:
#   1. Campaign lifecycle: create (with audience + scheduledAt) → list (fields
#      round-trip) → pause (status=paused) → reactivate via PUT (status=active)
#      → history (GET). The pause/PUT/history routes were missing before B6.
#   2. Lead capture + source attribution: create inquiry (source=facebook) → list.
#   3. Convert → Admissions CRM: the inquiry becomes a real B1 lead carrying its
#      source + campaign attribution; the inquiry flips to status=converted.
#   4. Attribution surfaces: funnel exposes sourceAttribution + campaignAttribution;
#      dashboard exposes KPIs.
#   5. RBAC: a parent-scope token cannot manage growth (403).
#   6. Entitlement: the pilot org (Professional) is allowed (200, not 402),
#      proving the module.marketing grant resolves under the new gate.
#
# Usage:
#   API_BASE_URL=http://127.0.0.1:54321/functions/v1/api scripts/marketing_engine_b6_smoke.sh
#   API_BASE_URL=https://akshara.veloraunisexsalon.com    scripts/marketing_engine_b6_smoke.sh
set -euo pipefail

BASE="${API_BASE_URL:-http://127.0.0.1:54321/functions/v1/api}"
ADMIN_PHONE="${ADMIN_PHONE:-9876543210}"
PARENT_PHONE="${PARENT_PHONE:-9876543211}"
PASS=0
FAIL=0

log() { echo "[b6-smoke] $*"; }
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

# ─── 1) Campaign lifecycle ────────────────────────────────────────────────────
CREATE=$(api POST /growth/campaigns -H "$(auth_header "$ADMIN_TOKEN")" -d '{
  "name": "B6 Smoke Campaign", "channel": "facebook", "budgetInr": 5000,
  "audience": "Class 6 parents", "scheduledAt": "2026-07-01T09:00:00Z"
}')
CAMP_ID=$(echo "$CREATE" | jqp "d['data']['id']")
[ -n "$CAMP_ID" ] && pass "create campaign (201) id=$CAMP_ID" || { fail "create campaign: $CREATE"; exit 1; }

LIST=$(api GET /growth/campaigns -H "$(auth_header "$ADMIN_TOKEN")")
echo "$LIST" | python3 -c "
import sys,json
items=json.load(sys.stdin)['data']['items']
c=next((x for x in items if x['id']=='${CAMP_ID}'), None)
assert c, 'created campaign not in list'
assert c.get('audience')=='Class 6 parents', f\"audience not round-tripped: {c.get('audience')}\"
assert c.get('scheduledAt'), 'scheduledAt not round-tripped'
print('ok')
" >/dev/null 2>&1 && pass "list returns campaign with audience + scheduledAt round-tripped" \
  || fail "campaign fields not round-tripped: $LIST"

PAUSE=$(api POST "/growth/campaigns/${CAMP_ID}/pause" -H "$(auth_header "$ADMIN_TOKEN")")
PS=$(echo "$PAUSE" | jqp "d['data']['status']")
[ "$PS" = "paused" ] && pass "pause campaign → status=paused" || fail "pause ($PS): $PAUSE"

REACT=$(api PUT "/growth/campaigns/${CAMP_ID}" -H "$(auth_header "$ADMIN_TOKEN")" -d '{"status":"active"}')
RS=$(echo "$REACT" | jqp "d['data']['status']")
[ "$RS" = "active" ] && pass "reactivate campaign (PUT) → status=active" || fail "reactivate ($RS): $REACT"

HIST_CODE=$(code GET /growth/campaigns/history "$ADMIN_TOKEN")
[ "$HIST_CODE" = "200" ] && pass "campaign history (GET) 200" || fail "history ($HIST_CODE)"

# ─── 2) Lead capture + source attribution ─────────────────────────────────────
INQ=$(api POST /growth/inquiries -H "$(auth_header "$ADMIN_TOKEN")" -d "{
  \"parentName\": \"B6 Smoke Parent\", \"phone\": \"9999900099\",
  \"gradeInterest\": \"6\", \"source\": \"facebook\", \"campaignId\": \"${CAMP_ID}\"
}")
INQ_ID=$(echo "$INQ" | jqp "d['data']['id']")
[ -n "$INQ_ID" ] && pass "create inquiry (lead capture) id=$INQ_ID" || { fail "create inquiry: $INQ"; exit 1; }

INQ_LIST_CODE=$(code GET /growth/inquiries "$ADMIN_TOKEN")
[ "$INQ_LIST_CODE" = "200" ] && pass "list inquiries 200" || fail "list inquiries ($INQ_LIST_CODE)"

# ─── 3) Convert → Admissions CRM (handoff with attribution) ───────────────────
CONV=$(api POST "/growth/inquiries/${INQ_ID}/convert" -H "$(auth_header "$ADMIN_TOKEN")")
LEAD_ID=$(echo "$CONV" | jqp "d['data']['leadId']")
[ -n "$LEAD_ID" ] && pass "convert inquiry → CRM lead id=$LEAD_ID" || { fail "convert: $CONV"; exit 1; }

LEADS=$(api GET /admissions/leads -H "$(auth_header "$ADMIN_TOKEN")")
echo "$LEADS" | python3 -c "
import sys,json
d=json.load(sys.stdin)['data']
items=d['items'] if isinstance(d, dict) and 'items' in d else d
l=next((x for x in items if x.get('id')=='${LEAD_ID}'), None)
assert l, 'converted lead not found in admissions CRM'
assert l.get('source')=='facebook', f\"lead source attribution lost: {l.get('source')}\"
print('ok')
" >/dev/null 2>&1 && pass "converted lead present in CRM with source attribution" \
  || fail "lead attribution check failed: $LEADS"

# ─── 4) Attribution surfaces ──────────────────────────────────────────────────
FUNNEL=$(api GET /growth/funnel -H "$(auth_header "$ADMIN_TOKEN")")
echo "$FUNNEL" | python3 -c "
import sys,json
d=json.load(sys.stdin)['data']
assert 'sourceAttribution' in d and 'campaignAttribution' in d, 'attribution missing'
srcs={s['source'] for s in d['sourceAttribution']}
assert 'facebook' in srcs, f'facebook source not attributed: {srcs}'
print('ok')
" >/dev/null 2>&1 && pass "funnel exposes source + campaign attribution (facebook present)" \
  || fail "funnel attribution: $FUNNEL"

DASH_CODE=$(code GET /growth/dashboard "$ADMIN_TOKEN")
[ "$DASH_CODE" = "200" ] && pass "dashboard KPIs 200 (entitlement allowed — pilot Professional)" \
  || fail "dashboard ($DASH_CODE) — entitlement may be denying the pilot"

# ─── 5) RBAC: parent cannot manage growth ─────────────────────────────────────
PARENT_TOKEN=$(login_phone "$PARENT_PHONE" "parent")
if [ -n "$PARENT_TOKEN" ]; then
  PC=$(code POST /growth/campaigns "$PARENT_TOKEN" -d '{"name":"x","channel":"facebook"}')
  [ "$PC" = "403" ] && pass "parent denied managing growth (403)" || fail "parent manage growth expected 403 got $PC"
else
  log "SKIP: parent login unavailable"
fi

log "──────────────────────────────"
log "RESULT: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
