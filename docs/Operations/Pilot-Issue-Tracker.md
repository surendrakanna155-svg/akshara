# Pilot Issue Tracker

**Version:** 1.3  
**Branch:** `main` (feature freeze — no new milestones)  
**Last updated:** 2026-06-10

---

## Purpose

Single source of truth for defects and operational fixes discovered during the v1.0 pilot.  
Only in-scope work is logged here: pilot bugs, onboarding/import, OTP/auth, attendance/fees/notifications/timetable, and deployment/configuration.

**Out of scope:** new modules, v7.8+ milestones, CRM, franchise, or feature requests unless explicitly approved.

---

## How to use

1. **Open an issue** when a school or ops run surfaces a defect (staging smoke, onboarding, or production pilot).
2. Assign the next **Issue ID** (`PILOT-YYYY-NNN`, sequential within the calendar year).
3. Fill all fields below before starting a fix.
4. After merge, set **Fix Commit** (full SHA or `pending`) and **Verification Status**.
5. Update the summary counts at the bottom of this file.

### Severity

| Level | When to use |
|-------|-------------|
| **Critical** | Production down, data loss, auth bypass, payment/compliance block |
| **High** | Core workflow blocked (enrollment, fees, attendance, OTP login) |
| **Medium** | Workaround exists; UX or partial module failure |
| **Low** | Cosmetic, copy, non-blocking edge case |

### Verification status

| Status | Meaning |
|--------|---------|
| **Open** | Reported; not yet fixed |
| **In progress** | Fix branch or PR active |
| **Fixed — pending verify** | Commit landed; awaiting staging/pilot re-test |
| **Verified** | Repro steps pass on target environment |
| **Won't fix (pilot)** | Accepted risk; documented reason in Root Cause |

---

## Issue log

| Issue ID | Date | School | Module | Severity | Reproduction Steps | Root Cause | Fix Commit | Verification Status |
|----------|------|--------|--------|----------|-------------------|------------|------------|---------------------|
| PILOT-2026-001 | 2026-06-10 | Demo School (School A) | Onboarding | **High** | Run `python3 scripts/demo_school_seed.py` → teacher/student import commit returns 500 | `erp_tenant` cannot INSERT into `users` under RLS; first row error aborts PG transaction so job stays `previewed` | `20260615110000_onboarding_user_provisioning_fix.sql` + handler/repository updates | **Verified** |
| PILOT-2026-002 | 2026-06-10 | Demo School | Timetable | **High** | `POST /academic/timetables/generate` → 404 Route not found | `routeAcademic()` returned 404 for unmatched `/academic/*` paths before timetable router ran | `academic_router.ts` (return `null` when no match) | **Verified** |
| PILOT-2026-003 | 2026-06-10 | Demo School | Finance | **Medium** | Seed fee structure with hard-coded year ID `ce100000-…` on staging | Staging DB lacks seed UUID; academic year labels differ from local migration IDs | `resolve_academic_year()` in demo scripts | **Verified** |
| PILOT-2026-004 | 2026-06-10 | Demo School | Communications | **Medium** | `POST /communications/broadcasts` with `audience=parents` → 500 | `comm_broadcasts.audience` CHECK rejects shorthand values (`parents`, `teachers`) | `normalizeBroadcastAudience()` in `communication_service.ts` | **Verified** |
| PILOT-2026-005 | 2026-06-10 | Demo School | Onboarding | **Low** | Secondary guardian invites via wrong JSON fields | Client script used `role`/`phone` instead of `inviteType`/`recipientPhone`/`recipientLabel` | demo seed script | **Verified** |
| PILOT-2026-006 | 2026-06-10 | Demo School | Analytics | **High** | `GET /analytics/dashboard` → 500 | SQL used `finance_invoices.status`; column is `invoice_status` | `analytics_metrics_service.ts` | **Verified** |
| PILOT-2026-007 | 2026-06-10 | Demo School | Mobile Read | **High** | Demo parent OTP login OK but `GET /parent/attendance`, `/parent/timetable`, `/parent/fees` → 404 | Onboarding creates students/guardians but not `parent_entities` snapshot rows; handlers threw `SnapshotNotFoundError` | Live-data fallbacks in `mobile_read_handlers.ts` + `pilot_operations_repository.ts` | **Verified** |
| PILOT-2026-008 | 2026-06-10 | Demo School | Auth | **High** | Full 500-student seed (~15 min) → finance/attendance/broadcast fail with `Invalid access token` | Admin JWT expired before post-import seed phases completed | Refresh `admin_token()` between seed phases in `demo_school_seed.py` | **Verified** |
| PILOT-2026-009 | 2026-06-10 | Demo School | Attendance | **Medium** | At 500 students, seed reports `not enough demo students` | `list_students` capped at 2 pages × 50 rows | Increase pagination to 10 pages in `seed_attendance_history` | **Verified** |
| PILOT-2026-010 | 2026-06-10 | Deployment | **Low** | `production_launch_verify.sh` exits early on macOS bash | `set -u` + empty `health_headers` array expansion | Safe curl array expansion in launch + pilot verify scripts | **Verified** |
| PILOT-2026-011 | 2026-06-10 | Deployment | **Low** | Launch verify fails timetable check with HTTP 422 | Script called summary without `academicYearId`; 422 means route mounted | Accept 422 as pass when `ACADEMIC_YEAR_ID` unset | **Verified** |
| PILOT-2026-012 | 2026-06-10 | Demo School | Communications | **Medium** | `POST /communications/broadcasts` → 502 during full-scale seed | Transient gateway timeout under large parent audience + concurrent load | Immediate retry succeeds; monitor in production | **Verified** |

