# Android Tester Pack — NIKSHA OS Pilot

**Build:** 16.6.0 (166) · **APK size:** ~73 MB  
**Environment:** Staging demo school  
**Time required:** 20–30 minutes

---

## What you need

- Android phone or tablet (Android 8+ recommended)
- Wi‑Fi or mobile data
- APK file: `app-release.apk` (from team)
- This document

---

## 1. Install APK

1. Transfer `app-release.apk` to your phone (email, Drive, USB, or QR).
2. Open the APK file.
3. If prompted: **Settings → Allow install from this source** → enable for your file app.
4. Tap **Install**.
5. Open **NIKSHA OS**.

**Verify:** No red DEBUG banner on launch.

---

## 2. Login

### Staging login (with internet)

| Your role | Phone number |
|-----------|--------------|
| Parent | `9000100001` |
| Teacher | `9000000001` |
| Principal | `9876543210` |
| Student | `9876543212` |

1. Enter your assigned phone number.
2. Tap **Send OTP**.
3. Enter OTP (ask coordinator if not received — staging may show OTP in API logs only).
4. You should land on your role dashboard.

### Offline demo (backup only)

1. Select role on login screen.
2. OTP: `123456`
3. Principal: choose **Staff** → ERP role **Principal**.

---

## 3. Test scenarios

Complete **your role** section (15 min minimum).

### Parent (`9000100001`)

| # | Action | Pass if… |
|---|--------|----------|
| P1 | View dashboard | Child name, notices, quick actions visible |
| P2 | Open Attendance | Monthly summary or clear empty state |
| P3 | Open Fees / payment | Balance or paid status shown |
| P4 | Open Experience hub | Homework / exam section loads |
| P5 | Open Notifications | Inbox or empty message |
| P6 | Rotate phone once | No red overflow stripes |

### Teacher (`9000000001`)

| # | Action | Pass if… |
|---|--------|----------|
| T1 | View dashboard | Greeting, schedule, attendance summary |
| T2 | Open Attendance | Class list loads |
| T3 | Open Homework | Assignment list loads |
| T4 | Open Timetable | Weekly schedule visible |
| T5 | Back to dashboard | Navigation works |

### Student (`9876543212` or mock Student)

| # | Action | Pass if… |
|---|--------|----------|
| S1 | View dashboard | Schedule strip, homework due |
| S2 | Open Homework | List of assignments |
| S3 | Open Timetable | Weekly view |
| S4 | Open Exams | Upcoming papers |

### Principal (`9876543210` — tablet or large phone)

| # | Action | Pass if… |
|---|--------|----------|
| A1 | Management dashboard | KPIs load |
| A2 | Intelligence hub | Summary / risk tabs |
| A3 | Finance dashboard | Collections, defaulters |
| A4 | Global search | Find "Finance" or "Enrollment" |

Full matrix: [Device-Test-Plan.md](Device-Test-Plan.md)

---

## 4. Bug reporting

When something fails:

1. Note **device model** and **Android version** (Settings → About).
2. Note **role** and **screen** you were on.
3. Take a **screenshot**.
4. Copy template from [Bug-Report-Template.md](Bug-Report-Template.md):

```
Device: Samsung Galaxy A54, Android 14
Role: Parent
Screen: Fees tab
Issue: Blank panel after login
Expected: Fee balance visible
Actual: Empty white area, no error message
Severity: Major
Screenshot: [attach]
```

5. Send to your coordinator or shared bug folder.

**Do not share OTP codes.**

---

## 5. FAQ

| Question | Answer |
|----------|--------|
| App won't install | Enable unknown sources; confirm ~70 MB download complete |
| "Unable to load dashboard" | Check internet; tap **Try again** |
| Wrong dashboard | Logout; use correct phone for your role |
| Crash on open | Report as **Critical** with screenshot |

---

## Coordinator checklist

- [ ] APK built from tag `v16.6-release-build` or later
- [ ] Tester assigned one persona + phone
- [ ] Bug collection channel shared
- [ ] Staging API confirmed up (`demo_school_validate.py` green)

---

## Reference

- Demo accounts: [Demo-Accounts.md](Demo-Accounts.md)
- User journeys: [Real-User-Journeys.md](Real-User-Journeys.md)
- Bug triage: [Bug-Triage-Process.md](Bug-Triage-Process.md)
