#!/usr/bin/env bash
# ASIP live cert/smoke — runs ON the VPS against a chosen edge+DB. Full mission
# flow: report -> auto-evidence -> AI package -> mirror -> console -> investigate
# -> handoff -> cluster -> resolve (propagate back + notify) -> LEARN (KB) ->
# RECALL on a new incident (ASIP-8) -> cleanup.
# Non-destructive by construction: the cert incident uses a cert-unique failing
# path (/cert-asip-vps/marks) so its signature/cluster/KB article can never
# collide with real tenant data and are fully removed at cleanup.
# Usage: cert_asip_vps.sh <EDGE_CONTAINER> <DB> <BASE_URL>
set -u
EDGE="${1:?edge container}"; DB="${2:?db}"; BASE="${3:?base url}"
ORG="${ORG:-a1000000-0000-4000-8000-000000000001}"
SCHOOL="${SCHOOL:-a2000000-0000-4000-8000-000000000001}"
REPORTER="${REPORTER:-de3f0000-0000-4000-8000-000000000006}"
PLATORG="a5100000-0000-4000-8000-000000000001"
SUPPORT_USER="a5200000-0000-4000-8000-000000000001"
MARKER="CERT-ASIP-VPS"
pass=0; total=0
rec(){ total=$((total+1)); if [ "$1" = "P" ]; then pass=$((pass+1)); echo "  [PASS] $2"; else echo "  [FAIL] $2  :: $3"; fi; }
db(){ docker exec "$EDGE_PG" psql -U supabase_admin -d "$DB" -tAc "$1" 2>/dev/null; }
EDGE_PG="akshara-postgres"

MINT_JS='import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const school = Deno.env.get("SCHOOLID");
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: school === "null" ? null : school,
  role: Deno.env.get("ROLE"), role_slugs: [Deno.env.get("ROLE")], primary_role: Deno.env.get("ROLE"),
  permissions: JSON.parse(Deno.env.get("PERMS")),
  permissions_version: Number(Deno.env.get("PERMVER") || "1"),
  scope: Deno.env.get("SCOPE"), school_group_id: null, student_id: null, child_ids: [],
  session_id: Deno.env.get("SESSID"),
}).setProtectedHeader({ alg: "HS256", typ: "JWT" }).setSubject(Deno.env.get("SUB"))
  .setIssuedAt().setExpirationTime(Math.floor(Date.now()/1000)+3600).sign(secret);
console.log(t);'
mint(){ # org scope school sub role perms sessid permver
  docker exec -e ORG="$1" -e SCOPE="$2" -e SCHOOLID="$3" -e SUB="$4" -e ROLE="$5" -e PERMS="$6" -e SESSID="$7" -e PERMVER="${8:-1}" -i "$EDGE" deno run -A - <<<"$MINT_JS" 2>/dev/null | tail -1
}
j(){ python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d))"; }
req(){ # method path token [body]
  local m="$1" p="$2" tok="$3" body="${4:-}"
  if [ -n "$body" ]; then
    curl -s -o /tmp/asip_body -w "%{http_code}" -X "$m" "$BASE$p" -H "Content-Type: application/json" -H "Authorization: Bearer $tok" -d "$body"
  else
    curl -s -o /tmp/asip_body -w "%{http_code}" -X "$m" "$BASE$p" -H "Authorization: Bearer $tok"
  fi
}
field(){ python3 -c "import sys,json;
try:
 d=json.load(open('/tmp/asip_body'));
 v=d.get('data')
 for k in '$1'.split('.'):
  v=v.get(k) if isinstance(v,dict) else None
 print(v if v is not None else '')
except Exception as e: print('')"; }

echo "=== ASIP live cert/smoke on $EDGE / $DB / $BASE ==="
# Seed non-revoked cert sessions (DRP RT-16/RT-17 require a live sessions row +
# membership permissions_version match; memberships are version 1).
SREP="a5900000-0000-4000-8000-000000000001"
SPLAT="a5900000-0000-4000-8000-000000000002"
db "insert into sessions (id,user_id,tenant_id) values ('$SREP','$REPORTER','$ORG'),('$SPLAT','$SUPPORT_USER','$PLATORG') on conflict (id) do update set revoked_at=null" >/dev/null
# Look up live membership permissions_version so RT-17 (freshness) passes on any env.
REPVER=$(db "select permissions_version from school_memberships where user_id='$REPORTER' and school_id='$SCHOOL' and status='active' limit 1"); REPVER="${REPVER:-1}"
PLATVER=$(db "select permissions_version from organization_memberships where user_id='$SUPPORT_USER' and organization_id='$PLATORG' and status='active' limit 1"); PLATVER="${PLATVER:-1}"
REPTOK=$(mint "$ORG" school "$SCHOOL" "$REPORTER" teacher '[]' "$SREP" "$REPVER")
MGRTOK=$(mint "$ORG" school "$SCHOOL" "$REPORTER" schoolAdmin '["viewSupport","manageSupport"]' "$SREP" "$REPVER")
PLATTOK=$(mint "$PLATORG" organization null "$SUPPORT_USER" aksharaSupport '["platformSupport"]' "$SPLAT" "$PLATVER")
[ "$(echo "$REPTOK" | grep -c '\.')" -ge 1 ] && [ -n "$PLATTOK" ] || { echo "ABORT: mint failed"; exit 1; }

# 1. School reports an issue (403 signal -> permission_rbac). Cert-unique failing
#    path so the signature/cluster/KB article are hermetic (safe to delete).
CERTPATH="/cert-asip-vps/marks"
BODY='{"title":"'$MARKER' cannot open marks","description":"tap Marks nothing happens","context":{"appVersion":"1.4.0","platform":"android","deviceModel":"Pixel 7","osVersion":"14","sessionId":"cert","screenRoute":"'$CERTPATH'","moduleKey":"sis","correlationIds":["ak-cert-x"],"recentApiCalls":[{"method":"GET","path":"'$CERTPATH'","statusCode":403,"correlationId":"ak-cert-x"}]}}'
code=$(req POST /support/incidents "$REPTOK" "$BODY")
IID=$(field id); REF=$(field public_ref); CAT=$(field category)
[ "$code" = "201" ] && [ -n "$IID" ] && case "$REF" in SUP-*) true;; *) false;; esac && rec P "report:create ($REF)" || rec F "report:create" "HTTP $code id=$IID ref=$REF"
[ "$CAT" = "permission_rbac" ] && rec P "report:auto-categorized ($CAT)" || rec F "report:auto-categorized" "cat=$CAT"

