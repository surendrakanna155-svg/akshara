#!/usr/bin/env bash
# Shared helpers for Akshara backup tooling. Sourced by the other scripts.
# Not executable on its own.

set -euo pipefail

# Resolve config: BACKUP_ENV env var > /opt/akshara/backup/backup.env > sibling backup.env
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ENV="${BACKUP_ENV:-/opt/akshara/backup/backup.env}"
if [[ ! -f "$BACKUP_ENV" && -f "$_self_dir/backup.env" ]]; then
  BACKUP_ENV="$_self_dir/backup.env"
fi
if [[ -f "$BACKUP_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$BACKUP_ENV"
fi

# Defaults (overridable via backup.env).
: "${AKSHARA_PG_CONTAINER:=akshara-postgres}"
: "${AKSHARA_DB_NAME:=akshara_db}"
: "${AKSHARA_DB_USER:=supabase_admin}"
: "${BACKUP_ROOT:=/opt/akshara/backup/store}"
: "${LOG_DIR:=/var/log/akshara}"
: "${BACKUP_KEY_FILE:=/opt/akshara/backup/secret.key}"
: "${KEEP_DAILY:=7}"
: "${KEEP_WEEKLY:=4}"
: "${KEEP_MONTHLY:=12}"
: "${RCLONE_REMOTE:=}"
: "${RCLONE_FLAGS:=}"
: "${RCLONE_CONFIG_FILE:=}"
: "${DRILL_DB:=akshara_db_drill}"

HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname || echo vps)"

log() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$ts] $*"
}

die() {
  log "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

# Run psql inside the postgres container as the superuser. Extra args passed through.
# -qAt => quiet (no "INSERT 0 1" command tags), unaligned, tuples-only — so a
# `... RETURNING id` capture yields ONLY the scalar value.
pg() {
  docker exec -i "$AKSHARA_PG_CONTAINER" \
    psql -q -v ON_ERROR_STOP=1 -U "$AKSHARA_DB_USER" -d "${PG_DB_OVERRIDE:-$AKSHARA_DB_NAME}" -At "$@"
}

# Escape a string for safe single-quoted inclusion in SQL.
sql_str() {
  local s="${1:-}"
  printf "%s" "${s//\'/\'\'}"
}

# Verify the postgres container is up and accepting connections.
ensure_pg_up() {
  docker exec "$AKSHARA_PG_CONTAINER" pg_isready -U "$AKSHARA_DB_USER" -d "$AKSHARA_DB_NAME" >/dev/null 2>&1 \
    || die "postgres container '$AKSHARA_PG_CONTAINER' not ready"
}

# Off-site copy of an already-produced encrypted artifact via rclone.
#
# Sets globals OFFSITE (true/false) and OFFSITE_LOC (remote path or "").
# Opt-in and additive: with RCLONE_REMOTE unset this is a no-op (one log line,
# current local-only behavior is unchanged) — the 3-2-1 gap is only closed once
# an operator sets RCLONE_REMOTE (+ optionally RCLONE_CONFIG_FILE) for real.
#
# dry_run=true logs the exact rclone invocation(s) it WOULD run and returns —
# it never shells out to rclone, so it needs neither the rclone binary nor any
# credentials. This is how the wiring is proven correct before creds exist:
#   offsite_copy "$ARTIFACT" true
offsite_copy() {
  local artifact="$1" dry_run="${2:-false}"
  OFFSITE=false
  OFFSITE_LOC=""

  if [[ -z "$RCLONE_REMOTE" ]]; then
    log "WARNING: no RCLONE_REMOTE configured — backup is LOCAL-ONLY (violates 3-2-1)"
    return 0
  fi

  local dest="$RCLONE_REMOTE/$HOSTNAME_SHORT"
  local rclone_cfg_arg=""
  [[ -n "$RCLONE_CONFIG_FILE" ]] && rclone_cfg_arg="--config $RCLONE_CONFIG_FILE"

  if [[ "$dry_run" == true ]]; then
    log "[dry-run] off-site wiring check (no network call, no rclone/credentials required):"
    log "[dry-run]   would run:    rclone copy \"$artifact\" \"$dest/\" --checksum $rclone_cfg_arg $RCLONE_FLAGS"
    log "[dry-run]   would verify: rclone lsf \"$dest/$(basename "$artifact")\" $rclone_cfg_arg $RCLONE_FLAGS"
    log "[dry-run]   would prune:  rclone delete \"$dest\" --include 'akshara_db_*_nightly.dump.enc' --min-age ${KEEP_DAILY}d $rclone_cfg_arg $RCLONE_FLAGS"
    log "[dry-run] off-site wiring OK — set real RCLONE_REMOTE credentials to go live"
    return 0
  fi

  if ! command -v rclone >/dev/null 2>&1; then
    log "WARNING: RCLONE_REMOTE set but rclone not installed (backup is local-only)"
    return 0
  fi

  if rclone copy "$artifact" "$dest/" --checksum $rclone_cfg_arg $RCLONE_FLAGS >>"$LOG_DIR/backup.log" 2>&1; then
    # confirm it actually landed
    if rclone lsf "$dest/$(basename "$artifact")" $rclone_cfg_arg $RCLONE_FLAGS >/dev/null 2>&1; then
      OFFSITE=true
      OFFSITE_LOC="$dest/$(basename "$artifact")"
      log "off-site copy OK -> $OFFSITE_LOC"
    else
      log "WARNING: off-site copy reported success but file not found at $dest"
    fi
  else
    log "WARNING: off-site rclone copy FAILED (backup is local-only)"
  fi
}

# Best-effort remote prune of aged nightly copies. No-op (logged) if off-site
# was never reached this run, RCLONE_REMOTE is unset, or dry_run is true.
offsite_prune() {
  local dry_run="${1:-false}"
  [[ -n "$RCLONE_REMOTE" ]] || return 0
  local rclone_cfg_arg=""
  [[ -n "$RCLONE_CONFIG_FILE" ]] && rclone_cfg_arg="--config $RCLONE_CONFIG_FILE"
  if [[ "$dry_run" == true ]]; then
    return 0  # already logged the intended prune inside offsite_copy's dry-run branch
  fi
  [[ "$OFFSITE" == true ]] || return 0
  rclone delete "$RCLONE_REMOTE/$HOSTNAME_SHORT" --include "akshara_db_*_nightly.dump.enc" \
    --min-age "${KEEP_DAILY}d" $rclone_cfg_arg $RCLONE_FLAGS >>"$LOG_DIR/backup.log" 2>&1 || true
}
