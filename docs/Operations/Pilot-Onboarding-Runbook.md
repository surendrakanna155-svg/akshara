# Pilot Onboarding Runbook

**Version:** 2.0 (v7.7)

## Pre-flight

1. Confirm staging: `./scripts/pilot_staging_verify.sh` (13+ checks)
2. Confirm tenant probes: `GET /health/tenant-access` with header `x-internal-health-token: $INTERNAL_HEALTH_TOKEN` — expect **213/213** pass
3. Confirm ops snapshot: `GET /health/operations` (same internal token header)
4. Optional full launch gate: `./scripts/production_launch_verify.sh`

## School data import

1. Open ERP → SIS → **School Onboarding** (`/sis/onboarding`)
2. **Student import:** upload CSV → preview → commit
3. **Teacher import:** upload CSV → preview → commit
4. Rollback within 24h if validation errors: `POST /onboarding/imports/:id/rollback`

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

See also: [Demo School Validation Plan](./Demo-School-Validation-Plan.md), [Pilot Issue Tracker](./Pilot-Issue-Tracker.md), [SaaS Launch Checklist](./SaaS-Launch-Checklist.md), [Production Integrations](./Production-Integrations.md)
