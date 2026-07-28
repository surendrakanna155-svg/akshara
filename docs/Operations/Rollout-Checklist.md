# Production Rollout Checklist

**Version:** 1.0 (v7.7)

Roll out **one pilot tenant** before multi-tenant production.

---

## Phase A — Staging validation

1. Push migrations + deploy `api`
2. Set staging secrets (stub externals acceptable)
3. Run `./scripts/production_launch_verify.sh`
4. Run `./scripts/pilot_staging_verify.sh` (with `INTERNAL_HEALTH_TOKEN` if set)

---

## Phase B — Pilot tenant (single school)

### Backend

- [ ] Production Supabase project linked
- [ ] All v7.7 secrets configured
- [ ] Domain events worker scheduled (`POST /domain-events/process-pending`)
      ⚠️ **This drain currently delivers nothing to subscribers**, because every
      event is inserted in terminal `status='published'` while the drain selects
      `pending|failed`, and the subscriber registry is empty. Schedule it anyway:
      it is the ONLY caller of the Signal Refinery, so without it AI cache
      invalidation and fact-freshness never run. Do not expect cross-module
      propagation from it. See docs/engineering/DOMAIN_EVENTS_ARCHITECTURE.md.

### Flutter web build

```bash
flutter build web \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://<project>.supabase.co/functions/v1/api \
  --dart-define=ENABLE_API_MODE=true \
  --dart-define=ADMISSIONS_API_ENABLED=true \
  --dart-define=FINANCE_API_ENABLED=true \
  --dart-define=SIS_API_ENABLED=true \
  --dart-define=ACADEMIC_API_ENABLED=true \
  --dart-define=ACADEMIC_TIMETABLE_API_ENABLED=true \
  --dart-define=ANALYTICS_INTELLIGENCE_API_ENABLED=true \
  --dart-define=AI_COPILOT_ENABLED=true \
  --dart-define=PAYMENT_API_ENABLED=true \
  --dart-define=COMMUNICATION_API_ENABLED=true \
  --dart-define=AUDIT_API_ENABLED=true \
  --dart-define=ONBOARDING_API_ENABLED=true \
  --dart-define=PARENT_API_ENABLED=true \
  --dart-define=TEACHER_API_ENABLED=true \
  --dart-define=STUDENT_API_ENABLED=true \
  --dart-define=INVENTORY_FINANCE_API_ENABLED=true
```

### Pilot smoke (48h)

- [ ] Staff login via live OTP
- [ ] Admissions → enrollment → SIS student visible
- [ ] Fee collection or Razorpay test payment
- [ ] Parent mobile dashboard
- [ ] Copilot assistant session (stub or live)
- [ ] Analytics intelligence hub loads

---

## Phase C — Expand tenants

- [ ] Enable feature flags per tenant in rollout tracker
- [ ] Monitor audit ingestion. **Do not use the domain-event backlog as a health
      signal** — it counts rows in `pending|failed`, which is structurally always
      zero, so it can never go red and will be mistaken for evidence of health.
- [ ] Weekly tenant probe job via internal health endpoint
