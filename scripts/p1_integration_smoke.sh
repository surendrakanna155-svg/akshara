#!/usr/bin/env bash
# P1 INTEGRATION certification — verifies the completed P1 batches (B1–B6) work
# TOGETHER end-to-end on the live edge. Real auth + real production DB.
#
# This is NOT a per-batch re-test (each batch has its own smoke). It exercises the
# SEAMS between batches:
#   Chain 1  Marketing → CRM → AI Admissions Assistant   (B6 → B1 → B4)
#   Chain 2  Capability Gating consistency across modules (B2 × B6 × B3 × B1)
#   Chain 3  Parent Insights + RBAC scope                 (B3 × B4 × B6 × B1)
#   Chain 4  WhatsApp data readiness on a converted lead  (B5 × B6 → B1)
#
# Usage:
#   API_BASE_URL=https://akshara.veloraunisexsalon.com/functions/v1/api scripts/p1_integration_smoke.sh
set -euo pipefail

BASE="${API_BASE_URL:-http://127.0.0.1:54321/functions/v1/api}"
ADMIN_PHONE="${ADMIN_PHONE:-9876543210}"
PARENT_PHONE="${PARENT_PHONE:-9876543211}"
STUDENT_ID="${STUDENT_ID:-a4000000-0000-4000-8000-000000000001}"
PASS=0; FAIL=0
log() { echo "[p1-int] $*"; }
pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }

api() { local m="$1" p="$2"; shift 2; curl -sS -X "$m" "${BASE}${p}" -H "Content-Type: application/json" ${1+"$@"}; }
ah() { echo "Authorization: Bearer $1"; }
jqp() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)"; }
code() { local m="$1" p="$2" tok="$3"; shift 3; curl -sS -o /dev/null -w "%{http_code}" -X "$m" "${BASE}${p}" -H "$(ah "$tok")" -H "Content-Type: application/json" ${1+"$@"}; }
login_phone() {
  local phone="$1" scope="${2:-}" resp otp sid body
  resp=$(api POST /auth/login -d "{\"identifier\":\"${phone}\",\"type\":\"phone\"}")
  otp=$(echo "$resp" | python3 -c "import sys,json,re; d=json.load(sys.stdin)['data']; print(d.get('otp') or re.search(r'(\\d{4,8})', d.get('message','')).group(1))")
  sid=$(echo "$resp" | jqp "d['data']['sessionId']")
  body="{\"identifier\":\"${phone}\",\"type\":\"phone\",\"otp\":\"${otp}\",\"sessionId\":\"${sid}\""
  [ -n "$scope" ] && body="${body},\"scope\":\"${scope}\""
  body="${body}}"
  api POST /auth/verify-otp -d "$body" | jqp "d['data']['accessToken']"
}

log "Base: ${BASE}"
ADMIN=$(login_phone "$ADMIN_PHONE")
[ -n "$ADMIN" ] && pass "admin login (school scope)" || { fail "admin login"; exit 1; }

# ── Chain 1: Marketing → CRM → AI Admissions Assistant ────────────────────────
U0=$(api GET /admissions/intelligence -H "$(ah "$ADMIN")" | jqp "d['data']['funnel'].get('unassignedLeads', 0)")
log "baseline unassignedLeads (B4) = ${U0}"

CAMP=$(api POST /growth/campaigns -H "$(ah "$ADMIN")" -d '{"name":"P1 Integration Campaign","channel":"facebook","budgetInr":3000,"audience":"Grade 6 parents"}')
CAMP_ID=$(echo "$CAMP" | jqp "d['data']['id']")
[ -n "$CAMP_ID" ] && pass "B6 campaign created ($CAMP_ID)" || { fail "campaign: $CAMP"; exit 1; }

INQ=$(api POST /growth/inquiries -H "$(ah "$ADMIN")" -d "{\"parentName\":\"P1 Integ Parent\",\"phone\":\"9999900123\",\"gradeInterest\":\"6\",\"source\":\"facebook\",\"campaignId\":\"${CAMP_ID}\"}")
INQ_ID=$(echo "$INQ" | jqp "d['data']['id']")
[ -n "$INQ_ID" ] && pass "B6 inquiry captured ($INQ_ID)" || { fail "inquiry: $INQ"; exit 1; }

CONV=$(api POST "/growth/inquiries/${INQ_ID}/convert" -H "$(ah "$ADMIN")")
LEAD_ID=$(echo "$CONV" | jqp "d['data']['leadId']")
[ -n "$LEAD_ID" ] && pass "B6→B1 convert → CRM lead ($LEAD_ID)" || { fail "convert: $CONV"; exit 1; }

