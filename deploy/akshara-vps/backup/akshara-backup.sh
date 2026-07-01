#!/usr/bin/env bash
# Akshara nightly database backup.
#
# What it does (3-2-1 aligned):
#   1. pg_dump the live DB in custom/compressed format, streamed straight into
#      AES-256 encryption (plaintext never touches disk).
#   2. Records a row in ops_backup_runs (size, sha256, location, success/fail) so
#      `/health/backup` and humans can see backup freshness.
#   3. Copies the encrypted artifact OFF the box via rclone (if configured).
#   4. Prunes old local backups on a grandfather-father-son schedule.
#
# Safe to run by hand: ./akshara-backup.sh [manual]
# Cron runs it nightly (see install-ops-cron.sh). A flock prevents overlap.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-common.sh"

require_cmd docker
require_cmd openssl
require_cmd sha256sum

mkdir -p "$BACKUP_ROOT" "$LOG_DIR"

# --- single-instance lock ------------------------------------------------------
LOCK="$BACKUP_ROOT/.backup.lock"
exec 9>"$LOCK"
flock -n 9 || die "another backup is already running (lock: $LOCK)"

# --- preflight -----------------------------------------------------------------
ensure_pg_up
[[ -f "$BACKUP_KEY_FILE" ]] || die "encryption key file missing: $BACKUP_KEY_FILE (run install-ops-cron.sh)"

# Classify this run for retention: monthly on the 1st, weekly on Sunday, else daily.
DOM="$(date -u +%d)"
DOW="$(date -u +%u)"   # 1=Mon .. 7=Sun
if [[ "${1:-}" == "manual" || "${1:-}" == "--manual" ]]; then
  KIND="manual"
elif [[ "$DOM" == "01" ]]; then
  KIND="monthly"
elif [[ "$DOW" == "7" ]]; then
  KIND="weekly"
else
  KIND="nightly"
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
ARTIFACT="$BACKUP_ROOT/akshara_db_${TS}_${KIND}.dump.enc"
START_EPOCH="$(date +%s%3N 2>/dev/null || echo "$(($(date +%s)*1000))")"

# Open a ledger row immediately so a crash mid-dump still leaves a trace.
RUN_ID="$(pg -c "INSERT INTO ops_backup_runs (kind,status,database_name,host) \
  VALUES ('$(sql_str "$KIND")','running','$(sql_str "$AKSHARA_DB_NAME")','$(sql_str "$HOSTNAME_SHORT")') \
  RETURNING id;")"
[[ -n "$RUN_ID" ]] || die "could not open ledger row"

fail() {
  local msg="$1"
  local now_epoch dur
  now_epoch="$(date +%s%3N 2>/dev/null || echo "$(($(date +%s)*1000))")"
  dur=$(( now_epoch - START_EPOCH ))
  rm -f "$ARTIFACT" 2>/dev/null || true
  pg -c "UPDATE ops_backup_runs SET status='failed', error='$(sql_str "$msg")', \
    duration_ms=$dur, finished_at=now() WHERE id='$RUN_ID';" >/dev/null 2>&1 || true
  die "$msg"
}
trap 'fail "unexpected error on line $LINENO"' ERR

# --- dump + encrypt (single pipeline; pipefail catches either stage) ----------
log "starting backup ($KIND) -> $ARTIFACT"
set -o pipefail
if ! docker exec "$AKSHARA_PG_CONTAINER" \
      pg_dump -U "$AKSHARA_DB_USER" -d "$AKSHARA_DB_NAME" -Fc 2>>"$LOG_DIR/backup.log" \
   | openssl enc -aes-256-cbc -pbkdf2 -salt -pass "file:$BACKUP_KEY_FILE" > "$ARTIFACT"; then
  fail "pg_dump|encrypt pipeline failed"
fi
[[ -s "$ARTIFACT" ]] || fail "backup artifact is empty"

SHA="$(sha256sum "$ARTIFACT" | awk '{print $1}')"
BYTES="$(stat -c%s "$ARTIFACT" 2>/dev/null || stat -f%z "$ARTIFACT")"
log "dump complete: $BYTES bytes, sha256=$SHA"

# --- off-site copy -------------------------------------------------------------
OFFSITE=false
OFFSITE_LOC=""
if [[ -n "$RCLONE_REMOTE" ]]; then
  if command -v rclone >/dev/null 2>&1; then
    DEST="$RCLONE_REMOTE/$HOSTNAME_SHORT"
    if rclone copy "$ARTIFACT" "$DEST/" --checksum $RCLONE_FLAGS >>"$LOG_DIR/backup.log" 2>&1; then
      # confirm it actually landed
      if rclone lsf "$DEST/$(basename "$ARTIFACT")" $RCLONE_FLAGS >/dev/null 2>&1; then
        OFFSITE=true
        OFFSITE_LOC="$DEST/$(basename "$ARTIFACT")"
        log "off-site copy OK -> $OFFSITE_LOC"
      else
        log "WARNING: off-site copy reported success but file not found at $DEST"
      fi
    else
      log "WARNING: off-site rclone copy FAILED (backup is local-only)"
    fi
  else
    log "WARNING: RCLONE_REMOTE set but rclone not installed (backup is local-only)"
  fi
else
  log "WARNING: no RCLONE_REMOTE configured — backup is LOCAL-ONLY (violates 3-2-1)"
fi

# --- retention prune (local) ---------------------------------------------------
prune_kind() {
  local kind="$1" keep="$2" f
  # newest first; delete everything past the keep count
  ls -1t "$BACKUP_ROOT"/akshara_db_*_"$kind".dump.enc 2>/dev/null | tail -n +"$((keep+1))" | while read -r f; do
    log "pruning old $kind backup: $(basename "$f")"
    rm -f "$f"
  done || true
}
prune_kind nightly "$KEEP_DAILY"
prune_kind weekly  "$KEEP_WEEKLY"
prune_kind monthly "$KEEP_MONTHLY"
# Off-site retention (best-effort): drop nightly copies older than KEEP_DAILY days.
if [[ "$OFFSITE" == true ]]; then
  rclone delete "$RCLONE_REMOTE/$HOSTNAME_SHORT" --include "akshara_db_*_nightly.dump.enc" \
    --min-age "${KEEP_DAILY}d" $RCLONE_FLAGS >>"$LOG_DIR/backup.log" 2>&1 || true
fi

# --- close ledger row ----------------------------------------------------------
trap - ERR
END_EPOCH="$(date +%s%3N 2>/dev/null || echo "$(($(date +%s)*1000))")"
DUR=$(( END_EPOCH - START_EPOCH ))
pg -c "UPDATE ops_backup_runs SET status='success', artifact_path='$(sql_str "$ARTIFACT")', \
  artifact_bytes=$BYTES, sha256='$(sql_str "$SHA")', encrypted=true, offsite=$OFFSITE, \
  offsite_location=$( [[ -n "$OFFSITE_LOC" ]] && echo "'$(sql_str "$OFFSITE_LOC")'" || echo NULL ), \
  duration_ms=$DUR, finished_at=now() WHERE id='$RUN_ID';" >/dev/null

log "backup SUCCESS ($KIND) in ${DUR}ms (offsite=$OFFSITE)"