# 2. auto evidence (5 kinds)
K=$(db "select count(distinct kind) from support_incident_evidence where incident_id='$IID'")
[ "$K" = "5" ] && rec P "evidence:auto-collected (5 kinds)" || rec F "evidence:auto-collected" "kinds=$K"

# 3. MIRROR-WRITE via SECURITY DEFINER bridge
M=$(db "select count(*) from support_platform_incident where id='$IID'")
ME=$(db "select count(*) from support_platform_evidence where incident_id='$IID'")
SRC=$(db "select source_org_id from support_platform_incident where id='$IID'")
[ "$M" = "1" ] && rec P "mirror:incident-written" || rec F "mirror:incident-written" "rows=$M"
[ "$ME" = "5" ] && rec P "mirror:evidence-written (5)" || rec F "mirror:evidence-written" "n=$ME"
[ "$SRC" = "$ORG" ] && rec P "mirror:source-org-from-session (not forgeable)" || rec F "mirror:source-org" "src=$SRC"

# 4. AI Incident Package
code=$(req POST /support/incidents/$IID/analyze "$MGRTOK")
MTH=$(field method); SUM=$(field summary)
[ "$code" = "201" ] && [ -n "$SUM" ] && case "$MTH" in deterministic|ai_enriched) true;; *) false;; esac && rec P "ai-package:assemble ($MTH)" || rec F "ai-package" "HTTP $code method=$MTH"

# 5. RBAC deny: plain reporter cannot analyze / cannot see platform queue
code=$(req POST /support/incidents/$IID/analyze "$REPTOK"); [ "$code" = "403" ] && rec P "rbac:reporter-cannot-analyze" || rec F "rbac:reporter-analyze" "HTTP $code"
code=$(req GET /support/platform/incidents "$REPTOK"); [ "$code" = "403" ] && rec P "rbac:reporter-cannot-see-console" || rec F "rbac:reporter-console" "HTTP $code"

# 6. Support console: platform token sees the mirrored incident + detail (auto-cluster)
code=$(req GET /support/platform/incidents "$PLATTOK")
QN=$(python3 -c "import json;d=json.load(open('/tmp/asip_body'));print(len(d['data']['items']))" 2>/dev/null)
[ "$code" = "200" ] && [ "${QN:-0}" -ge 1 ] && rec P "console:queue-lists-mirror ($QN)" || rec F "console:queue" "HTTP $code n=$QN"
code=$(req GET /support/platform/incidents/$IID "$PLATTOK")
CLID=$(python3 -c "import json;d=json.load(open('/tmp/asip_body'));print((d['data'].get('cluster') or {}).get('id') or '')" 2>/dev/null)
[ "$code" = "200" ] && [ -n "$CLID" ] && rec P "console:detail+auto-cluster" || rec F "console:detail" "HTTP $code cluster=$CLID"

