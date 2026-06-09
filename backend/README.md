# Akshara ERP — Backend (Supabase)

v6.0 Sprint 2 core platform: organizations, schools, users, memberships, and auth.

## Structure

```
supabase/
  migrations/          PostgreSQL schema + staging seed
  functions/
    api/               Edge Function router (/v1 paths via /functions/v1/api/*)
    _shared/           Auth, JWT, permissions, HTTP helpers
openapi/
  akshara-v1.yaml      Health + auth OpenAPI v1
backend/
  .env.example         Environment template (no secrets)
```

## Local setup

1. Install [Supabase CLI](https://supabase.com/docs/guides/cli) and [Deno](https://deno.land/).
2. Copy `backend/.env.example` → `backend/.env.local` and fill values from `supabase start`.
3. Start stack:

```bash
supabase start
supabase db reset
```

4. Serve API:

```bash
set -a && source backend/.env.local && set +a
supabase functions serve api --env-file backend/.env.local --no-verify-jwt
```

5. Base URL for Flutter:

```
http://127.0.0.1:54321/functions/v1/api
```

Run app with:

```bash
flutter run --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=http://127.0.0.1:54321/functions/v1/api --dart-define=ENABLE_API_MODE=true
```

## Staging OTP test user

| Field | Value |
|-------|-------|
| Phone | `+919876543210` or `9876543210` |
| OTP | Returned in login response when `AUTH_OTP_DEV_MODE=true` |
| Role | `schoolAdmin` |

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Liveness |
| GET | `/health/ready` | DB readiness |
| POST | `/auth/login` | Send OTP |
| POST | `/auth/verify-otp` | Verify OTP + tokens |
| POST | `/auth/refresh` | Refresh rotation |
| POST | `/auth/logout` | Logout session |
| POST | `/auth/sessions/logout-all` | Logout all |
| POST | `/auth/sessions/revoke` | Revoke session |
| GET | `/auth/me` | Current user |
| GET | `/auth/permissions` | Permissions |
| GET | `/health/tenant-access` | RLS-enforced isolation probe (Phase 3A) |

## Configuration rules

- No project IDs, URLs, API keys, or SMS credentials in source code.
- All secrets via environment variables / CI secrets.
- `JWT_SECRET` minimum 32 characters.
- `ERP_TENANT_DATABASE_URL` — non-bypass `erp_tenant` Postgres URL for module queries (TD-P0-01).
- Production requires SMS provider env vars; staging uses `AUTH_OTP_DEV_MODE`.

## Tests

```bash
deno test --allow-env supabase/functions/_shared/auth_unit_test.ts
```

## Staging deployment

GitHub Actions workflow `.github/workflows/backend_staging.yml` deploys migrations and the `api` function when `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_ID_STAGING`, and `JWT_SECRET` are configured in repository secrets.
