#!/usr/bin/env bash
# ============================================================================
# UX REVIEW DEMO — one-command create / destroy for a temporary UI/UX review.
# ----------------------------------------------------------------------------
# Stands up (or tears down) an isolated demo:
#   * isolated test-tenant API stack on the VPS  (akshara_tenant_test, NOT prod)
#   * 8 login-able demo accounts (owner + 7 roles) seeded into the test tenant
#   * the existing web app, built + served at https://<host>/review/
#
# It NEVER touches production (akshara_db / prod edge / velora-salon / n8n).
#
# Usage:
#   scripts/uxr_review/uxr_review.sh create [ownerPhone]   # build everything
#   scripts/uxr_review/uxr_review.sh destroy               # remove everything
#   scripts/uxr_review/uxr_review.sh set-owner <phone>     # set your login phone
#   scripts/uxr_review/uxr_review.sh status | verify
#
# Requires: an SSH ControlMaster socket to the VPS already open, e.g.
#   ssh -fN -M -S ~/.ssh/akshara-cm.sock -o ControlPersist=12h root@46.28.44.46
# ============================================================================
set -euo pipefail

# ---- config ---------------------------------------------------------------
VPS_HOST="${UXR_VPS_HOST:-root@46.28.44.46}"
SSH_SOCK="${UXR_SSH_SOCK:-$HOME/.ssh/akshara-cm.sock}"
PG_CONTAINER="akshara-postgres"
DB="akshara_tenant_test"                     # <-- HARD-CODED non-prod target
PROD_DB="akshara_db"                          # never allowed
COMPOSE="/opt/akshara/docker-compose.tenant-test.yml"
COMPOSE_DIR="/opt/akshara"
TEST_EDGE="http://127.0.0.1:3001/functions/v1/api"
WEBROOT="/var/www/akshara-review"
ORIGIN="https://api.nikshaos.in"
REVIEW_API="${ORIGIN}/review-api"
NGINX_CONF="/etc/nginx/sites-available/akshara"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEB_DIR="$REPO_ROOT/web"

if [ "$DB" = "$PROD_DB" ]; then echo "FATAL: target DB is production — refusing."; exit 1; fi

sv() { ssh -S "$SSH_SOCK" "$VPS_HOST" "$@"; }
scpv() { scp -o ControlPath="$SSH_SOCK" "$1" "$VPS_HOST:$2" >/dev/null; }
psql_run() { # runs a SQL file (arg1) on the test DB, extra psql args after
  scpv "$1" "/tmp/$(basename "$1")"
  sv "docker exec -i $PG_CONTAINER psql -U supabase_admin -d $DB ${*:2} < /tmp/$(basename "$1")"
}

require_socket() {
  if ! ssh -S "$SSH_SOCK" -O check "$VPS_HOST" >/dev/null 2>&1; then
    echo "ERROR: no live SSH master at $SSH_SOCK."
    echo "Open one:  ssh -fN -M -S $SSH_SOCK -o ControlPersist=12h $VPS_HOST"
    exit 1
  fi
}

# ---- steps ----------------------------------------------------------------
stack_up() {
  echo "==> bringing up isolated test stack ($DB)"
  sv "cd $COMPOSE_DIR && docker compose -f $COMPOSE up -d"
  echo -n "==> waiting for test edge"
  for _ in $(seq 1 20); do
    code=$(sv "curl -s -o /dev/null -w '%{http_code}' -m 8 -X POST $TEST_EDGE/auth/login -H 'Content-Type: application/json' -d '{\"identifier\":\"9900100002\",\"type\":\"phone\"}'" || echo 000)
    [ "$code" = "200" ] && { echo " ready"; return 0; }
    echo -n "."; sleep 3
  done
  echo " TIMEOUT (edge not responding)"; exit 1
}

seed_db() {
  local owner="${1:-+919900100001}"
  echo "==> seeding demo accounts (owner phone: $owner)"
  psql_run "$SCRIPT_DIR/seed.sql" "-v owner_phone=\"$owner\""
}

build_web() {
  echo "==> building web app against $REVIEW_API"
  ( cd "$WEB_DIR" && rm -rf dist && \
    VITE_DATA_MODE=live VITE_API_BASE_URL="$REVIEW_API" node_modules/.bin/vite build --base=/review/ >/dev/null )
  echo "==> deploying static bundle to $WEBROOT/review"
  COPYFILE_DISABLE=1 tar -C "$WEB_DIR/dist" -czf - . | \
    sv "rm -rf $WEBROOT/review && mkdir -p $WEBROOT/review && tar -C $WEBROOT/review -xzf - && find $WEBROOT -name '._*' -delete && chown -R www-data:www-data $WEBROOT"
}

nginx_install() {
  echo "==> installing nginx /review/ + /review-api/ blocks"
  sv "python3 - <<'PY'
import subprocess, sys, shutil
CONF='$NGINX_CONF'
BLOCK='''    # --- UX REVIEW (temporary demo; remove via uxr_review destroy) ---
    location /review/ {
        root $WEBROOT;
        try_files \$uri \$uri/ /review/index.html;
    }
    location /review-api/ {
        proxy_pass http://127.0.0.1:3001/functions/v1/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_read_timeout 120s;
    }
    # --- END UX REVIEW ---

'''
src=open(CONF).read()
if 'UX REVIEW' in src:
    print('   already installed'); sys.exit(0)
lines=src.splitlines(keepends=True); t=None
for i,l in enumerate(lines):
    if l.strip()=='location / {' and 'proxy_pass http://127.0.0.1:3000' in ''.join(lines[i:i+4]):
        t=i; break
if t is None: print('   ERROR: anchor not found'); sys.exit(2)
shutil.copy2(CONF, CONF+'.uxr.bak')
open(CONF,'w').write(''.join(lines[:t])+BLOCK+''.join(lines[t:]))
r=subprocess.run(['nginx','-t'],capture_output=True,text=True)
if r.returncode!=0:
    shutil.copy2(CONF+'.uxr.bak',CONF); print('   nginx -t FAILED, rolled back'); print(r.stderr); sys.exit(3)
subprocess.run(['systemctl','reload','nginx'],check=True); print('   installed + reloaded')
PY"
}

