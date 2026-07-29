#!/usr/bin/env bash
# B3 Parent Insights — live-cert smoke. Real auth + real DB + real AI.
#
# Exercises the now-surfaced parent flow end-to-end on the live edge:
#   - parent OTP login (school scope)
#   - language preference save + read (multilingual)
#   - AI insight generation (POST /parent-insights/generate) — real provider
#   - insight listing (GET /parent-insights/students/{id})
#   - B3 entitlement gate: feature.parent_insights now wrapped — locked on
#     Standard (402 PLAN_UPGRADE_REQUIRED), unlocked on Professional.
#
# Always restores the org to Professional + language english at the end.
#
# Usage:
#   API_BASE_URL=https://api.nikshaos.in \
#     ADMIN_PHONE=9876543210 PARENT_PHONE=9876543211 \
#     STUDENT_ID=a4000000-0000-4000-8000-000000000001 \
#     scripts/parent_insights_b3_smoke.sh
set -euo pipefail

BASE="${API_BASE_URL:-http://127.0.0.1:54321/functions/v1/api}"
ADMIN_PHONE="${ADMIN_PHONE:-9876543210}"
PARENT_PHONE="${PARENT_PHONE:-9876543211}"
STUDENT_ID="${STUDENT_ID:-a4000000-0000-4000-8000-000000000001}"
FINAL_PLAN="${FINAL_PLAN:-professional}"
PASS=0; FAIL=0

log() { echo "[b3-smoke] $*"; }
pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }
api() { local m="$1" p="$2"; shift 2; curl -sS -X "$m" "${BASE}${p}" -H "Content-Type: application/json" "${@}"; }
ah() { echo "Authorization: Bearer $1"; }
jqp() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)"; }
code() { local m="$1" p="$2" tok="$3"; shift 3; curl -sS -o /dev/null -w "%{http_code}" -X "$m" "${BASE}${p}" -H "$(ah "$tok")" -H "Content-Type: application/json" "${@}"; }

login_phone() { # phone [scope]
  local phone="$1" scope="${2:-}" resp otp sid body
  resp=$(api POST /auth/login -d "{\"identifier\":\"${phone}\",\"type\":\"phone\"}")
  otp=$(echo "$resp" | python3 -c "import sys,json,re; d=json.load(sys.stdin)['data']; print(d.get('otp') or re.search(r'(\\d{4,8})', d.get('message','')).group(1))")
  sid=$(echo "$resp" | jqp "d['data']['sessionId']")
  body="{\"identifier\":\"${phone}\",\"type\":\"phone\",\"otp\":\"${otp}\",\"sessionId\":\"${sid}\""
  [ -n "$scope" ] && body="${body},\"scope\":\"${scope}\""
  body="${body}}"
  api POST /auth/verify-otp -d "$body" | jqp "d['data']['accessToken']"
}

assign_plan() { api PUT "/platform/organizations/$1/subscription" -H "$(ah "$ADMIN_TOKEN")" -d "{\"planSlug\":\"$2\"}"; }
plan_now() {
  api GET /platform/subscriptions -H "$(ah "$ADMIN_TOKEN")" \
    | python3 -c "import sys,json; d=json.load(sys.stdin)['data']['organizations']; print(next((o['planSlug'] for o in d if o['organizationId']=='${ORG_ID}'),''))"
}

log "Base: ${BASE}"

# --- Auth ---
ADMIN_TOKEN=$(login_phone "$ADMIN_PHONE" organization)
[ -n "$ADMIN_TOKEN" ] && pass "superAdmin login (organization scope)" || { fail "superAdmin login"; exit 1; }
ME=$(api GET /auth/me -H "$(ah "$ADMIN_TOKEN")")
ORG_ID=$(echo "$ME" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}); print(d.get('organizationId') or d.get('organization_id') or (d.get('claims',{}) or {}).get('organization_id',''))")
[ -n "$ORG_ID" ] && pass "resolved org ($ORG_ID)" || { fail "resolve org: $ME"; exit 1; }

PARENT_TOKEN=$(login_phone "$PARENT_PHONE")
[ -n "$PARENT_TOKEN" ] && pass "parent login" || { fail "parent login"; exit 1; }

