#!/usr/bin/env bash
# Phase 21 v15.1 — Staging deployment completion + full route verification
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-oeicxjpewrumkfgyqnnj}"
REPORT_DIR="${REPORT_DIR:-reports/phase21}"
mkdir -p "$REPORT_DIR"
LOG="$REPORT_DIR/deploy.log"
REPORT="$REPORT_DIR/deployment_report.json"

: > "$LOG"
log() { echo "[phase21-deploy] $*" | tee -a "$LOG"; }

DEPLOY_STATUS="blocked"
BLOCKERS='["Run supabase login or set SUPABASE_ACCESS_TOKEN"]'

if command -v supabase >/dev/null 2>&1; then
  if [ -n "${SUPABASE_ACCESS_TOKEN:-}" ] || supabase projects list >/dev/null 2>&1; then
    log "Applying migrations..."
    if supabase db push --project-ref "$PROJECT_REF" 2>&1 | tee -a "$LOG"; then
      log "Deploying Edge api..."
      if supabase functions deploy api --project-ref "$PROJECT_REF" 2>&1 | tee -a "$LOG"; then
        DEPLOY_STATUS="complete"
        BLOCKERS="[]"
      else
        DEPLOY_STATUS="partial"
        BLOCKERS='["functions deploy failed"]'
      fi
    else
      DEPLOY_STATUS="partial"
      BLOCKERS='["db push failed"]'
    fi
  fi
fi

if [ -x "./scripts/pilot_readiness_verify.sh" ]; then
  log "Running readiness verification..."
  RUN_VERIFY=1 bash ./scripts/pilot_readiness_verify.sh 2>&1 | tee -a "$LOG" || true
fi

python3 - <<PY
import json, datetime, os
report = {
  "generatedAt": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
  "phase": 21,
  "deployStatus": "${DEPLOY_STATUS}",
  "blockers": json.loads('${BLOCKERS}'),
  "logPath": "${LOG}",
}
with open("${REPORT}", "w") as f:
  json.dump(report, f, indent=2)
print(json.dumps(report, indent=2))
PY

log "Report: $REPORT"
[ "${DEPLOY_STATUS}" = "complete" ] || exit 1
