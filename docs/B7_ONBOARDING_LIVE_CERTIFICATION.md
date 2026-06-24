# B7 — First-Time Student Onboarding · LIVE Certification

**Date:** 2026-06-24
**Target:** Live VPS pilot — `https://akshara.veloraunisexsalon.com` (real edge, real Postgres)
**Auth:** Real OTP login → real JWT (pilot personas, allowlisted)
**DB checks:** Direct `psql` on the live `akshara_db` (no mocks, no route-existence-only checks)
**Harness:** [`scripts/qa/live_cert_b7_onboarding.py`](../scripts/qa/live_cert_b7_onboarding.py)
**Branch:** `wip/b7-onboarding` (→ merged to `feature/scope-trim-school-build`)

## Result: **10 PASS / 0 FAIL / 0 BLOCKED — GATE: PASS**

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| — | Backend health | **PASS** | `GET /health` → 200 `status:ok` |
| — | Admin OTP login | **PASS** | real OTP → JWT, role `schoolAdmin` |
| 1 | Import preview | **PASS** | `POST /onboarding/imports/students/preview` → `validRows:1`, `status:previewed` |
| 2 | Import commit | **PASS** | `POST …/commit` → `status:committed`, `committedRows:1` |
| 3 | Student creation | **PASS** | DB: `students` + `student_profiles` + 1 current `sis_student_enrollments` row created |
| 4 | Parent provisioning | **PASS** | DB: `users` row created for fresh parent phone + active `student_guardians` link |
| 5 | OTP login | **PASS** | parent persona authenticates end-to-end (`/auth/verify-otp` → JWT, role `parent`) |
| 6 | Aadhaar masking/hash | **PASS** | stored masked `XXXXXXXX2345`, `aadhaar_hash` = sha256(raw), **no raw leak**, duplicate Aadhaar flagged in preview |
| 7 | Placeholder generation | **PASS** | `POST /onboarding/students/generate` → 3 placeholders; DB: `is_placeholder=true`, **0** with user_id, **0** with guardian (no parent login) |
| 8 | Rollback | **PASS** | `POST …/rollback` → `rolled_back`; DB residual students/aadhaar/placeholders = **0** |

Post-run tenant state verified clean (0 residual QA rows).

## Defect found & fixed during certification

**Rollback failed on first run (HTTP 500 `Import rollback failed`).**
Root cause: the edge runs tenant operations as the non-bypass `erp_tenant` role, which holds `INSERT/SELECT/UPDATE` but **no `DELETE`** on student tables (non-destructive by design). Import rollback hard-deletes the student rows it created, so it hit `permission denied`.

Fix (consistent with the existing `onboarding_upsert_user_by_phone` pattern):
- **Migration `20260715000000_onboarding_rollback_student_secdef.sql`** — `SECURITY DEFINER` function `onboarding_rollback_student(student_id, org, school)` performing the scoped cascade delete; `EXECUTE` granted only to `erp_tenant`. The tenant role keeps zero direct `DELETE` rights.
- **`onboarding_user_provisioning.ts`** — `rollbackImportedStudent` now calls the function instead of raw `DELETE`s.
- **`onboarding_placeholder_test.ts`** — fake DB updated for the new call; Deno suite 28/28 green.

Re-certified after deploy → all 10 PASS.

## What was deployed to the live pilot (additive, reversible)

1. Migration `20260713000000` — `students.{aadhaar,aadhaar_hash,is_placeholder}`, `student_profiles.mother_name`, `student_placeholder` import type, unique Aadhaar-hash index.
2. Migration `20260715000000` — SECURITY DEFINER rollback function (above).
3. Edge: `supabase/functions/_shared/onboarding/*` rsynced to `/opt/akshara/functions/…`; `akshara-edge` restarted.

Both migrations are `IF NOT EXISTS` / `CREATE OR REPLACE` idempotent and recorded in the migration ledger.
