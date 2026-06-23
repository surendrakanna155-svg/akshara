#!/usr/bin/env bash
# Idempotent installer for the Akshara watchdog. Run as root from
# /opt/akshara/monitoring after deploying this directory there.

set -euo pipefail
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ "$(id -u)" -eq 0 ]] || { echo "must run as root (sudo)"; exit 1; }

ENV_FILE="$INSTALL_DIR/monitoring.env"
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$INSTALL_DIR/monitoring.env.example" "$ENV_FILE"
  echo "seeded $ENV_FILE — set ALERT_WEBHOOK_URL / ALERT_SMS_PHONES to receive alerts"
fi
chmod 600 "$ENV_FILE"
chmod +x "$INSTALL_DIR"/*.sh
mkdir -p /opt/akshara/monitoring/state /var/log/akshara

CRON_FILE=/etc/cron.d/akshara-watchdog
cat > "$CRON_FILE" <<EOF
# Akshara watchdog — health/disk/cert/container checks. Managed by install-monitoring.sh.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MONITORING_ENV=$ENV_FILE
*/5 * * * *   root   $INSTALL_DIR/akshara-watchdog.sh >> /var/log/akshara/watchdog-cron.log 2>&1
EOF
chmod 644 "$CRON_FILE"
echo "installed $CRON_FILE (every 5 min)"
echo "run once now: $INSTALL_DIR/akshara-watchdog.sh && tail /var/log/akshara/watchdog.log"
