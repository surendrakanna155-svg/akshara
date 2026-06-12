# iPhone Tester Pack — Akshara ERP Pilot

**Build:** 16.6.0 (166) via **TestFlight**  
**Environment:** Staging demo school  
**Time required:** 20–30 minutes

> **Note for coordinators:** TestFlight build must be uploaded first. See [iOS-Execution-Checklist.md](iOS-Execution-Checklist.md).

---

## What you need

- iPhone (iOS 15+ recommended; iOS 13 minimum)
- **TestFlight** app (App Store)
- Invite email or public link from Akshara team
- Wi‑Fi or mobile data

---

## 1. Install via TestFlight

1. Install **TestFlight** from the App Store (if needed).
2. Open the **invite email** from Akshara → **View in TestFlight**.
   - Or tap the **public link** shared by coordinator.
3. Tap **Install** on **Akshara ERP**.
4. Open the app from TestFlight or home screen.

**Verify:** No DEBUG banner on launch.

### First-time TestFlight tips

- Builds expire after ~90 days — reinstall when team sends update.
- Send feedback via TestFlight **Send Beta Feedback** (optional).

---

## 2. Login

Same staging accounts as Android:

| Your role | Phone number |
|-----------|--------------|
| Parent | `9000100001` |
| Teacher | `9000000001` |
| Principal | `9876543210` |
| Student | `9876543212` |

1. Enter phone → **Send OTP** → verify.
2. Land on role dashboard.

**Backup (offline demo):** Role selector + OTP `123456`.

---

## 3. Test scenarios

### iPhone-specific checks (all roles)

| # | Check | Pass if… |
|---|-------|----------|
| I1 | Notch / Dynamic Island | App bar not clipped |
| I2 | Home indicator area | Bottom nav fully visible |
| I3 | Keyboard on login | Numeric pad; dismiss works |
| I4 | Swipe back | Returns to previous screen |
| I5 | Scroll dashboard | Smooth, no freeze |

### Parent (`9000100001`)

| # | Action | Pass if… |
|---|--------|----------|
| P1 | Dashboard | Child context visible |
| P2 | Attendance | Data or friendly empty state |
| P3 | Fees | Payment status shown |
| P4 | Experience hub | Loads without crash |

### Teacher (`9000000001`)

| # | Action | Pass if… |
|---|--------|----------|
| T1 | Dashboard | Schedule + attendance summary |
| T2 | Attendance | Class view opens |
| T3 | Homework | List loads |

### Student (`9876543212`)

| # | Action | Pass if… |
|---|--------|----------|
| S1 | Homework | Assignments listed |
| S2 | Timetable | Weekly view |
| S3 | Exams | Upcoming papers |

### Principal (`9876543210`)

Use iPad if available; iPhone in landscape acceptable.

| # | Action | Pass if… |
|---|--------|----------|
| A1 | Management dashboard | KPIs render |
| A2 | Intelligence hub | Tabs switch cleanly |

Full matrix: [Device-Test-Plan.md](Device-Test-Plan.md)

---

## 4. Bug reporting

1. **Screenshot:** Volume Up + Side button.
2. Note **iPhone model** and **iOS version** (Settings → General → About).
3. Use [Bug-Report-Template.md](Bug-Report-Template.md).
4. Optional: TestFlight → Akshara ERP → **Send Beta Feedback**.
5. Send to coordinator.

**Severity guide:** Crash on launch = Critical; feature broken = Major; visual glitch = Minor.

---

## 5. FAQ

| Question | Answer |
|----------|--------|
| No TestFlight invite | Ask coordinator; build may not be uploaded yet |
| "Unable to verify app" | Re-open invite link; ensure TestFlight installed |
| OTP not received | Ask coordinator for staging OTP or use mock `123456` |
| Layout looks cramped | Try rotation; report with screenshot |

---

## Coordinator checklist (TestFlight)

- [ ] IPA uploaded and processed in App Store Connect
- [ ] Internal test passed on at least one device
- [ ] External group created for friends/pilot
- [ ] [iOS-Execution-Checklist.md](iOS-Execution-Checklist.md) gates 5.x complete
- [ ] Testers receive this pack + assigned phone number

---

## Reference

- iOS build execution: [iOS-Execution-Checklist.md](iOS-Execution-Checklist.md)
- Demo accounts: [Demo-Accounts.md](Demo-Accounts.md)
- User journeys: [Real-User-Journeys.md](Real-User-Journeys.md)
