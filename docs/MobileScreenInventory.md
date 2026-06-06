# Akshara ERP — Mobile Screen Inventory (Master)

**Document ID:** `AKS-MOBILE-INV-v1.0`  
**Purpose:** Consolidated `[M]` frame catalog for all mobile surfaces (AR-022)  
**Frame preset:** `390×844` unless noted · Margin `16` · Content `358`

---

## 1. Native Mobile Apps

### Parent App — `Parent.md`

| ID | Frame | Bottom nav | Priority |
|----|-------|------------|----------|
| P-01 | Splash-M | — | P0 |
| P-02 | Language-M | — | P0 |
| P-03 | Login-M | — | P0 |
| P-04 | Dashboard-M | Home | P0 |
| P-05 | ChildSelector-M | overlay | P0 |
| P-06 | Attendance-M | Academics | P0 |
| P-07 | HomeworkList-M | Academics | P0 |
| P-08 | HomeworkDetail-M | push | P0 |
| P-09 | Fees-M | Fees | P0 |
| P-10 | FeePayment-M | push | P0 |
| P-11 | Receipt-M | push | P0 |
| P-12 | ReportCards-M | Academics | P0 |
| P-13 | Messages-M | Messages | P0 |
| P-14 | Thread-M | push | P0 |
| P-15 | BusTracking-M | More | P1 |
| P-16 | Certificates-M | More | P1 |
| P-17 | Events-M | More | P1 |
| P-18 | Notifications-M | AppBar | P0 |
| P-19 | Discipline-M | More | P1 |
| P-20 | PTMBooking-M | More | P1 |
| P-21 | Onboarding-M | wizard | P0 |
| P-22 | AICopilot-M | AppBar | P1 |
| P-23 | Profile-M | More | P0 |
| P-24 | Settings-M | More | P0 |
| P-25 | More-M | More | P0 |

### Student App — `Student.md`

| ID | Frame | Tab | Priority |
|----|-------|-----|----------|
| S-01–S-03 | Splash/Language/Login-M | — | P0 |
| S-04 | Dashboard-M | Home | P0 |
| S-05 | Attendance-M | — | P0 |
| S-06 | HomeworkList-M | Learn | P0 |
| S-07 | HomeworkSubmit-M | push | P0 |
| S-08 | Assignments-M | Learn | P1 |
| S-09 | Timetable-M | Schedule | P0 |
| S-10 | OnlineClass-M | push | P1 |
| S-11 | PracticePapers-M | Learn | P1 |
| S-12 | ExamResults-M | Results | P0 |
| S-13 | ReportCards-M | push | P0 |
| S-14 | BusTracking-M | More | P1 |
| S-15 | Notifications-M | — | P0 |
| S-16 | Gallery-M | More | P2 |
| S-17 | Events-M | More | P1 |
| S-18 | AIAssistant-M | AppBar | P1 |
| S-19 | Profile-M | More | P0 |
| S-20 | Settings-M | More | P0 |

### Teacher App — `Teacher.md`

| ID | Frame | Tab | Priority |
|----|-------|-----|----------|
| T-01–T-03 | Splash/Language/Login-M | — | P0 |
| T-04 | Dashboard-M | Home | P0 |
| T-05 | StaffCheckIn-M | push | P0 |
| T-06 | MarkAttendance-M | Classes | P0 |
| T-07 | AttendanceSummary-M | push | P0 |
| T-08 | CreateHomework-M | Teach | P0 |
| T-09 | HomeworkList-M | Teach | P0 |
| T-10 | Assignments-M | Teach | P1 |
| T-11 | EnterMarks-M | More | P0 |
| T-12 | Timetable-M | More | P0 |
| T-13 | Messages-M | Messages | P0 |
| T-14 | Thread-M | push | P0 |
| T-15 | LeaveApply-M | More | P0 |
| T-16 | LeaveStatus-M | More | P0 |
| T-17 | AIAssistant-M | AppBar | P1 |
| T-18 | Notifications-M | — | P0 |
| T-19 | ClassDashboard-M | card | P1 |
| T-20 | StudentList-M | push | P1 |
| T-21 | ClassAnalytics-M | push | P1 |
| T-22 | BehaviourLog-M | push | P1 |

