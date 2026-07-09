#!/usr/bin/env bash
# Idempotent installer for the Akshara scheduled-broadcast cron (COM-4). Run
# as root from /opt/akshara/communication-cron after deploying this directory
# there.
#
# NOTE (activation): this installer wires up the CLIENT side (cron + env
# file) only. It does NOT set INTERNAL_CRON_TOKEN on the akshara-edge
# container, and does NOT restart/redeploy anything — that is a separate,
# deliberate activation step (surgical akshara-edge redeploy to pick up the
# new env var). See docs/engineering/eos/COM4_CRON_ACTIVATION_RUNBOOK.md for
# the full, ordered activation sequence. Running this installer alone leaves
# the cron firing 401s (safe — fails closed) until that step is done.

set -euo pipefail
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ "$(id -u)" -eq 0 ]] || { echo "must run as root (sudo)"; exit 1; }

ENV_FILE="$INSTALL_DIR/communication-cron.env"
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$INSTALL_DIR/communication-cron.env.example" "$ENV_FILE"
  echo "seeded $ENV_FILE — set INTERNAL_CRON_TOKEN (openssl rand -base64 48) to match the akshara-edge container's env"
fi
chmod 600 "$ENV_FILE"
chmod +x "$INSTALL_DIR"/*.sh
mkdir -p /var/log/akshara

CRON_FILE=/etc/cron.d/akshara-communications
cat > "$CRON_FILE" <<EOF
# Akshara scheduled-broadcast sweep (COM-4). Managed by install-communication-cron.sh; edits overwritten.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
COMMUNICATION_CRON_ENV=$ENV_FILE

# Every 5 minutes — matches the akshara-watchdog cadence; scheduled broadcasts
# claim "due" rows atomically (FOR UPDATE SKIP LOCKED), so overlap is safe.
*/5 * * * *   root   $INSTALL_DIR/akshara-broadcast-cron.sh >> /var/log/akshara/communication-cron-invoke.log 2>&1
EOF
chmod 644 "$CRON_FILE"
echo "installed $CRON_FILE (every 5 min)"
echo "next: set INTERNAL_CRON_TOKEN in $ENV_FILE AND on the akshara-edge container (see the activation runbook), then:"
echo "  $INSTALL_DIR/akshara-broadcast-cron.sh && tail /var/log/akshara/communication-cron.log"
