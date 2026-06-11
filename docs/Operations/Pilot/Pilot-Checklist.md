# Pilot Checklist — Real School Simulation

**Version:** v15.0 · **School OS only**

## Pre-pilot gates

- [ ] `flutter analyze` — 0 issues
- [ ] `flutter test` — all passing
- [ ] `./scripts/pilot_staging_verify.sh` — core 13/13 PASS
- [ ] `./scripts/pilot_deploy_v14.sh` — Edge deployed (Supabase auth required)
- [ ] `python3 scripts/demo_school_seed.py` — 500-student dataset seeded
- [ ] `python3 scripts/demo_school_validate.py` — workflow validation PASS

## Day 1 — School Admin

- [ ] Login (school scope OTP)
- [ ] Admissions dashboard — pipeline visible
- [ ] SIS registry — 500 students searchable
- [ ] Finance fee structures assigned
- [ ] Inventory distribution dashboard loads
- [ ] Timetable published for current year

## Day 2 — Principal

- [ ] Principal intelligence center (`/intelligence/principal/center`)
- [ ] Student success dashboard
- [ ] Communication analytics summary
- [ ] Lesson analytics (principal view)
- [ ] Academic progress overview

## Day 3 — Teachers (sample 5)

- [ ] Teacher dashboard + today's schedule
- [ ] Attendance draft → submit for one class
- [ ] Homework queue visible
- [ ] Lesson log created
- [ ] Parent message thread

## Day 4 — Parents (sample 10)

- [ ] Parent OTP login
- [ ] Child switcher (multi-child if applicable)
- [ ] Fees, attendance, homework, exams
- [ ] Parent experience hub / academic report
- [ ] Fee payment flow (staging)

## Day 5 — Student + Staff

- [ ] Student dashboard — homework due, timetable
- [ ] Accountant — collections, refunds, executive dashboard
- [ ] Inventory manager — book kit distribution reports

## Sign-off

| Role | Name | Date | Pass/Fail |
|------|------|------|-----------|
| School Admin | | | |
| Principal | | | |
| Teacher | | | |
| Parent | | | |
| Akshara QA | | | |
