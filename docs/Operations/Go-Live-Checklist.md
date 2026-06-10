# Go-Live Checklist

**Version:** 1.0 (v1.0-rc1)  
**Scope:** Limited production pilot cutover — no new features  
**Prerequisite:** [`v1.0-Release-Candidate.md`](../Releases/v1.0-Release-Candidate.md) validated on staging

---

## 1. Production secrets

Complete before any pilot user access. Reference: [`Production-Integrations.md`](./Production-Integrations.md)

### Database & platform

- [ ] `ERP_TENANT_DATABASE_URL` — production Postgres pooler URL for `erp_tenant`
- [ ] `JWT_SECRET` — unique production secret (not staging value)
- [ ] `INTERNAL_HEALTH_TOKEN` — random high-entropy token for health endpoints
- [ ] Supabase project linked to production (not staging ref)

### Auth

- [ ] `AUTH_OTP_DEV_MODE=false`
- [ ] SMS provider credentials configured (Twilio or equivalent)
- [ ] Demo/mock OTP paths blocked in production Flutter build (`disableDemoAuth`)

### Payments (if pilot collects fees online)

- [ ] `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`
- [ ] `RAZORPAY_STUB_MODE=false`
- [ ] Webhook URL registered: `https://<project>.supabase.co/functions/v1/api/webhooks/razorpay`
- [ ] Test payment → webhook → finance collection verified

### Communication

- [ ] `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM_NUMBER`
- [ ] `SENDGRID_API_KEY`, `SENDGRID_FROM_EMAIL`
- [ ] `FCM_SERVER_KEY` (if push enabled)
- [ ] `SMS_STUB_MODE=false`, `EMAIL_STUB_MODE=false`, `FCM_STUB_MODE=false`

### AI Copilot (optional)

- [ ] `OPENAI_API_KEY` set **or** stub mode documented and accepted for pilot
- [ ] `OPENAI_MODEL` override reviewed (default `gpt-4o-mini`)

---

## 2. OTP verification

- [ ] Admin staff phone receives real SMS OTP (not dev code in response body)
- [ ] Parent phone login → OTP → `/parent/dashboard` 200
- [ ] Teacher phone login → OTP → `/teacher/dashboard` 200
- [ ] Student ID login (if enabled) → OTP → `/student/dashboard` 200
- [ ] Invalid OTP rejected with clear error
- [ ] Expired session refresh works (`/auth/refresh`)
- [ ] Logout revokes session

**Smoke command:**

```bash
API_BASE_URL=https://<prod>/functions/v1/api bash scripts/pilot_staging_verify.sh
```

---

## 3. Payment verification

Skip if pilot is fees-offline only; otherwise:

- [ ] Create payment intent from parent mobile or ERP
- [ ] Complete Razorpay test/live payment
- [ ] Webhook signature validated (reject invalid signature → 401/403)
- [ ] `finance_collections` row created with matching amount
- [ ] Invoice status transitions (`issued` → `partially_paid` / `paid`)
- [ ] No duplicate collections on webhook replay
- [ ] Refund approve/reject path tested on one sample collection

---

## 4. Communication verification

- [ ] Send broadcast to `all_teachers` — HTTP 201
- [ ] Send broadcast to `all_parents` — HTTP 201 (allow retry on transient 502)
- [ ] `POST /communications/notifications/process-queue` — deliveries marked sent
- [ ] Parent receives notification in `/parent/notifications`
- [ ] Teacher → parent message thread created and visible to parent
- [ ] Delivery records show provider ref (not `stub_*`) when live keys set
- [ ] Audit events: `broadcastSent`, `notificationBatchProcessed`

---

## 5. Backup verification

Reference: [`Backup-Runbook.md`](./Backup-Runbook.md), [`Restore-Runbook.md`](./Restore-Runbook.md)

- [ ] Automated daily backup enabled (Supabase PITR or scheduled dump)
- [ ] Pre-go-live manual snapshot taken and labeled (`v1.0-rc1-pre-go-live`)
- [ ] Restore drill completed on non-prod clone within RTO target (2 h)
- [ ] RPO documented (15 min with PITR)
- [ ] Rollback tag identified: `v1.0-pilot-ready` or prior stable tag

---

## 6. Health checks

- [ ] `GET /health/ready` → 200
- [ ] `GET /health/tenant-access` with `x-internal-health-token` → 200, **213/213 probes pass**
- [ ] `GET /health/operations` with internal token → `status: ok`
- [ ] Public access to tenant-access **without** token → 403 (production mandatory)
- [ ] Core dashboards: admissions, finance, SIS → 200 (admin JWT)
- [ ] v7.4 Copilot assistants → 200
- [ ] v7.5 Timetable summary (with `academicYearId`) → 200
- [ ] v7.6 Analytics dashboard → 200

**Launch verify:**

```bash
export API_BASE_URL=https://<prod>/functions/v1/api
export INTERNAL_HEALTH_TOKEN=<secret>
export EXPECTED_PROBE_COUNT=213
export ACADEMIC_YEAR_ID=<current-year-uuid>   # optional
./scripts/production_launch_verify.sh
```

---

## 7. Smoke tests

### Automated (required)

- [ ] `./scripts/production_launch_verify.sh` — all pass
- [ ] `./scripts/pilot_staging_verify.sh` — all pass
- [ ] `python3 scripts/demo_school_validate.py` — 31/31 (against pilot school or `--skip-seed-check`)

### Manual pilot school (recommended)

- [ ] Onboard 1 teacher + 1 student via CSV import
- [ ] Mark attendance for one class
- [ ] Assign fee structure + verify invoice visible to parent
- [ ] Generate timetable for one section
- [ ] Run one Copilot finance query
- [ ] View analytics dashboard

### Multi-tenant isolation

- [ ] School A admin cannot read School B probe student (404/403)
- [ ] Parent scoped to School A cannot read School B data

---

## 8. Deployment artifacts

- [ ] Git tag `v1.0-rc1` deployed (or production tag after GA)
- [ ] Migrations through `20260615110000_onboarding_user_provisioning_fix.sql` applied
- [ ] Edge Function `api` deployed
- [ ] Flutter web/mobile build artifact version recorded in release notes
- [ ] [`Pilot-Issue-Tracker.md`](./Pilot-Issue-Tracker.md) — 0 open issues

---

## 9. Rollback readiness

- [ ] [`Rollback-Checklist.md`](./Rollback-Checklist.md) reviewed with on-call owner
- [ ] Previous function bundle tag documented
- [ ] Incident communication template ready

---

## 10. Sign-off

| Role | Name | Approved | Date |
|------|------|:--------:|------|
| Release Manager | | ☐ | |
| Backend / API | | ☐ | |
| Security | | ☐ | |
| Pilot school lead | | ☐ | |

**Go-live decision:**

- [ ] **Approved** — limited production pilot may proceed
- [ ] **Blocked** — list blockers in Pilot Issue Tracker

---

## Quick reference

| Task | Script / doc |
|------|----------------|
| Full validation orchestrator | `python3 scripts/production_validation.py` |
| Demo school E2E | `python3 scripts/demo_school_validate.py` |
| Launch gate | `./scripts/production_launch_verify.sh` |
| Pilot gate | `./scripts/pilot_staging_verify.sh` |
| RC release notes | `docs/Releases/v1.0-Release-Candidate.md` |
| Validation evidence | `docs/Operations/Production-Validation-Report.md` |
