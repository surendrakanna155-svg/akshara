#!/usr/bin/env bash
# Deploy Akshara API + pending migrations to staging (akshara-staging).
# RC finalization — run before phase5_staging_verify.sh and production_launch_verify.sh
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-oeicxjpewrumkfgyqnnj}"
REPORT_DIR="${REPORT_DIR:-reports/phase5_validation}"
RUN_VERIFY="${RUN_VERIFY:-1}"

mkdir -p "$REPORT_DIR"
LOG="$REPORT_DIR/deploy_staging.log"
: > "$LOG"

log() { echo "[deploy-staging] $*" | tee -a "$LOG"; }

if ! command -v supabase >/dev/null 2>&1; then
  log "FAIL: supabase CLI not installed"
  exit 1
fi

if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ] && ! supabase projects list >/dev/null 2>&1; then
  log "FAIL: Run 'supabase login' or set SUPABASE_ACCESS_TOKEN"
  exit 1
fi

log "Project: $PROJECT_REF"
log "Critical migrations (Phase 5 + storage):"
log "  - 20260622500000_phase5_foundation.sql"
log "  - 20260622600000_phase5_permissions.sql"
log "  - 20260622600001_phase5_probe_seed.sql"
log "  - 20260622700000_v104_storage_foundation.sql"

log "Applying migrations..."
supabase db push --project-ref "$PROJECT_REF" 2>&1 | tee -a "$LOG"

log "Deploying Edge function 'api' (includes Phase 5 routers)..."
supabase functions deploy api --project-ref "$PROJECT_REF" 2>&1 | tee -a "$LOG"

log "Deploy complete."

if [ "$RUN_VERIFY" = "1" ] && [ -x "./scripts/phase5_staging_verify.sh" ]; then
  log "Running phase5_staging_verify.sh..."
  ./scripts/phase5_staging_verify.sh 2>&1 | tee -a "$LOG" || {
    log "WARN: phase5 staging verify failed — see log"
    exit 1
  }
fi

log "Success. Optional: ./scripts/production_launch_verify.sh"
