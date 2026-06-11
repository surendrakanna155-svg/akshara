# Akshara ERP — Deployment Guide

**Version:** RC (v10.4.2)  
**Last updated:** June 2026

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| Supabase CLI | `supabase --version` ≥ 2.x |
| Access token | `supabase login` or `SUPABASE_ACCESS_TOKEN` |
| Project ref | Staging: `oeicxjpewrumkfgyqnnj` (`akshara-staging`) |

---

## Environment Variables

### Supabase deploy

| Variable | Required | Purpose |
|----------|----------|---------|
| `SUPABASE_ACCESS_TOKEN` | Yes (CI) | CLI authentication |
| `SUPABASE_PROJECT_REF` | No | Defaults to staging ref |
| `INTERNAL_HEALTH_TOKEN` | Prod recommended | Locks `/health/tenant-access` |

### Flutter client (dart-define)

| Flag | Purpose |
|------|---------|
| `APP_ENV` | `development` \| `staging` \| `production` |
| `API_BASE_URL` | Override API base (include `/functions/v1/api` path for Supabase) |
| `ENABLE_API_MODE=true` | Master API switch |
| `PHASE5_API_ENABLED=true` | Parent hub, operations, memories, promotion |
| `PARENT_API_ENABLED=true` | Parent mobile module |
| `ONBOARDING_API_ENABLED=true` | CSV import / invites |
| Per-module flags | See `lib/core/repositories/repository_config.dart` |

**Staging example:**

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api \
  --dart-define=ENABLE_API_MODE=true \
  --dart-define=PHASE5_API_ENABLED=true \
  --dart-define=PARENT_API_ENABLED=true
```

---

## Migration Order (Phase 5 critical path)

Apply via `supabase db push` — migrations are timestamp-ordered:

1. `20260622500000_phase5_foundation.sql`
2. `20260622600000_phase5_permissions.sql`
3. `20260622600001_phase5_probe_seed.sql`
4. `20260622700000_v104_storage_foundation.sql`

Full history: `supabase/migrations/` (58 files as of v10.4.2).

---

## Staging Deploy

```bash
export SUPABASE_ACCESS_TOKEN=...
./scripts/deploy_staging.sh
```

This runs `db push`, deploys Edge `api`, then `phase5_staging_verify.sh`.

**Route probe:** Deployed routes return **401** without auth; missing routes return **404**.

---

## Production Verification

```bash
export API_BASE_URL=https://<prod>/functions/v1/api
export INTERNAL_HEALTH_TOKEN=...
./scripts/production_launch_verify.sh
```

Includes tenant isolation probes (213), core ERP dashboards, and Phase 5 route checks when deployed.

---

## Rollback

See [Rollback-Checklist.md](./Rollback-Checklist.md).

1. Redeploy previous Edge bundle: `git checkout <tag> && supabase functions deploy api`
2. Do **not** run forward migrations if schema is the issue
3. PITR restore for data corruption — [Restore-Runbook.md](./Restore-Runbook.md)

---

## Verification Scripts

| Script | Purpose |
|--------|---------|
| `scripts/deploy_staging.sh` | Deploy + Phase 5 verify |
| `scripts/phase5_staging_verify.sh` | Phase 5 smoke (exit 2 = deploy blocked) |
| `scripts/production_launch_verify.sh` | Full launch gate |
| `scripts/sis_staging_verify.sh` | SIS-specific |
| `scripts/pilot_staging_verify.sh` | Pilot operations |

---

## Related

- [Go-Live-Checklist.md](./Go-Live-Checklist.md)
- [RealSchoolValidation.md](../Releases/RealSchoolValidation.md)
- [RC-Readiness-Review.md](../ArchitectureReview/RC-Readiness-Review.md)
