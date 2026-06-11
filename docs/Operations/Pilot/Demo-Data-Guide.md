# Demo Data Guide — Akshara Staging School

## Overview

The demo school simulates a **500-student K–10 institution** with full staff, finance, academic, and inventory data for pilot validation.

## Seed command

```bash
python3 scripts/demo_school_seed.py
```

Optional overrides:

```bash
DEMO_STUDENT_COUNT=500 \
DEMO_TEACHER_COUNT=20 \
DEMO_STAFF_COUNT=10 \
DEMO_GUARDIAN_COUNT=500 \
python3 scripts/demo_school_seed.py
```

## Dataset targets

| Entity | Count | Notes |
|--------|------:|-------|
| School | 1 | `Akshara Staging School` |
| Principal | 1 | First staff import row |
| Teachers | 20 | `Demo Teacher 01–20` |
| Non-teaching staff | 10 | Accountant, clerk, librarian, etc. (`schoolAdmin` role) |
| Students | 500 | `DEMO-2026-0001` … `DEMO-2026-0500` |
| Parents | 500 | 1:1 phone mapping `9000100001` … |
| Class-sections | 26 | Nursery–10 × sections A/B |
| Subjects | 8 | English, Math, Science, … |
| Fee assignments | ~150 | Configurable via `DEMO_FINANCE_SAMPLE_SIZE` |
| Attendance history | 30 days | 25 students × class |
| Homework | 8 class samples | Education module |
| Exam papers | 6 unit tests | Question paper generator |
| Book kit distributions | 50 | Inventory distribution catalog |
| Lesson logs | 40 | School completion module |

## Sample login phones

| Persona | Phone |
|---------|-------|
| School admin | `9876543210` |
| Principal / Teacher 1 | `9000000001` |
| Teacher 2 | `9000000002` |
| Parent (student 1) | `9000100001` |
| Parent (student 2) | `9000100002` |

OTP appears in API login response (staging demo mode).

## Validation

```bash
python3 scripts/demo_school_validate.py
```

Report: `reports/demo_school/validation_report.json`  
Seed manifest: `reports/demo_school/seed_manifest.json`

## Refresh post-import only

If students/teachers already exist:

```bash
python3 scripts/demo_school_seed.py --post-import-only
```