### Alumni App — `Alumni.md`

| ID | Frame | Tab | Priority |
|----|-------|-----|----------|
| AL-M-01 | Login-M | — | P2 |
| AL-M-02 | Dashboard-M | Home | P2 |
| AL-M-03 | Profile-M | More | P2 |
| AL-M-04 | Events-M | Events | P2 |
| AL-M-05 | Donate-M | Donate | P2 |
| AL-M-06 | Stories-M | More | P3 |
| AL-M-07 | Network-M | Network | P3 |
| AL-M-08 | Notifications-M | — | P2 |

---

## 2. Admin Module Mobile Companions

Reduced-column layouts · bottom sheets · FABs · drawer nav instead of 256px rail.

| Module | Mobile frames | Key flows |
|--------|---------------|-----------|
| Finance | FN-*-M (11) | FN-02 record cash · FN-03 defaulter call |
| Management | MG-*-M (8) | MG-03 approve bottom sheet |
| Admissions | AD-*-M (6) | AD-03 enquiry drawer · AD-04 pipeline scroll |
| Transport | TR-M-01–04 | TR-M-03 driver GPS · TR-M-04 delay broadcast |
| Hostel | HO-M-01–04 | HO-M-02 roster attendance · HO-M-04 gate pass QR |
| HR | HR-M-01–03 | HR-M-02 leave approve |
| Library | LB-M-01–04 | Barcode scan issue/return |
| Inventory | INV-M-01–03 | Asset QR scan |

### Transport Mobile — `Transport.md`

| ID | Screen | User |
|----|--------|------|
| TR-M-01 | Coordinator Dashboard | Transport coord |
| TR-M-02 | Live Map | Transport coord |
| TR-M-03 | Driver Check-in | Driver |
| TR-M-04 | Broadcast Delay | Transport coord |

### Hostel Mobile — `Hostel.md`

| ID | Screen | User |
|----|--------|------|
| HO-M-01 | Warden Dashboard | Warden |
| HO-M-02 | Session Attendance | Warden |
| HO-M-03 | Visitor QR Scan | Warden |
| HO-M-04 | Gate Pass View | Parent |

---

## 3. Mobile UX Rules (All Apps)

| Rule | Value |
|------|-------|
| Bottom nav height | `80` + safe area |
| AppBar | `56` |
| Min touch target | `48×48` |
| Primary actions | FAB or sticky bottom CTA |
| Tables | Card list fallback under `390` width |
| Filters | Bottom sheet · not 56px desktop filter bar |
| Dialogs | Fullscreen sheet on mobile |
| Offline banner | DesignSystem `Feedback/Banner` |

---

## 4. Figma Folder Map

```
📁 01 Parent App      → P-*-M
📁 02 Student App     → S-*-M
📁 03 Teacher App     → T-*-M
📁 04 Management      → MG-*-M (companion)
📁 05 Hostel          → HO-*-M
📁 06 Transport       → TR-*-M
📁 07 Admissions      → AD-*-M
📁 08 Finance         → FN-*-M
📁 09 HR              → HR-*-M
📁 11 Library         → LB-*-M
📁 12 Inventory       → INV-*-M
📁 13 Alumni          → AL-M-*
```

---

## 5. Build Priority

| Wave | Apps |
|------|------|
| Wave 1 | Parent P-03–P-18 · Teacher T-03–T-18 · Student S-03–S-15 |
| Wave 2 | Admin companions TR-M, HO-M, FN-M |
| Wave 3 | Alumni AL-M · Library LB-M · Inventory INV-M |

---

**End of Mobile Screen Inventory v1.0**
