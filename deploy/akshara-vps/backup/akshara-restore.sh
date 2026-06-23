#!/usr/bin/env bash
# Akshara database restore — decrypt an encrypted backup and load it into a DB.
#
# Usage:
#   ./akshara-restore.sh <artifact.dump.enc> <target_db> [--force]
#
# By default it REFUSES to restore over the live database ($AKSHARA_DB_NAME).
# Pass --force only if you truly mean to overwrite production (disaster recovery).
# For a safe verification, restore into a throwaway db name instead, or use
# akshara-restore-drill.sh.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-common.sh"

ARTIFACT="${1:-}"
TARGET_DB="${2:-}"
FORCE="${3:-}"

[[ -n "$ARTIFACT" && -n "$TARGET_DB" ]] || die "usage: akshara-restore.sh <artifact.dump.enc> <target_db> [--force]"
[[ -f "$ARTIFACT" ]] || die "artifact not found: $ARTIFACT"
[[ -f "$BACKUP_KEY_FILE" ]] || die "encryption key file missing: $BACKUP_KEY_FILE"

require_cmd docker
require_cmd openssl
ensure_pg_up

if [[ "$TARGET_DB" == "$AKSHARA_DB_NAME" && "$FORCE" != "--force" ]]; then
  die "refusing to restore over live DB '$AKSHARA_DB_NAME' without --force"
fi

log "verifying artifact decrypts cleanly..."
# Full decrypt to /dev/null validates the key + padding without a pipe (piping
# into `head` would SIGPIPE openssl and false-fail). Cheap for a DB dump.
openssl enc -d -aes-256-cbc -pbkdf2 -pass "file:$BACKUP_KEY_FILE" -in "$ARTIFACT" -out /dev/null 2>/dev/null \
  || die "artifact failed to decrypt (wrong key or corrupt file)"

# (Re)create target db when it is NOT the live db.
if [[ "$TARGET_DB" != "$AKSHARA_DB_NAME" ]]; then
  log "recreating target db '$TARGET_DB'"
  PG_DB_OVERRIDE=postgres pg -c "DROP DATABASE IF EXISTS \"$TARGET_DB\";"
  PG_DB_OVERRIDE=postgres pg -c "CREATE DATABASE \"$TARGET_DB\";"
fi

log "restoring $ARTIFACT -> $TARGET_DB"
set -o pipefail
openssl enc -d -aes-256-cbc -pbkdf2 -pass "file:$BACKUP_KEY_FILE" -in "$ARTIFACT" \
  | docker exec -i "$AKSHARA_PG_CONTAINER" \
      pg_restore -U "$AKSHARA_DB_USER" -d "$TARGET_DB" --clean --if-exists --no-owner --no-acl \
  || die "pg_restore failed"

log "restore complete into '$TARGET_DB'"
