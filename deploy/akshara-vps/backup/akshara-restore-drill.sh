#!/usr/bin/env bash
# Akshara automated restore drill — "a backup you have never restored is not a backup."
#
# Restores the most recent (or a given) encrypted backup into a THROWAWAY db,
# sanity-checks it (table count + key tables have rows), records the result in
# ops_restore_drills, then drops the throwaway db. Run monthly by cron.
#
# Usage: ./akshara-restore-drill.sh [artifact.dump.enc] [--keep]

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-common.sh"

require_cmd docker
require_cmd openssl
ensure_pg_up

ARTIFACT="${1:-}"
KEEP="${2:-}"
if [[ "$ARTIFACT" == "--keep" ]]; then KEEP="--keep"; ARTIFACT=""; fi
if [[ -z "$ARTIFACT" ]]; then
  ARTIFACT="$(ls -1t "$BACKUP_ROOT"/akshara_db_*.dump.enc 2>/dev/null | head -n1 || true)"
fi
[[ -n "$ARTIFACT" && -f "$ARTIFACT" ]] || die "no backup artifact found to drill (looked in $BACKUP_ROOT)"

START_EPOCH="$(date +%s%3N 2>/dev/null || echo "$(($(date +%s)*1000))")"
DRILL_ID="$(pg -c "INSERT INTO ops_restore_drills (status,host,source_artifact,target_db) \
  VALUES ('running','$(sql_str "$HOSTNAME_SHORT")','$(sql_str "$(basename "$ARTIFACT")")','$(sql_str "$DRILL_DB")') \
  RETURNING id;")"

cleanup() {
  if [[ "$KEEP" != "--keep" ]]; then
    PG_DB_OVERRIDE=postgres pg -c "DROP DATABASE IF EXISTS \"$DRILL_DB\";" >/dev/null 2>&1 || true
  fi
}

fail() {
  local msg="$1" now dur
  now="$(date +%s%3N 2>/dev/null || echo "$(($(date +%s)*1000))")"
  dur=$(( now - START_EPOCH ))
  cleanup
  pg -c "UPDATE ops_restore_drills SET status='failed', error='$(sql_str "$msg")', \
    duration_ms=$dur, finished_at=now() WHERE id='$DRILL_ID';" >/dev/null 2>&1 || true
  die "$msg"
}
trap 'fail "unexpected error on line $LINENO"' ERR

log "drilling restore of $(basename "$ARTIFACT") -> $DRILL_DB"
BACKUP_ENV="$BACKUP_ENV" "$(dirname "${BASH_SOURCE[0]}")/akshara-restore.sh" "$ARTIFACT" "$DRILL_DB" >/dev/null \
  || fail "restore into drill db failed"

# --- verify the restored data is real -----------------------------------------
TABLES="$(PG_DB_OVERRIDE="$DRILL_DB" pg -c \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")"
[[ "$TABLES" =~ ^[0-9]+$ && "$TABLES" -gt 100 ]] || fail "restored db has too few tables ($TABLES, expected >100)"

ORGS="$(PG_DB_OVERRIDE="$DRILL_DB" pg -c "SELECT count(*) FROM organizations;" 2>/dev/null || echo 0)"
USERS="$(PG_DB_OVERRIDE="$DRILL_DB" pg -c "SELECT count(*) FROM users;" 2>/dev/null || echo 0)"
ROWS=$(( ${ORGS:-0} + ${USERS:-0} ))
MISMATCH=""
if [[ "${ORGS:-0}" -lt 1 ]]; then MISMATCH="organizations table empty after restore"; fi

now="$(date +%s%3N 2>/dev/null || echo "$(($(date +%s)*1000))")"
DUR=$(( now - START_EPOCH ))
trap - ERR
cleanup

if [[ -n "$MISMATCH" ]]; then
  pg -c "UPDATE ops_restore_drills SET status='failed', tables_checked=$TABLES, rows_sampled=$ROWS, \
    mismatch='$(sql_str "$MISMATCH")', duration_ms=$DUR, finished_at=now() WHERE id='$DRILL_ID';" >/dev/null
  die "drill FAILED: $MISMATCH"
fi

pg -c "UPDATE ops_restore_drills SET status='success', tables_checked=$TABLES, rows_sampled=$ROWS, \
  duration_ms=$DUR, finished_at=now() WHERE id='$DRILL_ID';" >/dev/null
log "drill SUCCESS: $TABLES tables, orgs=$ORGS users=$USERS, ${DUR}ms"
