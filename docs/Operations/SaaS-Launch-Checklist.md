# SaaS Launch Checklist

**Version:** 1.0 (v7.7) — closes Final Production Readiness Audit Priority A items

---

## 1. Database

- [ ] All migrations through `20260615100000_analytics_intelligence.sql` applied
- [ ] Pre-deploy backup snapshot confirmed
- [ ] `erp_tenant` role password matches `ERP_TENANT_DATABASE_URL`

## 2. Edge Functions

- [ ] `api` function deployed to target environment
- [ ] Secrets set per [Production Integrations](./Production-Integrations.md)
- [ ] `INTERNAL_HEALTH_TOKEN` configured (production mandatory)
- [ ] `AUTH_OTP_DEV_MODE=false` in production

## 3. Deploy verification (v7.4–v7.6)

- [ ] `GET /copilot/assistants` → 200 (authenticated)
- [ ] `GET /academic/timetables/summary` → 200 or 400 (route mounted)
- [ ] `GET /analytics/dashboard` → 200 (authenticated)
- [ ] `./scripts/production_launch_verify.sh` — all pass
- [ ] Tenant probes **213/213** via `/health/tenant-access`

## 4. Flutter production build

- [ ] `--dart-define=APP_ENV=production`
- [ ] `--dart-define=ENABLE_API_MODE=true`
- [ ] Per-module API flags enabled (see rollout checklist)
- [ ] `disableDemoAuth` active (production profile)
- [ ] `flutter analyze` = 0 · `flutter test` all pass

## 5. External integrations

- [ ] Razorpay live keys + webhook secret; `RAZORPAY_STUB_MODE=false`
- [ ] Twilio + SendGrid + FCM configured; stub flags false
- [ ] OpenAI key set OR stub fallback documented for pilot

## 6. Security

- [ ] Penetration test scheduled or completed
- [ ] TLS-only API URLs in client build
- [ ] Sensitive health endpoints require internal token
- [ ] Demo OTP paths blocked in production build

## 7. Governance

- [ ] `ProductionReadinessChecklist.md` production column reviewed
- [ ] `TechnicalDebtRegister.md` P0 items closed
- [ ] Pilot runbook updated (213 probes)

## 8. Sign-off

| Role | Approved | Date |
|------|----------|------|
| Release Manager | | |
| Security | | |
| Pilot school lead | | |
