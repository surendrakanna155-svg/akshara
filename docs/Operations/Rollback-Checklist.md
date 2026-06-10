# Production Rollback Checklist

**Version:** 1.0 (v7.7)

---

## Triggers

- Launch verify script failures post-deploy
- Tenant probe count < 213 or `pass: false`
- Payment webhook creating duplicate collections
- Auth outage affecting all pilot users

---

## Immediate actions (< 15 min)

1. **Announce** maintenance to pilot users
2. **Redeploy** previous known-good Edge Function version:
   ```bash
   git checkout <previous-tag>
   supabase functions deploy api --no-verify-jwt
   ```
3. If schema-related: **stop** further migrations; do not run `db push`

---

## Database rollback

| Severity | Action |
|----------|--------|
| Data corruption | PITR restore — see [Restore Runbook](./Restore-Runbook.md) |
| Migration-only issue | Restore pre-deploy SQL dump or forward-fix migration |

---

## Client rollback

1. Redeploy previous Flutter web build artifact from CI/CD or tagged release
2. Confirm production build still points at rolled-back API URL

---

## Validation after rollback

- [ ] `/health/ready` → 200
- [ ] Staff login works
- [ ] Core dashboards load
- [ ] Document incident + root cause within 48h

---

## Do not rollback if

- Issue is external provider only (Twilio/Razorpay) — disable integration flag instead
- Fix is forward-compatible hotfix ready within 1 hour
