#!/usr/bin/env bash
# v6.4 Sprint 6 — Local validation gate (flutter + deno)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

log() { echo "[sprint6-verify] $*"; }

log "flutter analyze"
flutter analyze

log "Sprint 6 flutter tests"
flutter test \
  test/security/rbac/server_rbac_validation_suite_test.dart \
  test/security/rbac/rbac_validation_suite_test.dart \
  test/security/tenant/tenant_isolation_validation_suite_test.dart \
  test/integration/validation/sprint6_validation_suite_test.dart \
  test/integration/cross_module/cross_module_workflow_integration_test.dart \
  test/integration/audit/audit_api_integration_test.dart \
  test/contracts/openapi/openapi_contract_validation_test.dart \
  test/integration/pilot/pilot_workflow_certification_test.dart

log "Deno validation tests"
cd supabase/functions/_shared
deno test \
  validation/rbac_route_validation_test.ts \
  validation/audit_ingestion_e2e_test.ts \
  audit/audit_repository_test.ts \
  permission_middleware_test.ts

log "Sprint 6 local validation complete"
