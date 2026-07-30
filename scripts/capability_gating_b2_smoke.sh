#!/usr/bin/env bash
# B2 Capability Gating (entitlement layer) — live-cert smoke. Real auth + real DB.
#
# Exercises: plan catalog, resolved subscription, superAdmin plan assignment
# (PUT, SECURITY DEFINER), and server-side enforcement (402 PLAN_UPGRADE_REQUIRED
# on a locked module → allowed after upgrade). Operates on the admin's OWN org
# (the pilot), which the superAdmin both reads and assigns.
#
# Requires ENTITLEMENT_ENFORCEMENT=true on the edge for the 402 checks.
#
# Usage:
#   API_BASE_URL=https://api.nikshaos.in ADMIN_PHONE=<superadmin> \
#     scripts/capability_gating_b2_smoke.sh
#   FINAL_PLAN=professional  # plan to leave the org on at the end (default professional)
set -euo pipefail

BASE="${API_BASE_URL:-http://127.0.0.1:54321/functions/v1/api}"
ADMIN_PHONE="${ADMIN_PHONE:-9876543210}"
FINAL_PLAN="${FINAL_PLAN:-professional}"
GATED_PATH="${GATED_PATH:-/transport/routes}"   # gated on module.transport
PASS=0; FAIL=0

log() { echo "[b2-smoke] $*"; }
pass() { PASS=$((PASS + 1)); log "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); log "FAIL: $*"; }
api() { local m="$1" p="$2"; shift 2; curl -sS -X "$m" "${BASE}${p}" -H "Content-Type: application/json" "${@}"; }
ah() { echo "Authorization: Bearer $1"; }
jqp() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)"; }
code() { local m="$1" p="$2" tok="$3"; curl -sS -o /dev/null -w "%{http_code}" -X "$m" "${BASE}${p}" -H "$(ah "$tok")" -H "Content-Type: application/json"; }

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

assign_plan() { # org, plan
  api PUT "/platform/organizations/$1/subscription" -H "$(ah "$ADMIN_TOKEN")" -d "{\"planSlug\":\"$2\"}"
}
# superAdmin token is organization-scoped, so verify the plan via the platform
# list (GET /subscription requires school scope and is covered separately).
plan_now() {
  api GET /platform/subscriptions -H "$(ah "$ADMIN_TOKEN")" \
    | python3 -c "import sys,json; d=json.load(sys.stdin)['data']['organizations']; print(next((o['planSlug'] for o in d if o['organizationId']=='${ORG_ID}'),''))"
}

log "Base: ${BASE}"
ADMIN_TOKEN=$(login_phone "$ADMIN_PHONE" organization)
[ -n "$ADMIN_TOKEN" ] && pass "superAdmin login (organization scope)" || { fail "superAdmin login"; exit 1; }

# Org under test = admin's own org.
ME=$(api GET /auth/me -H "$(ah "$ADMIN_TOKEN")")
ORG_ID=$(echo "$ME" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}); print(d.get('organizationId') or d.get('organization_id') or d.get('tenantId') or d.get('tenant_id') or (d.get('claims',{}) or {}).get('organization_id',''))")
[ -n "$ORG_ID" ] && pass "resolved org under test ($ORG_ID)" || { fail "could not resolve org id: $ME"; exit 1; }

# 1) Plan catalog.
PLANS=$(api GET /plans -H "$(ah "$ADMIN_TOKEN")")
echo "$PLANS" | python3 -c "import sys,json; p=json.load(sys.stdin)['data']['plans']; s={x['slug'] for x in p}; exit(0 if {'trial','standard','professional','enterprise'}.issubset(s) else 1)" \
  && pass "GET /plans returns the 4-tier catalog" || fail "GET /plans: $PLANS"

# 2) RBAC: a non-superAdmin cannot assign plans.
if [ -n "${SCHOOL_PHONE:-}" ]; then
  ST=$(login_phone "$SCHOOL_PHONE")
  C=$(curl -sS -o /dev/null -w "%{http_code}" -X PUT "${BASE}/platform/organizations/${ORG_ID}/subscription" -H "$(ah "$ST")" -H "Content-Type: application/json" -d '{"planSlug":"enterprise"}')
  [ "$C" = "403" ] && pass "non-superAdmin assign denied (403)" || fail "RBAC assign ($C)"
fi

# 3) Assign Standard → verify → gated module 402.
assign_plan "$ORG_ID" standard >/dev/null
[ "$(plan_now)" = "standard" ] && pass "assigned + resolved Standard" || fail "resolve Standard"
C=$(code GET "$GATED_PATH" "$ADMIN_TOKEN")
BODY=$(api GET "$GATED_PATH" -H "$(ah "$ADMIN_TOKEN")")
CODEVAL=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error',{}).get('code',''))" 2>/dev/null || echo "")
{ [ "$C" = "402" ] && [ "$CODEVAL" = "PLAN_UPGRADE_REQUIRED" ]; } \
  && pass "Standard: gated module 402 PLAN_UPGRADE_REQUIRED" || fail "expected 402/PLAN_UPGRADE_REQUIRED, got $C/$CODEVAL"

# 4) Upgrade to Professional → same module no longer 402.
assign_plan "$ORG_ID" professional >/dev/null
[ "$(plan_now)" = "professional" ] && pass "upgraded + resolved Professional" || fail "resolve Professional"
C=$(code GET "$GATED_PATH" "$ADMIN_TOKEN")
BODY=$(api GET "$GATED_PATH" -H "$(ah "$ADMIN_TOKEN")")
CODEVAL=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error',{}).get('code',''))" 2>/dev/null || echo "")
{ [ "$C" != "402" ] && [ "$CODEVAL" != "PLAN_UPGRADE_REQUIRED" ]; } \
  && pass "Professional: gated module unlocked (no 402, got $C)" || fail "still locked after upgrade ($C/$CODEVAL)"

# 5) Leave the org on the correct final plan.
assign_plan "$ORG_ID" "$FINAL_PLAN" >/dev/null
[ "$(plan_now)" = "$FINAL_PLAN" ] && pass "final plan = $FINAL_PLAN" || fail "final plan set ($FINAL_PLAN)"

log "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
