# Staging Migration Recovery — v15.7

**Tag:** `v15.7-staging-migration-recovery`  
**Date:** June 2026  
**Blocker:** `relation "intel_student_risk_snapshots" does not exist`

---

## Root cause

Staging `supabase db push` stopped applying migrations at **`20260620000001_education_permissions.sql`** (first broken file in the chain).

| Issue | Detail |
|-------|--------|
| **Wrong table** | Migrations used `INSERT INTO permissions (...)` |
| **Correct table** | RBAC schema defines `permission_definitions` (`20260608100000_rbac_foundation.sql`) |
| **Wrong columns** | Several files used `code`, `role_code`, `permission_code` instead of `slug`, `role_slug`, `permission_slug` |
| **Effect** | Postgres error `relation "permissions" does not exist` → chain halted before intelligence layer |
| **Symptom** | Edge API deployed (routes live) but DB missing `intel_student_risk_snapshots` → tenant probes + principal intelligence 500 |

**Not** a missing migration file — `20260621000000_intelligence_layer_foundation.sql` exists and is correct.

---

## Migration involved

| File | Purpose |
|------|---------|
| `20260621000000_intelligence_layer_foundation.sql` | Creates `intel_student_risk_snapshots`, `intel_communication_drafts`, `intel_parent_guidance_reports` |
| `20260621000001_intelligence_permissions.sql` | Intelligence RBAC (was broken; fixed) |
| `20260621000002_intelligence_probe_seed.sql` | Probe fixtures `f0500000-…` |
| **`20260627100000_staging_intelligence_layer_recovery.sql`** | **Idempotent hotfix** (IF NOT EXISTS + probe seed) |

---

## Repository / service references

| Layer | Path |
|-------|------|
| Repository | `supabase/functions/_shared/intelligence/student_risk_repository.ts` |
| Engine | `supabase/functions/_shared/intelligence/student_risk_engine.ts` |
| Principal center | `supabase/functions/_shared/intelligence/principal_intelligence_service.ts` |
| Teacher success | `supabase/functions/_shared/intelligence/teacher_success_service.ts` |
| Tenant probes | `supabase/functions/_shared/tenant_isolation_probes.ts` → `INTEL_RISK_*` |
| Student 360 | `supabase/functions/_shared/sis/student_360_service.ts` |
| Operations hub | `supabase/functions/_shared/operations/operations_hub_service.ts` |

---

## Schema objects (intel_student_risk_snapshots)

- **FK:** `organization_id` → `organizations`, `school_id` → `schools`, `student_id` → `students`
- **Indexes:** `idx_intel_student_risk_school_class`, `idx_intel_student_risk_student`
- **RLS:** `intel_student_risk_school_scope` (FORCE RLS, school scope)
- **Grants:** `SELECT, INSERT, UPDATE, DELETE` to `erp_tenant`

---

## Recovery plan

### 1. Verify migration table state (staging)

```bash
export SUPABASE_ACCESS_TOKEN=...
supabase link --project-ref "$SUPABASE_PROJECT_ID_STAGING"
supabase migration list
```

Expect pending migrations from `20260620000001` onward if push previously failed.

### 2. Apply fixed chain + hotfix

```bash
supabase db push
supabase functions deploy api --no-verify-jwt
```

Or trigger **Backend Staging** GitHub Actions on `main`.

### 3. Verify schema drift

```sql
SELECT to_regclass('public.intel_student_risk_snapshots');
SELECT count(*) FROM intel_student_risk_snapshots;
```

### 4. Run staging probes

```bash
./scripts/pilot_readiness_verify.sh
python3 scripts/device_validation_matrix.py
```

**Success criteria:**

- Tenant isolation probes pass (219/219)
- Admin intelligence `/intelligence/principal/center` → 200 (with `viewAnalytics`)
- Storage/provider health remain 200

---

## Files changed (v15.7)

- Fixed 14 `*_permissions.sql` migrations (`permissions` → `permission_definitions`)
- Added `20260627100000_staging_intelligence_layer_recovery.sql`
- Added `intelligence_migration_validation_test.ts`
- Added `student_risk_repository_test.ts`
- This document

---

## Deployment steps

1. Merge / push to `main`
2. Confirm **Backend Staging** → **Push migrations** succeeds
3. Confirm **Deploy api function** succeeds
4. Run `./scripts/pilot_readiness_verify.sh` — expect **22/22 pass**
5. Run `python3 scripts/device_validation_matrix.py` — expect **18/18 pass**

---

## Rollback

If recovery migration causes conflict (unlikely — idempotent):

1. Do **not** drop tables in production without backup
2. Revert tag; Edge API rollback via prior `functions deploy` bundle
3. Mark migration reverted in Supabase dashboard only with DBA review
