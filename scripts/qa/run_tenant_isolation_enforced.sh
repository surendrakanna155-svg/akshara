#!/usr/bin/env bash
# Track B (B5/B7) — run the enforced tenant-isolation test (233 probes) against
# the dedicated tenant-validation database `akshara_tenant_test` via
# ERP_TENANT_DATABASE_URL, using a direct non-bypass `erp_tenant` connection with
# RLS enforced (the same suite the live /health/tenant-access self-check runs).
#
# Design notes:
#   * ERP_TENANT_DATABASE_URL is provided ONLY to this harness — it points at
#     `akshara_tenant_test`, NOT the edge runtime env. The edge's own
#     ERP_TENANT_DATABASE_URL stays `akshara_db` (real attendance/exam/promotion
#     RLS queries depend on it); repointing it would break the live app.
#   * Secret-free: the `erp_tenant` password is read from the VPS
#     `/opt/akshara/.env.akshara` at runtime and never leaves the VPS or prints.
#   * Runs inside the `akshara-edge` container (has Deno + the mounted functions +
#     network to `akshara-postgres`), so no local tunnel or local secret is needed.
#
# Requires: the owner's SSH ControlMaster (Host akshara). See docs/FINAL_QA_ROADMAP.md Phase B.
#
# To (re)provision akshara_tenant_test as an isolated clone of akshara_db:
#   ssh akshara 'docker exec -u postgres akshara-postgres psql -d postgres -c "CREATE DATABASE akshara_tenant_test;"'
#   ssh akshara 'docker exec -u postgres akshara-postgres psql -d postgres -c "GRANT CONNECT ON DATABASE akshara_tenant_test TO erp_tenant;"'
#   ssh akshara 'docker exec -u postgres akshara-postgres bash -c "pg_dump -d akshara_db | psql -q -d akshara_tenant_test"'
# (the ~421 "SET ROLE supabase_admin/pgbouncer" errors are benign auth/storage-schema
#  ownership lines; the public schema + RLS + probe fixtures clone completely.)
set -euo pipefail

SSH_HOST="${AKSHARA_SSH_HOST:-akshara}"
TENANT_DB="${AKSHARA_TENANT_DB:-akshara_tenant_test}"

echo "[tenant-isolation] running enforced 233-probe suite against ${TENANT_DB} (erp_tenant, RLS enforced)…"
ssh "$SSH_HOST" "URL=\$(grep -E '^ERP_TENANT_DATABASE_URL=' /opt/akshara/.env.akshara | cut -d= -f2- | sed 's#/akshara_db#/${TENANT_DB}#'); \
  docker exec -e ERP_TENANT_DATABASE_URL=\"\$URL\" akshara-edge deno test --allow-all --no-lock /app/_shared/tenant_isolation_enforced_test.ts"