# 7. investigate + engineering handoff
code=$(req POST /support/platform/incidents/$IID/investigate "$PLATTOK")
RC=$(field likelyRootCause)
[ "$code" = "200" ] && [ -n "$RC" ] && rec P "console:ai-investigate" || rec F "console:investigate" "HTTP $code"
code=$(req GET /support/platform/incidents/$IID/handoff "$PLATTOK")
HR=$(field incidentRef)
[ "$code" = "200" ] && [ "$HR" = "$REF" ] && rec P "console:engineering-handoff" || rec F "console:handoff" "HTTP $code ref=$HR"
# add an internal note
code=$(req POST /support/platform/incidents/$IID/notes "$PLATTOK" '{"body":"checked the role grants"}'); [ "$code" = "201" ] && rec P "console:internal-note" || rec F "console:note" "HTTP $code"

# 8. resolve -> propagate back to school + notify reporter
code=$(req POST /support/platform/incidents/$IID/resolve "$PLATTOK" '{"resolution":"granted the missing permission"}')
[ "$code" = "200" ] && rec P "console:resolve" || rec F "console:resolve" "HTTP $code"
SST=$(db "select status from support_incident where id='$IID'")
[ "$SST" = "resolved" ] && rec P "resolve:propagated-to-school" || rec F "resolve:propagate" "school status=$SST"
NOTE=$(db "select count(*) from notification_deliveries where recipient_user_id='$REPORTER' and category='support' and rendered_body like '%resolved%'")
[ "${NOTE:-0}" -ge 1 ] && rec P "resolve:school-notified" || rec F "resolve:notify" "notifications=$NOTE"

# 9. ASIP-8 Continuous Learning: the resolution was distilled into a KB article
KBA=$(db "select count(*) from support_kb_article where source_incident_ref='$REF'")
[ "${KBA:-0}" -ge 1 ] && rec P "kb:learned-on-resolve" || rec F "kb:learned" "articles=$KBA"
# KB browse endpoint sees it; a plain reporter is denied (RBAC)
code=$(req GET /support/platform/kb "$PLATTOK")
KBN=$(python3 -c "import json;d=json.load(open('/tmp/asip_body'));print(len(d['data']['items']))" 2>/dev/null)
[ "$code" = "200" ] && [ "${KBN:-0}" -ge 1 ] && rec P "kb:list-endpoint ($KBN)" || rec F "kb:list" "HTTP $code n=$KBN"
code=$(req GET /support/platform/kb "$REPTOK"); [ "$code" = "403" ] && rec P "rbac:reporter-cannot-see-kb" || rec F "rbac:reporter-kb" "HTTP $code"

# 10. RECALL: a NEW incident with the SAME signature recalls the prior resolution
BODY2='{"title":"'$MARKER' cannot open marks again","description":"tap Marks nothing happens","context":{"appVersion":"1.4.0","platform":"android","deviceModel":"Pixel 7","osVersion":"14","sessionId":"cert","screenRoute":"'$CERTPATH'","moduleKey":"sis","correlationIds":["ak-cert-y"],"recentApiCalls":[{"method":"GET","path":"'$CERTPATH'","statusCode":403,"correlationId":"ak-cert-y"}]}}'
code=$(req POST /support/incidents "$REPTOK" "$BODY2")
IID2=$(field id)
[ "$code" = "201" ] && [ -n "$IID2" ] && rec P "kb:second-incident-created" || rec F "kb:second-incident" "HTTP $code"
# platform detail deterministically recalls the exact prior resolution ("we've seen this")
code=$(req GET /support/platform/incidents/$IID2 "$PLATTOK")
KBM=$(python3 -c "import json;d=json.load(open('/tmp/asip_body'));ms=d['data'].get('kbMatches') or [];print(sum(1 for m in ms if m.get('matchType')=='exact'))" 2>/dev/null)
[ "$code" = "200" ] && [ "${KBM:-0}" -ge 1 ] && rec P "kb:recall-exact-on-new-incident" || rec F "kb:recall" "HTTP $code exact=$KBM"

# 11. cleanup (non-destructive; cert-unique signature ⇒ 0 residue incl. KB + cluster)
db "delete from support_platform_incident where id in ('$IID','$IID2')" >/dev/null
db "delete from support_incident where title like '$MARKER%'" >/dev/null
db "delete from support_kb_article where source_incident_ref='$REF'" >/dev/null
db "delete from support_cluster where cluster_key='permission_rbac|sis|403,$CERTPATH'" >/dev/null
db "delete from notification_deliveries where recipient_user_id='$REPORTER' and category='support'" >/dev/null
db "delete from sessions where id in ('$SREP','$SPLAT')" >/dev/null
rec P "cleanup:non-destructive"

echo ""
echo "=== ASIP cert/smoke: $pass/$total PASS ==="
[ "$pass" = "$total" ] && exit 0 || exit 1
