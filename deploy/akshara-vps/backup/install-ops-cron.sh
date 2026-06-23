#!/usr/bin/env bash
# One-time (idempotent) installer for Akshara backup automation on the VPS.
# Run as root from /opt/akshara/backup after deploying this directory there:
#   sudo ./install-ops-cron.sh
#
# It: makes dirs, generates the encryption key if missing, seeds backup.env,
# marks scripts executable, and installs cron jobs (nightly backup + monthly
# restore drill) and a logrotate rule. Re-running is safe.

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ "$(id -u)" -eq 0 ]] || { echo "must run as root (sudo)"; exit 1; }

# Load defaults from backup.env if present, else from the example.
ENV_FILE="$INSTALL_DIR/backup.env"
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$INSTALL_DIR/backup.env.example" "$ENV_FILE"
  echo "seeded $ENV_FILE from example — review RCLONE_REMOTE etc. before relying on off-site"
fi
chmod 600 "$ENV_FILE"
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${BACKUP_ROOT:=/opt/akshara/backup/store}"
: "${LOG_DIR:=/var/log/akshara}"
: "${BACKUP_KEY_FILE:=/opt/akshara/backup/secret.key}"

mkdir -p "$BACKUP_ROOT" "$LOG_DIR" "$(dirname "$BACKUP_KEY_FILE")"

# Generate the encryption passphrase once. NEVER regenerate — it would orphan
# every existing backup. Keep an off-box copy of this key.
if [[ ! -f "$BACKUP_KEY_FILE" ]]; then
  umask 077
  openssl rand -base64 48 > "$BACKUP_KEY_FILE"
  chmod 600 "$BACKUP_KEY_FILE"
  echo "generated NEW encryption key at $BACKUP_KEY_FILE"
  echo ">>> ACTION REQUIRED: copy this key somewhere safe and OFF this server."
  echo ">>> Without it, backups cannot be restored."
else
  echo "encryption key already present at $BACKUP_KEY_FILE (left untouched)"
fi

chmod +x "$INSTALL_DIR"/*.sh

# --- cron jobs -----------------------------------------------------------------
CRON_FILE=/etc/cron.d/akshara-ops
cat > "$CRON_FILE" <<EOF
# Akshara ops — backups + restore drill. Managed by install-ops-cron.sh; edits overwritten.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BACKUP_ENV=$ENV_FILE

# Nightly encrypted backup at 02:15 (server local time).
15 2 * * *   root   $INSTALL_DIR/akshara-backup.sh >> $LOG_DIR/backup.log 2>&1
# Monthly restore drill at 03:30 on the 2nd (after the 1st's monthly backup exists).
30 3 2 * *   root   $INSTALL_DIR/akshara-restore-drill.sh >> $LOG_DIR/drill.log 2>&1
EOF
chmod 644 "$CRON_FILE"
echo "installed cron file $CRON_FILE"

# --- logrotate -----------------------------------------------------------------
cat > /etc/logrotate.d/akshara-ops <<EOF
$LOG_DIR/*.log {
  weekly
  rotate 8
  compress
  delaycompress
  missingok
  notifempty
  copytruncate
}
EOF
echo "installed logrotate rule /etc/logrotate.d/akshara-ops"

echo "done. Run a first backup now with:  $INSTALL_DIR/akshara-backup.sh manual"