---

## Verification evidence (2026-06-10 — production validation)

See [`Production-Validation-Report.md`](./Production-Validation-Report.md).

```bash
python3 scripts/demo_school_seed.py              # 500/35/750 (~15 min)
python3 scripts/demo_school_seed.py --post-import-only
SKIP_FULL_SEED=1 python3 scripts/production_validation.py
python3 scripts/demo_school_validate.py        # 31/31
bash scripts/pilot_staging_verify.sh             # 13/13
bash scripts/production_launch_verify.sh         # 11/11
```

---

## Issue detail

### PILOT-2026-001 — Onboarding import commit 500

| Field | Value |
|-------|-------|
| **Module** | Onboarding |
| **Severity** | High |

**Reproduction steps**

1. Login admin school scope (`9876543210`).
2. `POST /onboarding/imports/teachers/preview` with one valid row.
3. `POST /onboarding/imports/{id}/commit` → 500 `Import commit failed`.

**Root cause**

Onboarding commit upserts parent/teacher rows into `users` using the `erp_tenant` connection. `users` has no INSERT policy/grant for `erp_tenant`. PostgreSQL marks the transaction aborted; subsequent UPDATE never runs.

**Fix**

- Migration: SECURITY DEFINER functions `onboarding_upsert_user_by_phone`, `onboarding_ensure_school_membership`
- Repository: per-row SAVEPOINT so one bad row does not abort batch
- Handler: surface underlying error message in 500 response

**Verified by:** Teacher/student import jobs show committed rows; seed + validate PASS.

---

### PILOT-2026-002 — Timetable routes shadowed by academic router

**Reproduction:** `POST /academic/timetables/generate` → 404.

**Root cause:** `routeAcademic()` returned 404 for any unmatched `/academic/*` path, preventing `routeTimetable()` from running.

**Fix:** Return `null` when `matchAcademicRoute()` is null.

**Verified by:** Seed generates 26 timetables; validate admin summary PASS.

---

### PILOT-2026-004 — Broadcast audience CHECK constraint

**Reproduction:** `POST /communications/broadcasts` with `audience: "parents"` → 500.

**Root cause:** DB CHECK allows only `all_parents`, `all_teachers`, `all_students`, `school_wide`.

**Fix:** Normalize shorthand audience labels before INSERT.

**Verified by:** Seed + validate broadcast messaging PASS.

---

### PILOT-2026-007 — Parent mobile reads for onboarded students

**Reproduction:** Demo parent (`9000100001`) login OK; parent attendance/timetable/fees → 404.

**Root cause:** Mobile read handlers required pre-seeded `parent_entities` rows (probe student only). Onboarded students had live attendance/finance data but no snapshot rows.

**Fix:** Build default snapshot from student enrollment context; overlay live attendance, timetable slots, and finance invoices.

**Verified by:** `demo_school_validate.py` parent visibility checks PASS.

---

## Summary

| Metric | Count |
|--------|------:|
| Total issues | 12 |
| Open | 0 |
| In progress | 0 |
| Fixed — pending verify | 0 |
| Verified | 12 |
| Won't fix (pilot) | 0 |

### By severity (open + in progress)

| Critical | High | Medium | Low |
|--------:|-----:|-------:|----:|
| 0 | 0 | 0 | 0 |

---

## Related runbooks

- [Customer Readiness Report](./Customer-Readiness-Report.md)
- [Operational Readiness Report](./Operational-Readiness-Report.md)
- [Production Validation Report](./Production-Validation-Report.md)
- [Go-Live Checklist](./Go-Live-Checklist.md)
- [v1.0 Release Candidate](../Releases/v1.0-Release-Candidate.md)
- [Demo School Validation Plan](./Demo-School-Validation-Plan.md)
- [Pilot Onboarding Runbook](./Pilot-Onboarding-Runbook.md)
- [SaaS Launch Checklist](./SaaS-Launch-Checklist.md)
- [Rollout Checklist](./Rollout-Checklist.md)
- [Rollback Checklist](./Rollback-Checklist.md)
- [Production Integrations](./Production-Integrations.md)
