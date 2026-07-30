#!/usr/bin/env bash
# Akshara / NIKSHA OS — data-retention purge (EXPLICITLY INVOKED ONLY).
#
# Usage:
#   ./akshara-retention-purge.sh audit    [--days N] [--org UUID] [--force]
#   ./akshara-retention-purge.sh ai-cache [--org UUID] [--force]
#   ./akshara-retention-purge.sh otp      [--days N] [--force]   (default 7 days)
#
# WITHOUT --force this is a DRY RUN: it reports exactly how many rows WOULD be
# removed and changes nothing. Only --force deletes. This mirrors the guard in
# akshara-restore.sh, which refuses to overwrite the live DB without --force.
#
# WHY THIS IS NOT A CRON JOB
# --------------------------
# `audit_events` is an APPEND-ONLY legal/forensic record — the thing a school
# relies on to answer "who changed this mark, who deleted this payment", and the
# thing that evidences consent under the DPDP Act. Scheduled, unattended
# destruction of that record is not appropriate: a bug in a cron entry silently
# and irreversibly destroys the evidence trail, and nothing is left to prove it
# happened. So retention is enforced by a human running THIS script on purpose,
# after sizing the purge (GET /audit/retention, permission `viewManagement`).
#
# install-ops-cron.sh deliberately does NOT schedule this script. If you are
# about to add it to cron: don't. Change the published policy first
# (docs/legal/DATA_RETENTION_AND_DELETION_POLICY.md), because the policy states
# purging is manual and the two must not drift apart again.
#
# This runs as the DB superuser inside the postgres container, which is required
# and intentional: `audit_events` is FORCE ROW LEVEL SECURITY, so a cross-tenant
# purge cannot run from the tenant (`erp_tenant`) role. There is deliberately no
# client-reachable delete path for audit rows.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-common.sh"

TARGET="${1:-}"
shift || true

DAYS=""
ORG=""
FORCE=""
OTP_DAYS_SET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    # Explicit value checks: without them a bare `--days` makes `shift 2` fail
    # under `set -e`, and the operator gets a silent exit 1 from a tool whose
    # other mode deletes records. Fail loudly instead.
    --days)
      [[ -n "${2:-}" ]] || die "--days requires a value"
      DAYS="$2"; OTP_DAYS_SET=1; shift 2 ;;
    --org)
      [[ -n "${2:-}" ]] || die "--org requires a value"
      ORG="$2"; shift 2 ;;
    --force) FORCE="--force"; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

usage() {
  die "usage: akshara-retention-purge.sh <audit|ai-cache|otp> [--days N] [--org UUID] [--force]"
}

[[ -n "$TARGET" ]] || usage

# --- validate input BEFORE touching docker/postgres, so bad arguments fail fast
# and identically on any host.

case "$TARGET" in
  audit|ai-cache|otp) ;;
  *) usage ;;
esac

# otp_requests has no organization_id column (it is a pre-authentication table
# keyed by phone), so a tenant filter is meaningless there — reject it loudly
# rather than silently ignoring the operator's intent.
if [[ "$TARGET" == "otp" && -n "$ORG" ]]; then
  die "--org is not supported for 'otp' (otp_requests is not tenant-scoped)"
fi

# Audit horizon: --days wins, else AUDIT_RETENTION_DAYS from the environment /
# backup.env, else 730 (2 years) — the same default as the API config so the
# script and the service cannot disagree about the horizon.
: "${AUDIT_RETENTION_DAYS:=730}"
[[ -n "$DAYS" ]] || DAYS="$AUDIT_RETENTION_DAYS"

if [[ "$TARGET" == "audit" ]]; then
  [[ "$DAYS" =~ ^[0-9]+$ && "$DAYS" -gt 0 ]] \
    || die "--days must be a positive integer, got: $DAYS"
fi

# OTP rows are purged on their own short horizon, independent of the audit one.
# Floor of 1 day: OTP send is rate-limited on a sliding window over created_at
# (OTP_RATE_WINDOW_SECONDS, default 3600 = 1 hour), so anything at least a day
# old is far outside that window and cannot weaken rate limiting.
if [[ "$TARGET" == "otp" ]]; then
  [[ -n "$OTP_DAYS_SET" ]] || DAYS=7
  [[ "$DAYS" =~ ^[0-9]+$ && "$DAYS" -ge 1 ]] \
    || die "--days for 'otp' must be an integer >= 1 (rate-limit safety floor), got: $DAYS"
fi

