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

## Stage 4 — lean runtime LIVE (verified)
Stack on akshara-net (localhost-only): akshara-postgres + akshara-postgrest +
akshara-rest-gateway (nginx) + akshara-edge (Deno `functions/api`). NestJS scaffold removed.
- Edge: denoland/deno:alpine, `run -A --no-lock api/index.ts`, Deno.serve :8000 -> host 127.0.0.1:3000.
- PostgREST connects as `authenticator`; gateway maps /rest/v1/* -> postgrest:3000.
- Keys: HS256 service_role/anon JWTs signed with PGRST_JWT_SECRET; app JWT_SECRET separate.
- Migration ledger backfilled (98 rows). authenticator + erp_tenant passwords set.
- Verified: /health ok; /health/ready database:true; PostgREST returns seeded org;
  auth login(dev OTP)->verify-otp->/auth/me (schoolAdmin, tenant scoped); /auth/permissions 200;
  GET /sis/students returns staging student via erp_tenant RLS; no-token -> 401.
- Host-exposed: ONLY 127.0.0.1:3000 (edge) + 127.0.0.1:5433 (pg). Nothing public.
- NOT done: public exposure (Nginx vhost + subdomain + SSL) — deferred, needs DNS + email.