nginx_uninstall() {
  echo "==> removing nginx review blocks"
  sv "python3 - <<'PY'
import subprocess, sys, shutil, re
CONF='$NGINX_CONF'
src=open(CONF).read()
if 'UX REVIEW' not in src:
    print('   not present'); sys.exit(0)
new=re.sub(r'[ \t]*# --- UX REVIEW.*?# --- END UX REVIEW ---\n\n?', '', src, flags=re.S)
shutil.copy2(CONF, CONF+'.uxr.bak')
open(CONF,'w').write(new)
r=subprocess.run(['nginx','-t'],capture_output=True,text=True)
if r.returncode!=0:
    shutil.copy2(CONF+'.uxr.bak',CONF); print('   nginx -t FAILED, rolled back'); print(r.stderr); sys.exit(3)
subprocess.run(['systemctl','reload','nginx'],check=True); print('   removed + reloaded')
PY"
}

# ---- commands -------------------------------------------------------------
cmd_create() {
  require_socket
  stack_up
  seed_db "${1:-+919900100001}"
  build_web
  nginx_install
  echo ""
  cmd_verify
  echo ""
  echo "REVIEW SITE:  $ORIGIN/review/"
  echo "Done. Log in with the demo phones (OTP is shown in the app; dev mode)."
}

cmd_destroy() {
  require_socket
  echo "==> DESTROY: removing the entire UX review demo"
  nginx_uninstall
  echo "==> removing web bundle"
  sv "rm -rf $WEBROOT"
  echo "==> scrubbing demo rows from $DB"
  psql_run "$SCRIPT_DIR/teardown.sql"
  echo "==> stopping isolated test stack"
  sv "cd $COMPOSE_DIR && docker compose -f $COMPOSE down"
  echo "DONE — demo fully removed. Production was never touched."
}

cmd_set_owner() {
  require_socket
  [ -n "${1:-}" ] || { echo "usage: set-owner <phone e.g. +919812345678>"; exit 1; }
  echo "==> setting owner login phone to $1"
  sv "docker exec -i $PG_CONTAINER psql -U supabase_admin -d $DB -c \"update users set phone='$1' where id='de3f0000-0000-4000-8000-000000000001';\""
  echo "Owner can now log in with: $1"
}

cmd_status() {
  require_socket
  echo "== test stack =="; sv "docker ps --filter name=-test --format '{{.Names}}\t{{.Status}}'"
  echo "== demo accounts =="; sv "docker exec -i $PG_CONTAINER psql -U supabase_admin -d $DB -tAc \"select display_name||' '||phone from users where email like '%@uxreview.demo' order by display_name;\""
  echo "== web =="; sv "test -f $WEBROOT/review/index.html && echo 'deployed' || echo 'absent'"
  echo "== nginx =="; sv "grep -q 'UX REVIEW' $NGINX_CONF && echo 'blocks present' || echo 'blocks absent'"
}

cmd_verify() {
  require_socket
  echo "==> verifying all roles via $REVIEW_API"
  for row in "Owner:9900100001:school:/sis/dashboard" "Principal:9900100002:school:/management/dashboard" \
             "Teacher:9900100003:school:/teacher/dashboard" "Finance:9900100004:school:/finance/dashboard" \
             "HR:9900100005:school:" "Office:9900100006:school:" \
             "Parent:9900100007:parent:/parent/dashboard" "Student:9900100008:student:/student/dashboard"; do
    IFS=: read -r label phone scope dash <<< "$row"
    lr=$(curl -s -m 20 -X POST "$REVIEW_API/auth/login" -H 'Content-Type: application/json' -d "{\"identifier\":\"$phone\",\"type\":\"phone\"}")
    otp=$(printf '%s' "$lr" | sed -n 's/.*"otp":"\([0-9]*\)".*/\1/p')
    sid=$(printf '%s' "$lr" | sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p')
    [ -n "$otp" ] || { printf '  %-10s LOGIN FAIL\n' "$label"; continue; }
    vr=$(curl -s -m 20 -X POST "$REVIEW_API/auth/verify-otp" -H 'Content-Type: application/json' \
         -d "{\"identifier\":\"$phone\",\"type\":\"phone\",\"otp\":\"$otp\",\"sessionId\":\"$sid\",\"scope\":\"$scope\",\"schoolId\":\"a2000000-0000-4000-8000-000000000001\"}")
    tok=$(printf '%s' "$vr" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')
    [ -n "$tok" ] || { printf '  %-10s VERIFY FAIL\n' "$label"; continue; }
    if [ -z "$dash" ]; then printf '  %-10s OK (login; Admin Hub)\n' "$label"; continue; fi
    dc=$(curl -s -o /dev/null -w '%{http_code}' -m 20 "$REVIEW_API$dash" -H "Authorization: Bearer $tok")
    printf '  %-10s OK (login + dashboard HTTP %s)\n' "$label" "$dc"
  done
}

case "${1:-}" in
  create)    shift; cmd_create "${1:-}";;
  destroy)   cmd_destroy;;
  set-owner) shift; cmd_set_owner "${1:-}";;
  status)    cmd_status;;
  verify)    cmd_verify;;
  *) echo "usage: $0 {create [ownerPhone] | destroy | set-owner <phone> | status | verify}"; exit 1;;
esac
