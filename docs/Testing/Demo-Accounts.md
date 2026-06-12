# Demo Accounts — Akshara Staging School

**School:** Akshara Staging School  
**Environment:** Staging API (`oeicxjpewrumkfgyqnnj.supabase.co`)  
**Validation:** `reports/demo_school/validation_report.json` — **58/58 passed**

OTP appears in the login API response when staging dev mode is enabled (`AUTH_OTP_DEV_MODE`).

---

## Account matrix

| Persona | Phone | App surface | Primary use |
|---------|-------|-------------|-------------|
| **Principal / School admin** | `9876543210` | ERP web / tablet | Dashboard, intelligence, finance, operations |
| **Teacher 1** | `9000000001` | Teacher mobile | Attendance, homework, lesson logs |
| **Teacher 2** | `9000000002` | Teacher mobile | Alternate teacher workflows |
| **Parent (student 1)** | `9000100001` | Parent mobile | Fees, attendance, homework, progress |
| **Parent (student 2)** | `9000100002` | Parent mobile | Second child / multi-child switcher |
| **Student (probe)** | `9876543212` | Student mobile | Timetable, homework, exams |
| **Parent (probe)** | `9876543211` | Parent mobile | API validation account |
| **Teacher (probe)** | `9876543213` | Teacher mobile | API validation account |

### Mock fallback (offline / no API)

| Persona | OTP | Login steps |
|---------|-----|-------------|
| Principal | `123456` | Role: **Staff** → ERP role **Principal** |
| Teacher | `123456` | Role: **Teacher** |
| Parent | `123456` | Role: **Parent** |
| Student | `123456` | Role: **Student** |

Mock mode uses in-app demo data. Staging login uses seeded demo school (500 students, 20 teachers).

---

## Demo data coverage

Verified by `python3 scripts/demo_school_validate.py`:

| Domain | Seeded | Validated |
|--------|--------|-----------|
| Principal / admin login | ✅ | ✅ |
| Teachers (20) | ✅ | ✅ |
| Parents (500) | ✅ | ✅ |
| Students (500) | ✅ | ✅ |
| **Attendance** | 30 days × 25 students | ✅ submit + parent visibility |
| **Homework** | 8 class samples | ✅ teacher queue + parent visibility |
| **Exams** | 6 unit test papers | ✅ parent + student visibility |
| **Fees** | ~150 assignments, 20 invoices | ✅ collection + parent visibility |
| **Inventory** | 50 book kit distributions | ✅ distribution dashboard |
| **Intelligence** | Dashboard analytics | ✅ SIS + finance + admission dashboards |
| **Lesson logs** | 40 samples | ✅ API list |
| Timetable | Class schedules | ✅ admin, teacher, parent |
| Notifications | Queue + inbox | ✅ parent inbox |
| AI Copilot | Session + queries | ✅ |

Refresh seed:

```bash
python3 scripts/demo_school_seed.py
python3 scripts/demo_school_validate.py
```

---

## Expected test journeys

### Principal (`9876543210`)

1. Login → OTP from API response → verify
2. Land on **Management dashboard**
3. Navigate: **Intelligence hub** → principal summary, risk cards
4. Navigate: **Finance** → KPIs, defaulters, collections
5. Navigate: **Admissions** → pipeline dashboard
6. Navigate: **SIS** → student registry (500 students)
7. Global search → jump to Finance / Enrollment / Intelligence

**Pass criteria:** No blank screens; data loads or shows friendly empty/error with retry.

### Teacher (`9000000001`)

1. Login → Teacher mobile shell
2. **Dashboard** — greeting, today schedule, attendance summary
3. **Attendance** — view class, mark present/absent
4. **Homework** — assigned list, create/view
5. **Lesson logs** — school completion entry (if permitted)
6. **Timetable** — weekly schedule

**Pass criteria:** Schedule and attendance reflect seeded data; no overflow on phone.

### Parent (`9000100001`)

1. Login → Parent mobile shell
2. **Dashboard** — child name, notices, events, quick actions
3. **Attendance** — monthly summary
4. **Fees** — outstanding / paid status
5. **Experience hub** — homework + exam readiness
6. **Notifications** — inbox messages
7. Child switcher (if multiple children linked)

**Pass criteria:** Child context visible; fee and attendance data or clear empty state.

### Student (`9876543212` or mock Student role)

1. Login → Student mobile shell
2. **Dashboard** — schedule strip, homework due
3. **Homework** — assignment list
4. **Timetable** — weekly view
5. **Exams** — upcoming papers
6. **Attendance** — own record

**Pass criteria:** Navigation completes within 2–3 taps from dashboard.

---

## Known staging notes

- Some intelligence endpoints return **403** when probed with the admin token outside RBAC scope (`reports/pilot_validation/program_report.json`). Device testing should use **persona-correct logins** above.
- Parent Experience Hub API may return **404** until latest Edge deploy — UI still navigable; report if blank after login.
- Use **staging network** (Wi‑Fi/mobile data); mock fallback only when documenting offline UX.

---

## Reference

- Full seed guide: `docs/Operations/Pilot/Demo-Data-Guide.md`
- Backend OTP: `backend/README.md`
- Build install: `docs/Testing/Tester-Instructions.md`
