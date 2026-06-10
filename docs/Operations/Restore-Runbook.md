# Restore Runbook

**Version:** 1.0 (v7.7)

---

## When to use

- Failed migration corrupts data
- Accidental tenant-wide DELETE
- Region outage requiring PITR

---

## RPO / RTO targets

| Metric | Target | Notes |
|--------|--------|-------|
| **RPO** (Recovery Point Objective) | **15 minutes** | Supabase PITR granularity |
| **RTO** (Recovery Time Objective) | **2 hours** | Includes validation + DNS cutover |

---

## PITR restore (Supabase)

1. **Stop writes:** Disable API function or set maintenance flag
2. Supabase Dashboard → Database → Backups → **Restore to point in time**
3. Select timestamp **before** incident
4. Restore to **new** branch/project if possible; validate before cutover
5. Re-link Edge Functions secrets (`JWT_SECRET`, `ERP_TENANT_DATABASE_URL`, integration secrets)
6. Run `./scripts/production_launch_verify.sh` with `INTERNAL_HEALTH_TOKEN`
7. Confirm **213/213** tenant probes pass
8. Resume traffic

---

## Migration rollback

If restore is not needed and only schema rollback:

1. Create reverse migration or restore from pre-deploy SQL dump
2. `supabase db push` on rollback branch
3. Redeploy previous Edge Function tag
4. Run launch verify script

---

## Post-restore validation

- [ ] Auth login (staff OTP)
- [ ] Finance dashboard + one collection read
- [ ] Audit batch upload accepted
- [ ] Tenant isolation probes 213/213 pass
- [ ] Pilot school smoke (parent dashboard)

---

## Communication

- Notify pilot school admins within 30 minutes of restore start
- Log incident in audit + post-mortem within 48h
