#!/usr/bin/env bash
# Akshara watchdog (Batch 7) — the thing that tells a human when something breaks.
#
# Every run it checks: API up + DB ready, backup freshness, storage reachable,
# disk headroom, TLS cert expiry, and that every container is running. Anything
# wrong is logged and (with a per-check cooldown so we don't spam) pushed to the
# configured alert sinks: a webhook and/or Fast2SMS. When a previously-failing
# check goes green again it sends a one-time "recovered" notice.
#
# Run by cron every 5 minutes. Manual: ./akshara-watchdog.sh

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${MONITORING_ENV:-/opt/akshara/monitoring/monitoring.env}"
[[ -f "$ENV_FILE" || ! -f "$SELF_DIR/monitoring.env" ]] || ENV_FILE="$SELF_DIR/monitoring.env"
# shellcheck disable=SC1090
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

: "${EDGE_BASE:=http://127.0.0.1:3000}"
: "${PUBLIC_DOMAIN:=akshara.veloraunisexsalon.com}"
: "${CERT_PATH:=/etc/letsencrypt/live/$PUBLIC_DOMAIN/fullchain.pem}"
: "${DISK_WARN_PCT:=85}"
: "${CERT_WARN_DAYS:=14}"
: "${CONTAINERS:=akshara-postgres akshara-postgrest akshara-rest-gateway akshara-edge akshara-storage}"
: "${INTERNAL_HEALTH_TOKEN:=}"
: "${ALERT_WEBHOOK_URL:=}"
: "${ALERT_SMS_PHONES:=}"
: "${ALERT_SMS_API_KEY:=}"
: "${FAST2SMS_ROUTE:=q}"
: "${ALERT_COOLDOWN_MIN:=60}"
: "${STATE_DIR:=/opt/akshara/monitoring/state}"
: "${LOG_DIR:=/var/log/akshara}"
: "${APP_ENV_FILE:=/opt/akshara/.env.akshara}"

mkdir -p "$STATE_DIR" "$LOG_DIR"
HOST="$(hostname -s 2>/dev/null || hostname || echo vps)"
NOW="$(date +%s)"
LOG="$LOG_DIR/watchdog.log"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
logline() { echo "[$(ts)] $*" >> "$LOG"; }

# Fast2SMS key fallback from the app env.
if [[ -z "$ALERT_SMS_API_KEY" && -f "$APP_ENV_FILE" ]]; then
  ALERT_SMS_API_KEY="$(grep -E '^SMS_PROVIDER_API_KEY=' "$APP_ENV_FILE" 2>/dev/null | cut -d= -f2- || true)"
fi

send_alert() {
  local severity="$1" text="$2"
  logline "ALERT[$severity] $text"
  if [[ -n "$ALERT_WEBHOOK_URL" ]]; then
    curl -s -m 10 -X POST "$ALERT_WEBHOOK_URL" \
      -H 'Content-Type: application/json' \
      -d "{\"host\":\"$HOST\",\"severity\":\"$severity\",\"text\":$(json_str "$text")}" >/dev/null 2>&1 || true
  fi
  # SMS only for CRITICAL (keep it cheap + loud).
  if [[ "$severity" == "CRIT" && -n "$ALERT_SMS_PHONES" && -n "$ALERT_SMS_API_KEY" ]]; then
    curl -s -m 10 "https://www.fast2sms.com/dev/bulkV2" \
      -H "authorization: $ALERT_SMS_API_KEY" \
      --data-urlencode "message=Akshara $HOST: $text" \
      --data-urlencode "language=english" \
      --data-urlencode "route=$FAST2SMS_ROUTE" \
      --data-urlencode "numbers=${ALERT_SMS_PHONES//+/}" >/dev/null 2>&1 || true
  fi
}

json_str() { local s="${1//\\/\\\\}"; s="${s//\"/\\\"}"; printf '"%s"' "$s"; }

# Cooldown-aware dispatch. key = stable id of the check; firing on CRIT/WARN.
handle() {
  local level="$1" key="$2" msg="$3"
  local state="$STATE_DIR/$key.firing"
  if [[ "$level" == "OK" ]]; then
    if [[ -f "$state" ]]; then
      rm -f "$state"
      send_alert "OK" "RECOVERED: $msg"
    fi
    return
  fi
  # firing (WARN/CRIT)
  local last=0
  [[ -f "$state" ]] && last="$(cat "$state" 2>/dev/null || echo 0)"
  if (( NOW - last >= ALERT_COOLDOWN_MIN * 60 )); then
    send_alert "$level" "$msg"
    echo "$NOW" > "$state"
  fi
}

# --- checks --------------------------------------------------------------------
hdr=(); [[ -n "$INTERNAL_HEALTH_TOKEN" ]] && hdr=(-H "x-internal-health-token: $INTERNAL_HEALTH_TOKEN")
summary=()

check_endpoint() {
  local name="$1" url="$2" expect="$3"
  local body code
  body="$(curl -s -m 10 -w $'\n%{http_code}' "${hdr[@]}" "$url" 2>/dev/null)"
  code="${body##*$'\n'}"; body="${body%$'\n'*}"
  if [[ "$code" == "200" ]] && { [[ -z "$expect" ]] || grep -q "$expect" <<<"$body"; }; then
    summary+=("$name=OK"); handle OK "$name" "$name ok"
  else
    summary+=("$name=FAIL($code)"); handle CRIT "$name" "$name DOWN (http=$code)"
  fi
}

check_endpoint api_ready   "$EDGE_BASE/health/ready"   '"database":true'
check_endpoint api_backup  "$EDGE_BASE/health/backup"  '"status":"ok"'
check_endpoint api_storage "$EDGE_BASE/health/storage" '"reachable":true'

# disk
disk_pct="$(df -P / | awk 'NR==2{gsub("%","",$5); print $5}')"
if [[ -n "$disk_pct" && "$disk_pct" -ge "$DISK_WARN_PCT" ]]; then
  summary+=("disk=${disk_pct}%!"); handle WARN disk "disk usage ${disk_pct}% >= ${DISK_WARN_PCT}%"
else
  summary+=("disk=${disk_pct}%"); handle OK disk "disk ok"
fi

# cert expiry
if [[ -r "$CERT_PATH" ]]; then
  end="$(openssl x509 -enddate -noout -in "$CERT_PATH" 2>/dev/null | cut -d= -f2)"
  if [[ -n "$end" ]]; then
    end_epoch="$(date -d "$end" +%s 2>/dev/null || echo 0)"
    days_left=$(( (end_epoch - NOW) / 86400 ))
    if (( days_left <= CERT_WARN_DAYS )); then
      summary+=("cert=${days_left}d!"); handle WARN cert "TLS cert expires in ${days_left}d"
    else
      summary+=("cert=${days_left}d"); handle OK cert "cert ok"
    fi
  fi
else
  summary+=("cert=unreadable")
fi

# containers
for c in $CONTAINERS; do
  st="$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo missing)"
  if [[ "$st" != "running" ]]; then
    summary+=("$c=$st!"); handle CRIT "container_$c" "container $c is $st"
  else
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$c" 2>/dev/null)"
    if [[ -n "$health" && "$health" != "healthy" ]]; then
      summary+=("$c=$health!"); handle WARN "container_$c" "container $c health=$health"
    else
      summary+=("$c=up"); handle OK "container_$c" "$c ok"
    fi
  fi
done

logline "check: ${summary[*]}"