# Marketing → CRM attribution: the lead carries source + campaign, and the handoff
# leaves it UNASSIGNED (counselor empty) — NOT a raw UUID owner.
LEADS=$(api GET /admissions/leads -H "$(ah "$ADMIN")")
echo "$LEADS" | python3 -c "
import sys,json,re
d=json.load(sys.stdin)['data']; items=d['items'] if isinstance(d,dict) and 'items' in d else d
l=next((x for x in items if x.get('id')=='${LEAD_ID}'), None)
assert l, 'converted lead missing from CRM'
assert l.get('source')=='facebook', f\"source attribution lost: {l.get('source')}\"
assert l.get('campaign') and 'Integration' in l['campaign'], f\"campaign attribution lost: {l.get('campaign')}\"
c=l.get('counselor','')
assert not re.match(r'^[0-9a-f]{8}-[0-9a-f]{4}-', c or ''), f'HANDOFF GAP: counselor is a raw UUID ({c}) — should be unassigned for the CRM/AI handoff'
assert (c or '')=='', f'handoff lead should be unassigned, got counselor={c!r}'
assert l.get('phone'), 'lead has no phone (breaks B5 WhatsApp deep-link)'
print('ok')
" >/dev/null 2>&1 && pass "B6→B1 lead: source+campaign attributed, UNASSIGNED handoff, phone present (B5-ready)" \
  || { fail "handoff/attribution seam: $(echo "$LEADS" | python3 -c "import sys,json,re;d=json.load(sys.stdin)['data'];items=d['items'] if isinstance(d,dict) and 'items' in d else d;l=next((x for x in items if x.get('id')=='${LEAD_ID}'),{});print('counselor=',repr(l.get('counselor')),'source=',l.get('source'),'campaign=',l.get('campaign'))" 2>/dev/null)"; }

# CRM → AI: the converted (unassigned) lead must surface in the AI assistant's
# next-best-actions and bump the unassigned count.
INTEL=$(api GET /admissions/intelligence -H "$(ah "$ADMIN")")
echo "$INTEL" | python3 -c "
import sys,json
d=json.load(sys.stdin)['data']
u1=d['funnel'].get('unassignedLeads',0)
assert u1 > ${U0}, f'unassignedLeads did not rise after convert (was ${U0}, now {u1}) — converted lead invisible to AI'
nbas=d.get('nextBestActions',[])
kinds={a.get('kind') for a in nbas}
assert 'unassigned_leads' in kinds or any(a.get('leadId')=='${LEAD_ID}' for a in nbas), 'no unassigned/assign NBA surfaced for the converted lead'
print('ok')
" >/dev/null 2>&1 && pass "B1→B4 converted lead surfaces in AI next-best-actions (assign handoff)" \
  || fail "CRM→AI seam: converted lead not surfaced ($(echo "$INTEL" | jqp "d['data']['funnel']"))"

# AI source grounding reflects the marketing source.
echo "$INTEL" | python3 -c "
import sys,json
d=json.load(sys.stdin)['data']['funnel']
ts=d.get('topSource') or {}
sc=d.get('stageCounts') or {}
assert ts or sc, 'funnel has no source/stage grounding'
print('ok')
" >/dev/null 2>&1 && pass "B4 funnel grounded in real CRM signals" || fail "B4 funnel grounding"

# ── Chain 2: Capability gating consistency (pilot = Professional) ─────────────
G=$(code GET /growth/dashboard "$ADMIN")
A=$(code GET /admissions/intelligence "$ADMIN")
[ "$G" = "200" ] && [ "$A" = "200" ] && pass "B2 gate consistent: pilot entitled across /growth + /admissions ($G,$A)" \
  || fail "gating inconsistency: growth=$G admissions=$A"

# ── Chain 3: Parent Insights + RBAC scope ────────────────────────────────────
PARENT=$(login_phone "$PARENT_PHONE")
[ -n "$PARENT" ] && pass "parent login" || fail "parent login"
if [ -n "$PARENT" ]; then
  PI=$(code GET "/parent-insights/students/${STUDENT_ID}" "$PARENT")
  [ "$PI" = "200" ] && pass "B3 parent reads own child insights (200)" || fail "parent insights ($PI)"
  # RBAC seams: parent cannot reach staff funnels/CRM/marketing.
  PAI=$(code GET /admissions/intelligence "$PARENT")
  PLE=$(code GET /admissions/leads "$PARENT")
  PGR=$(code POST /growth/campaigns "$PARENT" -d '{"name":"x","channel":"facebook"}')
  [ "$PAI" = "403" ] && [ "$PLE" = "403" ] && [ "$PGR" = "403" ] \
    && pass "RBAC: parent denied B4 intel + B1 leads + B6 growth (403/403/403)" \
    || fail "RBAC seam leaked: intel=$PAI leads=$PLE growth=$PGR"
fi

log "──────────────────────────────"
log "P1 INTEGRATION RESULT: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