# Org filter is optional; when absent the purge spans every tenant.
ORG_PRED=""
if [[ -n "$ORG" ]]; then
  [[ "$ORG" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] \
    || die "--org must be a UUID, got: $ORG"
  ORG_PRED="AND organization_id = '$(sql_str "$ORG")'::uuid"
fi

require_cmd docker
ensure_pg_up

mkdir -p "$LOG_DIR"
PURGE_LOG="$LOG_DIR/retention.log"

case "$TARGET" in
  audit)
    WHERE="created_at < timezone('utc', now()) - interval '$DAYS days' $ORG_PRED"

    CANDIDATES="$(pg -c "SELECT count(*) FROM audit_events WHERE $WHERE;")"
    TOTAL="$(pg -c "SELECT count(*) FROM audit_events WHERE true $ORG_PRED;")"
    log "audit_events: $CANDIDATES of $TOTAL row(s) are older than $DAYS days${ORG:+ (org $ORG)}"

    if [[ "$FORCE" != "--force" ]]; then
      log "DRY RUN — nothing deleted. Re-run with --force to purge those $CANDIDATES row(s)."
      exit 0
    fi

    [[ "$CANDIDATES" -gt 0 ]] || { log "nothing to purge"; exit 0; }

    log "PURGING $CANDIDATES audit_events row(s) older than $DAYS days — irreversible"
    DELETED="$(pg -c "WITH gone AS (DELETE FROM audit_events WHERE $WHERE RETURNING 1) SELECT count(*) FROM gone;")"
    log "purged $DELETED audit_events row(s)"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] audit purge: days=$DAYS org=${ORG:-ALL} deleted=$DELETED by=${SUDO_USER:-$(id -un)}" \
      >> "$PURGE_LOG"
    ;;

  ai-cache)
    # Expired AI cache rows are already invisible to the application: the read
    # path filters `expires_at > now()`, so these rows can never be served
    # again. They are dead weight that still contains generated text about real
    # people, so removing them is pure data minimisation with no behavioural
    # change. Rows with expires_at IS NULL have no TTL and are NOT touched here.
    WHERE="expires_at IS NOT NULL AND expires_at < timezone('utc', now()) $ORG_PRED"

    CANDIDATES="$(pg -c "SELECT count(*) FROM ai_response_cache WHERE $WHERE;")"
    log "ai_response_cache: $CANDIDATES expired row(s)${ORG:+ (org $ORG)}"

    if [[ "$FORCE" != "--force" ]]; then
      log "DRY RUN — nothing deleted. Re-run with --force to purge those $CANDIDATES row(s)."
      exit 0
    fi

    [[ "$CANDIDATES" -gt 0 ]] || { log "nothing to purge"; exit 0; }

    DELETED="$(pg -c "WITH gone AS (DELETE FROM ai_response_cache WHERE $WHERE RETURNING 1) SELECT count(*) FROM gone;")"
    log "purged $DELETED expired ai_response_cache row(s)"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ai-cache purge: org=${ORG:-ALL} deleted=$DELETED by=${SUDO_USER:-$(id -un)}" \
      >> "$PURGE_LOG"
    ;;

  otp)
    # otp_requests stores a phone number + an OTP hash per login attempt. The
    # CODE stops working within minutes (expires_at is checked on verify), but
    # nothing ever removed the ROW — so phone numbers accumulated indefinitely
    # in a pre-authentication table. Deleting rows that are BOTH expired and at
    # least --days old cannot affect any live login (the code is already dead)
    # nor OTP rate limiting (a 1-hour sliding window by default).
    WHERE="expires_at < timezone('utc', now())
           AND created_at < timezone('utc', now()) - interval '$DAYS days'"

    CANDIDATES="$(pg -c "SELECT count(*) FROM otp_requests WHERE $WHERE;")"
    TOTAL="$(pg -c "SELECT count(*) FROM otp_requests;")"
    log "otp_requests: $CANDIDATES of $TOTAL row(s) are expired and older than $DAYS day(s)"

    if [[ "$FORCE" != "--force" ]]; then
      log "DRY RUN — nothing deleted. Re-run with --force to purge those $CANDIDATES row(s)."
      exit 0
    fi

    [[ "$CANDIDATES" -gt 0 ]] || { log "nothing to purge"; exit 0; }

    DELETED="$(pg -c "WITH gone AS (DELETE FROM otp_requests WHERE $WHERE RETURNING 1) SELECT count(*) FROM gone;")"
    log "purged $DELETED expired otp_requests row(s)"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] otp purge: days=$DAYS deleted=$DELETED by=${SUDO_USER:-$(id -un)}" \
      >> "$PURGE_LOG"
    ;;

  *)
    usage
    ;;
esac
