# B1 — Admissions CRM completion · Certification

**Date:** 2026-06-24 · **Branch:** `feature/scope-trim-school-build`

Closes the remaining ~30% of the Admissions CRM: the lead-management loop
(assignment, stage transitions, follow-ups, notes, WhatsApp/call logging and a
persisted activity timeline + follow-up history). The Flutter UI, models, DTOs,
providers and API contract for all of this already existed and were wired to the
mock repository, but **had no backend persistence** — the action routes 404'd in
live mode and the timeline/history shown to users was hard-coded fixture data.

## What was gap, now closed

| Capability | Before | After |
|---|---|---|
| Lead assignment | UI + client `PATCH /assign`, no server route | Real `PATCH /admissions/leads/{id}/assign` → updates counselor + timeline + audit |
| Stage transitions | UI + client `PATCH /stage`, no server route | Real `PATCH …/stage` → updates stage + timeline + audit |
| Follow-ups | UI + client `POST /followups`, no table | Real `POST …/followups` → `admissions_lead_follow_ups` row + timeline + audit |
| Notes | UI + client `POST /notes`, scalar only | Real `POST …/notes` → activity row + audit |
| Activity timeline | Hard-coded client fixtures | Real `GET …/leads/{id}` returns persisted `activities[]` |
| Communication history | — | Same timeline, filtered by activity type |
| WhatsApp logging | — | `POST …/notes` with `activity_type:"whatsapp"` (wa.me only, no Meta API) |
| Call logging | — | `POST …/notes` with `activity_type:"call"` |

## Implementation (additive, reuses existing infra)

- **DB** — `supabase/migrations/20260716000000_admissions_crm_activities_followups.sql`:
  `admissions_lead_activities` (unified timeline) + `admissions_lead_follow_ups`.
  Same pattern as `admissions_leads`: FORCE RLS, school-scope policy, `erp_tenant`
  grants, `set_updated_at` trigger, FK + `ON DELETE CASCADE`. Additive only.
- **Backend** — 4 handlers + repository fns + router routes in
  `supabase/functions/_shared/admissions/*`; audit catalog entries
  (`admissions.lead.assigned|stage_changed|follow_up_added|note_added`) keyed off
  the new row id so repeated actions are never deduped. RBAC: `manageAdmissions`
  + school operational scope, mirroring existing lead handlers.
- **Flutter** — real `getLeadDetail` across interface/API/mock/datasource/mapper;
  the lead-detail provider now fetches the persisted timeline + follow-up history
  instead of synthesising it; mutations refresh the detail + list; "Log call" and
  "Log WhatsApp" quick actions added.

## Definition of Done

| Gate | Result |
|---|---|
| Real persistence | ✅ rows in `admissions_lead_activities` / `_follow_ups` |
| Migration applies on real Postgres | ✅ `supabase migration up` clean; RLS+FORCE+policy+grants verified |
| Real auth + real DB E2E | ✅ `scripts/admissions_crm_b1_smoke.sh` — **11/11 passed** (assign→stage→follow-up→note→WhatsApp→call→timeline read-back; parent denied 403; cross-school 404) |
| Audit logging | ✅ domain events recorded for all actions |
| `flutter analyze` | ✅ clean on touched code |
| Tests green | ✅ admissions + contract + integration suites pass (one pre-existing, unrelated SIS-count failure on baseline) |
| Deno type-check | ✅ router/handlers/repository/mapper/audit |

## Live VPS production certification — ✅ DONE (2026-06-24)

Deployed and certified on the production VPS (`46.28.44.46` / `akshara.veloraunisexsalon.com`,
stack dir `/opt/akshara`) over an authenticated SSH control-master session:

1. **Backup first:** `akshara-backup.sh manual` → `akshara_db_20260624T133840Z_manual.dump.enc`.
2. **Migration:** `20260716000000_admissions_crm_activities_followups.sql` applied to `akshara_db`
   as `supabase_admin` (`ON_ERROR_STOP`), recorded in `supabase_migrations.schema_migrations`.
   Verified on the live DB: both tables `rls=t force=t policies=1 erp_insert=t`.
3. **Edge:** the 5 B1 files synced into `/opt/akshara/functions/` and `akshara-edge` recreated.
4. **Live smoke** (real auth via pilot phone + real production DB):
   `API_BASE_URL=https://akshara.veloraunisexsalon.com scripts/admissions_crm_b1_smoke.sh`
   → **`Results: 11 passed, 0 failed`** (assign→stage→follow-up→note→WhatsApp→call→timeline
   read-back; parent assign 403; cross-school 404).
5. **Audit verified** on the live DB: `admissions.lead.{assigned,created,follow_up_added,
   note_added×3,stage_changed}` domain events recorded. Smoke test lead removed (cascade).

**Deploy note (for future deploys):** the compose `postgres` service interpolates
`${POSTGRES_DB}`/`${POSTGRES_PASSWORD}` from compose's env, and there is no default `.env`
in `/opt/akshara` — so **always run compose with `--env-file .env.akshara`**. Running a plain
`docker compose up` recreates `akshara-postgres` with an empty `POSTGRES_DB`, which fails its
`pg_isready` healthcheck (data is safe on the `akshara_pgdata` volume; fix = recreate postgres
with `--env-file .env.akshara`). This was hit and fully resolved during this deploy.

**Status: B1 = Production Certified.**
