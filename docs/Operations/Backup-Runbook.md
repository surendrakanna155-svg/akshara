# Backup Runbook

**Version:** 1.0 (v7.7)  
**Owner:** Platform / Release Manager

---

## Scope

PostgreSQL (Supabase), Edge Function config secrets, R2 file storage (when enabled).

---

## Automated backups (Supabase)

| Asset | Method | Frequency | Retention |
|-------|--------|-----------|-----------|
| PostgreSQL | Supabase PITR + daily snapshot | Continuous WAL | 30 days (plan-dependent) |
| Edge secrets | Supabase vault | On change | Version history in dashboard |

---

## Pre-deploy snapshot (required)

Before every production migration push:

1. Confirm Supabase dashboard → Database → Backups shows recent snapshot
2. Note current migration version: `supabase migration list --linked`
3. Export manual snapshot if major schema change (Copilot, Timetable, Analytics migrations)

---

## Manual export (optional)

```bash
supabase db dump --linked -f backups/pre-v7.7-$(date +%Y%m%d).sql
```

Store dumps in encrypted object storage — never commit to git.

---

## Verification

- [ ] Backup timestamp within 24h of deploy
- [ ] PITR enabled on production project
- [ ] Migration list documented in release notes

See also: [Restore Runbook](./Restore-Runbook.md), [Disaster Recovery Checklist](./Disaster-Recovery-Checklist.md).
