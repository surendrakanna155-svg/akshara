# School Onboarding Guide

## Phase 1 — Tenant setup (Day 0)

1. Provision organization and school in Control Center
2. Run setup wizard (`/setup-wizard`) if enabled
3. Create academic year (e.g. `2026-27`) and mark current
4. Import classes Nursery–10 with sections A/B

## Phase 2 — People (Day 1–2)

1. Import principal + teachers via CSV (`/onboarding/imports/teachers`)
2. Import students with parent phone columns
3. Verify parent OTP login for sample guardians
4. Assign teacher–subject and class–teacher mappings

## Phase 3 — Academic (Day 3–4)

1. Create subjects (`/school/subjects`)
2. Generate and publish timetables
3. Configure syllabus templates per class
4. Enable lesson logging for teachers

## Phase 4 — Finance (Day 5)

1. Create fee structures per class band
2. Bulk-assign fee structures to enrolled students
3. Issue invoices and record opening collections
4. Configure refund approval workflow

## Phase 5 — Operations (Day 6–7)

1. Load inventory catalog (books, uniforms, kits)
2. Configure book distribution rules
3. Enable communications (WhatsApp provider if used)
4. Run pilot dashboard review (`/school/pilot/dashboard`)

## Phase 6 — Go-live validation

1. Run `demo_school_validate.py` equivalent checks
2. Complete Pilot Checklist with real staff
3. Sign off RBAC and tenant isolation probes

## Support contacts

Document your school's Akshara admin contact and escalation path here before go-live.
