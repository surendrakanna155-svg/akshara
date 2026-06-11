#!/usr/bin/env bash
# Phase 18 — Staging deployment through v14.0 (School OS Pilot Readiness)
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-oeicxjpewrumkfgyqnnj}"
REPORT_DIR="${REPORT_DIR:-reports/pilot_readiness}"
RUN_VERIFY="${RUN_VERIFY:-1}"

mkdir -p "$REPORT_DIR"
LOG="$REPORT_DIR/deploy_v14.log"
REPORT="$REPORT_DIR/deployment_report.json"
: > "$LOG"

log() { echo "[pilot-deploy-v14] $*" | tee -a "$LOG"; }

DEPLOY_STATUS="blocked"
MIGRATION_STATUS="unknown"
EDGE_STATUS="unknown"
BLOCKERS="[]"

if ! command -v supabase >/dev/null 2>&1; then
  BLOCKERS='["supabase CLI not installed"]'
  log "BLOCKED: supabase CLI missing"
else
  if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ] && ! supabase projects list >/dev/null 2>&1; then
    BLOCKERS='["Run supabase login or set SUPABASE_ACCESS_TOKEN"]'
    log "BLOCKED: not authenticated to Supabase"
  else
    log "Applying migrations through v14.0..."
    if supabase db push --project-ref "$PROJECT_REF" 2>&1 | tee -a "$LOG"; then
      MIGRATION_STATUS="applied"
    else
      MIGRATION_STATUS="failed"
      BLOCKERS='["supabase db push failed — see deploy log"]'
    fi

    log "Deploying Edge function api (v14 routers)..."
    if supabase functions deploy api --project-ref "$PROJECT_REF" 2>&1 | tee -a "$LOG"; then
      EDGE_STATUS="deployed"
      DEPLOY_STATUS="complete"
      BLOCKERS="[]"
    else
      EDGE_STATUS="failed"
      DEPLOY_STATUS="partial"
      BLOCKERS='["supabase functions deploy failed"]'
    fi
  fi
fi

if [ "$RUN_VERIFY" = "1" ] && [ -x "./scripts/pilot_readiness_verify.sh" ]; then
  log "Running pilot_readiness_verify.sh..."
  ./scripts/pilot_readiness_verify.sh 2>&1 | tee -a "$LOG" || true
fi

python3 - <<PY
import json, datetime, os
report = {
  "generatedAt": datetime.datetime.utcnow().isoformat() + "Z",
  "phase": 18,
  "projectRef": os.environ.get("PROJECT_REF", "${PROJECT_REF}"),
  "deployStatus": "${DEPLOY_STATUS}",
  "migrationStatus": "${MIGRATION_STATUS}",
  "edgeStatus": "${EDGE_STATUS}",
  "blockers": json.loads('${BLOCKERS}'),
  "logPath": "${LOG}",
}
with open("${REPORT}", "w") as f:
  json.dump(report, f, indent=2)
print(json.dumps(report, indent=2))
PY

log "Deployment report: $REPORT"
[ "${DEPLOY_STATUS}" = "complete" ] || exit 1
