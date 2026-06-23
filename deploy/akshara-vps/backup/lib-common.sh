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
