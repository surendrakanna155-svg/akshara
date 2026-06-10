# Demo School Validation Plan

**Version:** 1.0  
**Feature freeze:** active — pilot validation only  
**Last updated:** 2026-06-10

---

## Purpose

Establish **Akshara Staging School** (`a2000000-0000-4000-8000-000000000001`) as the first **Demo School** pilot tenant. Populate realistic data and verify core ERP + mobile workflows before live school onboarding.

This plan is operational validation — not a roadmap milestone.

---

## Demo School profile

| Attribute | Target | Notes |
|-----------|--------:|-------|
| Students | 500 | Admission prefix `DEMO-2026-####` |
| Teachers | 35 | Phones `9000000001`–`9000000035` |
| Guardians | 750 | 500 primary (import) + 250 secondary invites |
| Classes | Nursery → 10 | 13 class labels |
| Sections | A, B | 26 sections total (~19 students/section at 500) |
| Academic year | 2026-27 | ID `ce100000-0000-4000-8000-000000000001` |

**Reserved staging phones (do not use in demo ranges):**

| Role | Phone |
|------|-------|
| Admin | `9876543210` |
| Probe parent | `9876543211` |
| Probe student | `9876543212` |
| Probe teachers | `9876543213`, `9876543214` |

---

## Tooling

| Script | Purpose |
|--------|---------|
| `scripts/demo_school_lib.py` | Shared API client + data generators |
| `scripts/demo_school_seed.py` | Seed catalog, imports, finance, attendance, comms |
| `scripts/demo_school_validate.py` | End-to-end workflow verification |

**Artifacts:**

- `reports/demo_school/seed_manifest.json`
- `reports/demo_school/validation_report.json`

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `API_BASE_URL` | Staging Supabase `api` function | Backend base URL |
| `DEMO_STUDENT_COUNT` | `500` | Student import rows |
| `DEMO_TEACHER_COUNT` | `35` | Teacher import rows |
| `DEMO_GUARDIAN_COUNT` | `750` | Unique guardian phone pool |
| `DEMO_IMPORT_BATCH_SIZE` | `50` | Rows per onboarding commit |
| `DEMO_FINANCE_SAMPLE_SIZE` | `100` | Fee assignments for pilot finance |
| `DEMO_ATTENDANCE_DAYS` | `14` | Historical attendance sessions |
| `DEMO_SCHOOL_ID` | School A UUID | Demo tenant |

### Smoke run (recommended first)

```bash
cd /path/to/Akshara_ERP

DEMO_STUDENT_COUNT=50 DEMO_TEACHER_COUNT=5 DEMO_GUARDIAN_COUNT=75 \
DEMO_FINANCE_SAMPLE_SIZE=10 DEMO_ATTENDANCE_DAYS=5 \
  python3 scripts/demo_school_seed.py

python3 scripts/demo_school_validate.py
```

### Full pilot dataset

```bash
python3 scripts/demo_school_seed.py   # defaults: 500/35/750
python3 scripts/demo_school_validate.py
```

---

## Seeding strategy (API-first)

| Phase | Method | API / module |
|-------|--------|--------------|
| 1. Academic catalog | REST | `POST /academic/classes`, `POST /academic/sections` |
| 2. Teachers | Onboarding import | `POST /onboarding/imports/teachers/preview` → commit |
| 3. Students | Onboarding import (batched) | `POST /onboarding/imports/students/preview` → commit |
| 4. Secondary guardians | Onboarding invites | `POST /onboarding/invites` |
| 5. Timetables | Timetable engine | `POST /academic/timetables/generate` → validate → publish |
| 6. Fee structures | Finance | `POST /finance/fee-structures` |
| 7. Fee assignments | Finance | `POST /finance/fee-assignments` (sample cohort) |
| 8. Invoices | Finance | Auto-draft on assign → `POST /finance/invoices/:id/issue` |
| 9. Collections | Finance | `POST /finance/collections` |
| 10. Refunds | Finance | `POST /finance/refunds` → approve |
| 11. Attendance history | Pilot ops | `POST /teacher/attendance/submit` (school scope) |
| 12. Broadcast + queue | Comms | `POST /communications/broadcasts`, `POST /communications/notifications/process-queue` |

