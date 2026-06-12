# Real User Journeys — Akshara Pilot Testing

**Purpose:** Role-based flows testers should execute on real devices.  
**Build:** 16.6.0 (166) · **Accounts:** [Demo-Accounts.md](Demo-Accounts.md)

Each journey lists **steps**, **expected outcome**, and **max taps** from dashboard.

---

## Principal

**Login:** `9876543210` · **Surface:** ERP web / tablet

### Daily workflow (~10 min)

| Step | Action | Expected | Taps |
|------|--------|----------|-----:|
| 1 | Login → OTP verify | Management dashboard | — |
| 2 | Review morning KPI row | Enrollment, attendance, fee collection stats | 0 |
| 3 | Open **Intelligence hub** → Summary | Principal summary, health indicators | 2 |
| 4 | Check **risk / alerts** tab | Student risk cards or empty state | 3 |
| 5 | Open **Finance** → dashboard | Defaulters, collection KPIs | 2 |
| 6 | Open **Admissions** pipeline | Lead/enrollment counts | 2 |
| 7 | Global search → "SIS" | Navigate to student registry | 2 |
| 8 | Spot-check one student record | Profile loads | +1 |

**Pass:** No blank screens; errors show retry message.

### Weekly workflow (~15 min)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Intelligence → trends / reports | Charts or tables render |
| 2 | Finance → executive / reports | Period filters work |
| 3 | Inventory → distribution dashboard | Book kit stats |
| 4 | SIS → filter class section | Student list paginates |
| 5 | Export or queue report (if available) | Snackbar confirmation |

---

## Teacher

**Login:** `9000000001` · **Surface:** Teacher mobile

### Attendance journey (~8 min)

| Step | Action | Expected | Taps |
|------|--------|----------|-----:|
| 1 | Dashboard → **Attendance** quick action | Attendance screen | 1 |
| 2 | Select today's class | Student roster visible | 2 |
| 3 | Mark present / absent for 2–3 students | State updates locally | 3 |
| 4 | Submit / save (if shown) | Success or API message | 4 |
| 5 | Back to dashboard | Summary reflects activity | 5 |

### Homework journey (~8 min)

| Step | Action | Expected | Taps |
|------|--------|----------|-----:|
| 1 | Dashboard → **Homework** | Assignment list | 1 |
| 2 | Open one assignment | Detail view | 2 |
| 3 | Return to list | State preserved | 3 |
| 4 | Dashboard → today schedule | Class times match seeded data | 2 |

### Lesson logs journey (~8 min)

| Step | Action | Expected | Taps |
|------|--------|----------|-----:|
| 1 | Navigate to **School completion** / lesson logs | List or entry form | 2–3 |
| 2 | View existing log entry | Topic + class visible | +1 |
| 3 | (Optional) Create draft entry | Form accepts input | +2 |

> If 403 on lesson logs, report with role `Teacher` — may be RBAC on staging token.

---

## Parent

**Login:** `9000100001` · **Surface:** Parent mobile

### Attendance journey (~5 min)

| Step | Action | Expected | Taps |
|------|--------|----------|-----:|
| 1 | Dashboard → child summary chips | Attendance % or status | 0 |
| 2 | Open **Attendance** | Monthly calendar / summary | 1 |
| 3 | Change month (if available) | Data or empty state | 2 |

### Fees journey (~5 min)

| Step | Action | Expected | Taps |
|------|--------|----------|-----:|
| 1 | Dashboard → fee / payment chip | Outstanding hint on dashboard | 0 |
| 2 | Open **Fees** or payment section | Invoice list or balance | 1–2 |
| 3 | View one invoice detail | Amount, due date | +1 |

### Progress journey (~8 min)

| Step | Action | Expected | Taps |
|------|--------|----------|-----:|
| 1 | Dashboard → **Experience hub** | Homework + exam readiness | 1 |
| 2 | View academic summary card | Grades or progress text | 0–1 |
| 3 | Open **Notifications** | Messages from school | 2 |
| 4 | Child switcher (if multi-child) | Second child loads | +1 |

---

## Student

**Login:** `9876543212` or mock **Student** + OTP `123456` · **Surface:** Student mobile

### Homework journey (~5 min)

| Step | Action | Expected | Taps |
|------|--------|----------|-----:|
| 1 | Dashboard → homework due list | Assignments with dates | 0 |
| 2 | Open **Homework** tab | Full list | 1 |
| 3 | Open one item | Subject, due date, status | 2 |

### Exams journey (~5 min)

| Step | Action | Expected | Taps |
|------|--------|----------|-----:|
| 1 | Dashboard → exams shortcut | Upcoming exam card | 1 |
| 2 | Open **Exams** | Paper list | 1 |
| 3 | View one exam | Title, date | 2 |

### Timetable journey (~5 min)

| Step | Action | Expected | Taps |
|------|--------|----------|-----:|
| 1 | Dashboard → schedule strip | Today's periods | 0 |
| 2 | Open **Timetable** | Weekly grid or list | 1 |
| 3 | Swipe / scroll week | All days accessible | 2 |

---

## Cross-role smoke (coordinator)

Run once per build before distributing to friends:

| # | Journey | Account |
|---|---------|---------|
| 1 | Principal daily (steps 1–4) | `9876543210` |
| 2 | Teacher attendance | `9000000001` |
| 3 | Parent fees + attendance | `9000100001` |
| 4 | Student homework + timetable | `9876543212` |
| 5 | Logout → re-login each | All four |

---

## Journey success criteria

| Criterion | Threshold |
|-----------|-------------|
| Login success rate | 100% with staging OTP |
| Dashboard load | < 5 seconds on 4G |
| Navigation dead ends | 0 in journeys above |
| Crash rate | 0 during journey |
| Overflow / layout break | 0 on assigned device |

---

## Reference

- Android pack: [Android-Tester-Pack.md](Android-Tester-Pack.md)
- iPhone pack: [iPhone-Tester-Pack.md](iPhone-Tester-Pack.md)
- Bug triage: [Bug-Triage-Process.md](Bug-Triage-Process.md)
