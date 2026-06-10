# Disaster Recovery Checklist

**Version:** 1.0 (v7.7)

---

## Definitions

| Term | Definition |
|------|------------|
| **RPO** | Maximum acceptable data loss — **15 min** (PITR) |
| **RTO** | Maximum acceptable downtime — **2 hours** |

---

## Quarterly DR drill

- [ ] Schedule staging PITR restore to isolated branch
- [ ] Restore to timestamp T-1h
- [ ] Deploy `api` function with staging secrets
- [ ] Run `production_launch_verify.sh` against restored branch
- [ ] Document elapsed time vs RTO
- [ ] Update runbooks with lessons learned

---

## Scenario playbooks

| Scenario | First action | Owner |
|----------|--------------|-------|
| DB corruption | PITR restore | Platform |
| Edge function bad deploy | Redeploy previous git tag | Release Manager |
| Auth outage | JWT still valid 15 min; queue writes | Security |
| Razorpay webhook storm | Disable webhook in dashboard; replay from Razorpay | Finance |
| Tenant probe failure | Block launch; inspect RLS migration | Backend |

---

## Contacts (fill before production)

| Role | Contact |
|------|---------|
| Release Manager | _TBD_ |
| Supabase support | Dashboard ticket |
| Razorpay support | Merchant dashboard |
| Pilot school admin | _TBD_ |

---

## Sign-off

| Item | Date | Initials |
|------|------|----------|
| DR drill completed | | |
| RPO/RTO accepted by stakeholders | | |
| Restore runbook reviewed | | |
