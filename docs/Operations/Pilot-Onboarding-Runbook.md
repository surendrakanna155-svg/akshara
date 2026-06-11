# Pilot Onboarding Runbook

**Version:** 2.1 (v1.0-rc1)

## Pre-flight

1. Confirm staging: `./scripts/pilot_staging_verify.sh` (13+ checks)
2. Confirm tenant probes: `GET /health/tenant-access` with header `x-internal-health-token: $INTERNAL_HEALTH_TOKEN` — expect **213/213** pass
3. Confirm ops snapshot: `GET /health/operations` (same internal token header)
4. Optional full launch gate: `./scripts/production_launch_verify.sh`
5. Complete [`School-Setup-Checklist.md`](./School-Setup-Checklist.md) for first real school

## Import templates

| Asset | Path |
|-------|------|
| Student CSV | [`templates/student_import_template.csv`](./templates/student_import_template.csv) |
| Teacher CSV | [`templates/teacher_import_template.csv`](./templates/teacher_import_template.csv) |
| Parent / secondary guardian | [`templates/parent_guardian_guide.md`](./templates/parent_guardian_guide.md) (no parent-only CSV) |

**Batch size:** ≤ **50 rows** per import job to avoid Edge Function timeouts. Refresh auth token between large batch runs (`demo_school_seed.py --post-import-only` pattern).

## School data import

1. Open ERP → SIS → **School Onboarding** (`/sis/onboarding`)
2. **Teachers first** (principal + staff): upload CSV → preview → commit
3. **Student import:** upload CSV → preview → commit (requires academic catalog labels to match)
4. **Rollback** (if bad commit): `POST /onboarding/imports/:id/rollback` — **student jobs only** for automated cleanup; teacher rollback marks job `rolled_back` but does **not** revoke memberships (manual ops if needed). No 24-hour API limit — ops policy may still prefer same-day rollback.

## Invitations

1. Create invite per parent/teacher (`POST /onboarding/invites`)
2. Share WhatsApp deep-link from response
3. Parent logs in via phone OTP; student via Student ID + OTP (requires `students.user_id`)

## Inventory–Finance (optional pilot)

1. Create vendor → create PO → approve (posts AP commitment)
2. Receive goods → verify stock valuation at `GET /inventory/stock/valuation`

## v7.4–v7.6 smoke (post-deploy)

| Module | Check |
|--------|-------|
| AI Copilot | `GET /copilot/assistants` → 200 |
| Smart Timetable | `GET /academic/timetables/summary?academicYearId=` → 200 |
| Analytics | `GET /analytics/dashboard` → 200 |

## Smoke checks

- Parent dashboard 200
- Finance dashboard 200
- Audit batch accepted
- Payment webhook resolves tenant (staging order_id required)

## Escalation

- Tenant probe failure → check RLS migration applied; expect **213** probes
- Webhook 404 → verify `payment_intents.gateway_order_id` populated
- Domain events stuck → `POST /domain-events/process-pending`
- Health 403 → set `INTERNAL_HEALTH_TOKEN` on Edge Function + pass header in scripts

See also: [Customer Readiness Report](./Customer-Readiness-Report.md), [Real-School Onboarding Guide](./guides/Real-School-Onboarding-Guide.md), [School Admin Quick-Start](./guides/School-Admin-Quick-Start.md), [School Setup Checklist](./School-Setup-Checklist.md), [First-Day Go-Live](./First-Day-Go-Live-Checklist.md), [Operational Readiness Report](./Operational-Readiness-Report.md), [Demo School Validation Plan](./Demo-School-Validation-Plan.md), [Pilot Issue Tracker](./Pilot-Issue-Tracker.md), [UAT Checklist](./UAT-Checklist-v1.0-rc1.md), [SaaS Launch Checklist](./SaaS-Launch-Checklist.md), [Production Integrations](./Production-Integrations.md)
