# Akshara VPS deployment (lean self-host Supabase) — checkpoint

Host: 46.28.44.46 (Ubuntu 24.04). Everything Akshara-namespaced, localhost-only,
isolated from Velora / n8n / MySQL / Redis (all untouched).

## Stage 1 — migration validation (local)
- `supabase start` dry-run: all 98 migrations apply cleanly (155 tables).
- Fixes (committed): re-ordered academic_foundation before pilot_operations;
  added 20260607000000_storage_stub.sql (guarded no-op when real Storage exists).
- Supabase deps: pgcrypto (ext), service_role (image role), storage schema
  (stubbed for lean), erp_tenant + app.* (self-created in migrations).

## Stage 2 — Postgres on Supabase image (VPS)
- akshara-postgres = public.ecr.aws/supabase/postgres:17.6.1.127 (PG 17.6).
- DB akshara_db; roles service_role/anon/authenticated/supabase_admin present.
- 127.0.0.1:5433 only.

## Stage 3 — migrations applied (VPS)
- Applied 98/98 as supabase_admin (superuser; `postgres` is non-super in this image).
- 155 tables, 137 RLS-enabled, 150 policies, erp_tenant + app.set_request_context present.
- Storage stub create-path validated on bare PG.

## Stage 4 (next) — lean runtime
- Retire NestJS scaffold; deploy Deno edge (functions/api) + PostgREST + nginx
  rest-gateway; backfill supabase_migrations ledger; mint JWT/service_role/anon keys.