# Ensure starting from Professional (feature.parent_insights granted).
assign_plan "$ORG_ID" professional >/dev/null
[ "$(plan_now)" = "professional" ] && pass "org on Professional" || fail "set Professional"

# --- 1) Language preference (multilingual) ---
api PUT /parent-insights/language-preference -H "$(ah "$PARENT_TOKEN")" \
  -d "{\"language\":\"telugu\",\"studentId\":\"${STUDENT_ID}\"}" >/dev/null
LANG=$(api GET "/parent-insights/language-preference?studentId=${STUDENT_ID}" -H "$(ah "$PARENT_TOKEN")" | jqp "d['data']['language']")
[ "$LANG" = "telugu" ] && pass "language preference saved + read (telugu)" || fail "language pref ($LANG)"

# --- 2) Generate insight (real AI) ---
GEN=$(api POST /parent-insights/generate -H "$(ah "$PARENT_TOKEN")" \
  -d "{\"studentId\":\"${STUDENT_ID}\",\"period\":\"weekly\"}")
GEN_ID=$(echo "$GEN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('id',''))" 2>/dev/null || echo "")
GEN_SUMMARY=$(echo "$GEN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('progressSummary',''))" 2>/dev/null || echo "")
{ [ -n "$GEN_ID" ] && [ -n "$GEN_SUMMARY" ]; } \
  && pass "generated weekly insight (id=$GEN_ID)" || fail "generate: $GEN"

# --- 3) List insights ---
LIST=$(api GET "/parent-insights/students/${STUDENT_ID}" -H "$(ah "$PARENT_TOKEN")")
echo "$LIST" | python3 -c "import sys,json; items=json.load(sys.stdin)['data']['items']; exit(0 if any(i['id']=='${GEN_ID}' for i in items) else 1)" \
  && pass "listed insights include the generated snapshot" || fail "list: $LIST"
echo "$LIST" | python3 -c "import sys,json; items=json.load(sys.stdin)['data']['items']; exit(0 if any(i.get('language')=='telugu' for i in items) else 1)" \
  && pass "listed insight carries telugu language" || fail "list language"

# --- 4) Entitlement gate (B3): Standard locks parent insights ---
assign_plan "$ORG_ID" standard >/dev/null
[ "$(plan_now)" = "standard" ] && pass "downgraded to Standard" || fail "set Standard"
C=$(code POST /parent-insights/generate "$PARENT_TOKEN" -d "{\"studentId\":\"${STUDENT_ID}\",\"period\":\"weekly\"}")
BODY=$(api POST /parent-insights/generate -H "$(ah "$PARENT_TOKEN")" -d "{\"studentId\":\"${STUDENT_ID}\",\"period\":\"weekly\"}")
CODEVAL=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error',{}).get('code',''))" 2>/dev/null || echo "")
{ [ "$C" = "402" ] && [ "$CODEVAL" = "PLAN_UPGRADE_REQUIRED" ]; } \
  && pass "Standard: parent insights locked (402 PLAN_UPGRADE_REQUIRED)" || fail "expected 402, got $C/$CODEVAL"

# --- 5) Upgrade unlocks again ---
assign_plan "$ORG_ID" professional >/dev/null
[ "$(plan_now)" = "professional" ] && pass "restored Professional" || fail "restore Professional"
C=$(code POST /parent-insights/generate "$PARENT_TOKEN" -d "{\"studentId\":\"${STUDENT_ID}\",\"period\":\"weekly\"}")
[ "$C" = "201" ] && pass "Professional: parent insights unlocked (201)" || fail "expected 201, got $C"

# --- Cleanup: leave on final plan + reset language ---
api PUT /parent-insights/language-preference -H "$(ah "$PARENT_TOKEN")" \
  -d "{\"language\":\"english\",\"studentId\":\"${STUDENT_ID}\"}" >/dev/null
assign_plan "$ORG_ID" "$FINAL_PLAN" >/dev/null
[ "$(plan_now)" = "$FINAL_PLAN" ] && pass "final plan = $FINAL_PLAN" || fail "final plan"

log "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
