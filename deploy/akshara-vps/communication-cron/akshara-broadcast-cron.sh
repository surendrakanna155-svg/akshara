#!/usr/bin/env bash
# Akshara scheduled-broadcast cron (COM-4) — triggers the all-orgs sweep of
# POST /communications/broadcasts/run-scheduled from a periodic cron instead
# of a user session. Authenticates with `x-internal-cron-token`, NEVER a JWT
# (see supabase/functions/_shared/communication/communication_cron_auth.ts —
# a missing/wrong/unset token always fails closed with 401, no fallback).
#
# Run by cron every 5 minutes (see install-communication-cron.sh). Manual:
#   ./akshara-broadcast-cron.sh

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${COMMUNICATION_CRON_ENV:-/opt/akshara/communication-cron/communication-cron.env}"
[[ -f "$ENV_FILE" || ! -f "$SELF_DIR/communication-cron.env" ]] || ENV_FILE="$SELF_DIR/communication-cron.env"
# shellcheck disable=SC1090
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

: "${EDGE_BASE:=http://127.0.0.1:3000}"
: "${INTERNAL_CRON_TOKEN:=}"
: "${LOG_DIR:=/var/log/akshara}"

mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/communication-cron.log"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
logline() { echo "[$(ts)] $*" >> "$LOG"; }

if [[ -z "$INTERNAL_CRON_TOKEN" ]]; then
  logline "ABORT: INTERNAL_CRON_TOKEN is not set in $ENV_FILE — refusing to call an unauthenticated run"
  echo "INTERNAL_CRON_TOKEN is not set in $ENV_FILE" >&2
  exit 1
fi

body_and_code="$(curl -s -m 30 -w $'\n%{http_code}' -X POST \
  -H "x-internal-cron-token: $INTERNAL_CRON_TOKEN" \
  -H "content-type: application/json" \
  "$EDGE_BASE/communications/broadcasts/run-scheduled" 2>&1)"
code="${body_and_code##*$'\n'}"
body="${body_and_code%$'\n'*}"

if [[ "$code" == "200" ]]; then
  logline "OK run-scheduled http=$code body=$body"
  exit 0
else
  logline "FAIL run-scheduled http=$code body=$body"
  echo "run-scheduled failed: http=$code" >&2
  exit 1
fi
