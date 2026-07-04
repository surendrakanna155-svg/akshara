# Real School Validation — Onboarding & Import Readiness

**Version:** v10.4.2  
**Date:** June 2026  
**Scope:** CSV import, duplicate handling, rollback, teacher/student provisioning, parent OTP onboarding

---

## System Under Review

| Component | Location |
|-----------|----------|
| Import preview/commit/rollback | `supabase/functions/_shared/onboarding/onboarding_handlers.ts` |
| CSV parsing & validation | `supabase/functions/_shared/onboarding/onboarding_repository.ts` |
| User provisioning | `supabase/functions/_shared/onboarding/onboarding_user_provisioning.ts` |
| Flutter onboarding UI | `lib/features/onboarding/` (read via repository) |
| Parent OTP auth | `supabase/functions/_shared/auth_handlers.ts` |

---

## Validated Capabilities

### CSV imports

| Import type | Preview endpoint | Required fields |
|-------------|------------------|-----------------|
| Students | `POST /onboarding/imports/students/preview` | studentName, admissionNumber, classLabel, sectionLabel, academicYear, parentName, parentPhone |
| Teachers | `POST /onboarding/imports/teachers/preview` | displayName, phone, role (teacher/principal/schoolAdmin) |

- Supports raw `csvText` or structured `rows[]`
- Quoted-field CSV parsing (`parseCsvLine`)
- Row-level validation errors returned in preview report

### Duplicate handling

- Student imports call `findDuplicateStudent` by admission number before commit
- Preview marks duplicates with `duplicate_rows` counter on import job
- Duplicate rows flagged in preview status — not silently merged

### Rollback paths

- `POST /onboarding/imports/:id/rollback` reverses committed student imports via `rollbackImportedStudent`
- Job status transitions tracked on `onboarding_import_jobs`
- **Limit:** Rollback scope is per-job; cross-job cascading delete not supported

### Teacher imports

- Creates/updates user by phone via `upsertUserByPhone`
- Assigns school membership + role via `ensureSchoolMembership`
- Roles: teacher, principal, schoolAdmin

### Student imports

- Creates student record + optional parent link
- Provisions parent phone for OTP login path

### Parent provisioning & OTP

- Parent phone normalized (`normalizeImportPhone`)
- Login flow: `POST /auth/login` → OTP → `POST /auth/verify-otp` with `scope=parent`
- Linked children resolved from `parent_student_map` at verify time

---

## Risks

| ID | Risk | Severity | Mitigation |
|----|------|----------|------------|
| R1 | Staging Edge bundle missing Phase 5 + onboarding routes (404) | **High** | Run `./scripts/deploy_staging.sh` before school pilot |
| R2 | Rollback does not undo finance/SIS side-effects post-enrollment | Medium | Run imports on staging copy first; document manual cleanup |
| R3 | Duplicate detection admission-number only — same student new admission # creates duplicate | Medium | Pre-import dedup report review by admissions team |
| R4 | Large CSV (>500 rows) not load-tested on Edge timeout | Medium | Batch imports in chunks ≤200 rows |
| R5 | Parent OTP depends on demo SMS stub in staging | Medium | Wire production SMS provider before go-live |
| R6 | Teacher import does not auto-create timetable/class assignments | Low | Follow with academic catalog setup (v6.1) |
| R7 | No automated parent invite send on import commit | Low | Use `POST /onboarding/invites` after import review |

---

## Limits

- Import preview is synchronous — very large files may hit Edge 150s limit
- No built-in photo/document import in CSV flow
- Parent multi-child linking requires separate rows or manual SIS mapping
- OTP onboarding requires valid phone unique across tenant
- Rollback window: job-level only, no time-based auto-expiry

---

## Operational Recommendations

1. **Pilot sequence:** staging deploy → `phase5_staging_verify.sh` green → import 10-row sample → parent login smoke → production deploy
2. **Import checklist:** preview → review invalid/duplicate counts → commit → verify SIS registry → send invites
3. **Go-live gate:** require `committed_rows == valid_rows` and `invalid_rows == 0` before production commit
4. **Support playbook:** keep rollback job ID for 24h after bulk import
5. **Monitoring:** audit events on import commit/rollback (`onboarding.import.*` in mutation catalog)
6. **Training:** admissions staff review duplicate report before commit; finance notified after student import for fee assignment

---

## Test Coverage

| Area | Tests |
|------|-------|
| Onboarding repository | `onboarding_repository_test.ts` (Deno) |
| Onboarding handlers | `onboarding_handlers_test.ts` (Deno) |
| Phase 5 staging manifest | `test/contracts/rbac/phase5_staging_readiness_test.dart` |
| Auth OTP parent | `test/auth_provider_test.dart`, `test/integration/auth/` |

---

## Readiness Verdict

**Import system:** Code-complete for preview/commit/rollback — **staging deploy required** before real-school validation.

**Parent OTP:** Functional in demo/staging with phone OTP stub — production SMS integration is the remaining ops dependency.
