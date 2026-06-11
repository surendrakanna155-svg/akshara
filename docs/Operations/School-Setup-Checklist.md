# School Setup Checklist (Pre-Go-Live)

**Version:** 1.0 (v1.0-rc1)  
**When:** Before first real-school data import  
**Prerequisite:** Environment deployed per [`Go-Live-Checklist.md`](./Go-Live-Checklist.md)

---

## 1. Platform & tenant

- [ ] Target environment verified (`production_launch_verify.sh` or equivalent)
- [ ] `INTERNAL_HEALTH_TOKEN` set (production)
- [ ] `AUTH_OTP_DEV_MODE=false` (production)
- [ ] Organization record exists
- [ ] School record created with unique code
- [ ] School admin user created with `schoolAdmin` membership
- [ ] School admin can OTP login (school scope)

**Note:** New school provisioning may require SQL/ops script today — confirm school UUID with platform team before import.

---

## 2. Academic foundation

- [ ] Academic year created (e.g. `2026-27`) and marked **current**
- [ ] Start/end dates set
- [ ] Classes created (Nursery → 10 or school-specific labels)
- [ ] Sections created (A, B, …) per class
- [ ] Class labels in CSV **match exactly** catalog labels (case-sensitive)

---

## 3. Staff onboarding

- [ ] Download [`templates/teacher_import_template.csv`](./templates/teacher_import_template.csv)
- [ ] Principal row uses `role=principal`
- [ ] All phones unique per teacher
- [ ] Teacher CSV preview → review invalid/duplicate rows
- [ ] Teacher import committed
- [ ] Principal login tested (school scope)
- [ ] At least one teacher login tested

---

## 4. Student & parent onboarding

- [ ] Download [`templates/student_import_template.csv`](./templates/student_import_template.csv)
- [ ] Admission number scheme agreed (unique per school)
- [ ] `academicYear` column matches current year label
- [ ] Import in batches of **≤ 50 rows** per job (avoid timeout)
- [ ] First batch preview → commit → spot-check 3 students in SIS
- [ ] Parent login tested for 2 phones from import
- [ ] Sibling test: two students, same `parentPhone` → one parent, two children
- [ ] Secondary guardians invited per [`parent_guardian_guide.md`](./templates/parent_guardian_guide.md) (if needed)
- [ ] Optional: `studentPhone` populated for student-app pilot cohort

---

## 5. Finance (if fees from day one)

- [ ] Fee structure created for current academic year
- [ ] Sample fee assignment on 3 students
- [ ] Parent fees visible on mobile
- [ ] Cash collection recorded for one invoice (smoke)
- [ ] Finance admin role assigned (if separate from school admin)

---

## 6. Operations modules (minimum)

- [ ] Attendance: one class marked for today
- [ ] Timetable: generated for current year (optional day-one)
- [ ] Communications: test broadcast to `all_teachers`
- [ ] Notification queue processed

---

## 7. Validation gates

- [ ] [`UAT-Checklist-v1.0-rc1.md`](./UAT-Checklist-v1.0-rc1.md) — onboarding section (ONB-*) complete
- [ ] Defects logged in [`Pilot-Issue-Tracker.md`](./Pilot-Issue-Tracker.md)
- [ ] Rollback procedure understood ([`Rollback-Checklist.md`](./Rollback-Checklist.md))

---

## Sign-off

| Step | Owner | Date | Done |
|------|-------|------|:----:|
| Platform / tenant | | | ☐ |
| Academic catalog | | | ☐ |
| Staff import | | | ☐ |
| Student import | | | ☐ |
| Finance smoke | | | ☐ |
| Ops modules | | | ☐ |
