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
# Safe to run by hand: ./akshara-backup.sh [manual] [--dry-run]
# Cron runs it nightly (see install-ops-cron.sh). A flock prevents overlap.
#
#   manual     classify this run as "manual" for retention (instead of the
#              date-derived nightly/weekly/monthly kind).
#   --dry-run  do the real dump+encrypt+ledger as usual, but only LOG the
#              off-site rclone command(s) instead of running them — proves the
#              off-site wiring end-to-end without rclone installed or any R2
#              credentials configured. See docs/engineering/eos/OFFSITE_BACKUP_R2_RUNBOOK.md.

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

# Parse args (order-independent; both can be combined, e.g. `manual --dry-run`).
MANUAL=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    manual|--manual) MANUAL=true ;;
    dry-run|--dry-run) DRY_RUN=true ;;
  esac
done

# Classify this run for retention: monthly on the 1st, weekly on Sunday, else daily.
DOM="$(date -u +%d)"
DOW="$(date -u +%u)"   # 1=Mon .. 7=Sun
if [[ "$MANUAL" == true ]]; then
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

# --- off-site copy ---------------------------------------------------------
# offsite_copy (lib-common.sh) sets OFFSITE / OFFSITE_LOC. Opt-in: no-op with a
# loud log line while RCLONE_REMOTE is unset (today's default, zero change).
# --dry-run logs the would-be rclone command without needing rclone/credentials.
offsite_copy "$ARTIFACT" "$DRY_RUN"

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
offsite_prune "$DRY_RUN"

# --- close ledger row ----------------------------------------------------------
trap - ERR
END_EPOCH="$(date +%s%3N 2>/dev/null || echo "$(($(date +%s)*1000))")"
DUR=$(( END_EPOCH - START_EPOCH ))
pg -c "UPDATE ops_backup_runs SET status='success', artifact_path='$(sql_str "$ARTIFACT")', \
  artifact_bytes=$BYTES, sha256='$(sql_str "$SHA")', encrypted=true, offsite=$OFFSITE, \
  offsite_location=$( [[ -n "$OFFSITE_LOC" ]] && echo "'$(sql_str "$OFFSITE_LOC")'" || echo NULL ), \
  duration_ms=$DUR, finished_at=now() WHERE id='$RUN_ID';" >/dev/null

if [[ "$DRY_RUN" == true ]]; then
  log "backup SUCCESS ($KIND) in ${DUR}ms (offsite=$OFFSITE, off-site step was --dry-run)"
else
  log "backup SUCCESS ($KIND) in ${DUR}ms (offsite=$OFFSITE)"
fi