**Not seeded via bulk API (by design today):**

- New school provisioning (SQL-only; reuses School A)
- Full 500-student fee ledger (sample of 100 for performance)
- Live SMS/WhatsApp delivery (queue processed; gateways may be stubbed on staging)

---

## Validation matrix

| # | Workflow | Validator step | Pass criteria |
|---|----------|------------------|---------------|
| 1 | Student import | `student import committed` | ≥1 committed student job |
| 2 | Teacher import | `teacher import committed` | ≥1 committed teacher job |
| 3 | Parent OTP login | `parent OTP login (demo import)` | 200 + JWT |
| 4 | Teacher OTP login | `teacher OTP login (demo import)` | 200 + JWT (school scope) |
| 5 | Attendance submission | `attendance submission (submit)` | 200 |
| 6 | Attendance visibility | `attendance visibility (parent)` | 200 on `/parent/attendance` |
| 7 | Timetable visibility | admin summary + parent timetable | 200 |
| 8 | Fee invoice generation | `fee invoice issued records` | ≥1 issued invoice |
| 9 | Fee collection | `fee collection (list)` | 200 + records |
| 10 | Refund flow | `refund flow (list)` | 200 + records |
| 11 | Notification delivery | process queue + parent inbox | 200 |
| 12 | Broadcast messaging | `broadcast messaging` | 201 |
| 13 | Parent-teacher chat | teacher send + parent threads | 201 / 200 |
| 14 | Dashboard analytics | `/analytics/dashboard`, SIS, finance dashboards | 200 |
| 15 | AI Copilot queries | session create + message | 200 / 201 |

---

## Execution checklist

### Pre-flight

- [ ] Staging `api` function deployed (tag `v1.0-pilot-ready` or later)
- [ ] Migrations through `20260615100000_analytics_intelligence.sql` applied
- [ ] `./scripts/pilot_staging_verify.sh` passes (213 probes)
- [ ] Admin can OTP login with school scope

### Seed

- [ ] Run smoke seed (`50` students) — confirm `seed_manifest.json` failed=0
- [ ] Run full seed (`500` students) — allow ~15–30 min for batched commits
- [ ] Confirm demo student count in SIS list

### Validate

- [ ] `python3 scripts/demo_school_validate.py` — failed=0
- [ ] Manual spot-check: parent app fees + attendance for phone `9000100001`
- [ ] Manual spot-check: ERP finance dashboard totals non-zero

### Defect handling

- [ ] Log every failure in [Pilot Issue Tracker](./Pilot-Issue-Tracker.md)
- [ ] Fix only in-scope defects (no new modules)
- [ ] Re-run validate after each fix

---

## Known constraints

1. **Onboarding import** creates label-based enrollments; run soft-FK backfill if academic FK linkage required (`scripts/backfill_academic_soft_fk.py`).
2. **Attendance endpoints** require **school scope** JWT (teachers login with `scope=school`, not a separate teacher scope).
3. **Large imports** must be batched (`DEMO_IMPORT_BATCH_SIZE=50`) to avoid Edge Function timeouts.
4. **Guardian count 750** = 500 import primaries + 250 secondary invites (one guardian per CSV row).
5. **Re-runs** are idempotent on admission numbers (`DEMO-2026-*` duplicates marked in preview).

---

## Related documents

- [Pilot Onboarding Runbook](./Pilot-Onboarding-Runbook.md)
- [Pilot Issue Tracker](./Pilot-Issue-Tracker.md)
- [SaaS Launch Checklist](./SaaS-Launch-Checklist.md)
