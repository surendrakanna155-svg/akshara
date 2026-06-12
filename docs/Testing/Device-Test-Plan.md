# Device Test Plan — Akshara ERP Pilot

**Version:** v16.7  
**Build:** 16.6.0 (166)  
**Scope:** Real-device validation before pilot school rollout

---

## Test matrix overview

| Platform | Devices | Testers | Priority |
|----------|---------|---------|----------|
| Android phone | 360–428 dp width | Friends, internal | P0 |
| Android tablet | 768–1024 dp | Internal | P1 |
| iPhone | 14/15/16 series + SE | Friends (TestFlight) | P0 |
| iPad | 10.9" / 11" | Internal | P1 |

---

## Android tests

### A1 — Install & launch

| # | Step | Expected |
|---|------|----------|
| A1.1 | Sideload `app-release.apk` | Installs without error |
| A1.2 | Open app | Splash → login, no debug banner |
| A1.3 | Check version | About shows 16.6.0 |

### A2 — Login

| # | Step | Expected |
|---|------|----------|
| A2.1 | Enter parent phone `9000100001` | OTP sent / dev OTP shown |
| A2.2 | Verify OTP | Parent dashboard loads |
| A2.3 | Logout → teacher login `9000000001` | Teacher dashboard loads |
| A2.4 | Airplane mode → mock login `123456` | Graceful fallback or clear error |

### A3 — Attendance

| Persona | Steps | Expected |
|---------|-------|----------|
| Teacher | Dashboard → Attendance → mark class | Saves or shows API error with retry |
| Parent | Dashboard → Attendance | Monthly view or empty state |
| Student | Dashboard → Attendance | Own record visible |

### A4 — Homework

| Persona | Steps | Expected |
|---------|-------|----------|
| Teacher | Homework list → open item | Detail loads, no overflow |
| Parent | Experience hub / homework | Assignments listed |
| Student | Homework tab | Due items with dates |

### A5 — Fees

| Persona | Steps | Expected |
|---------|-------|----------|
| Parent | Fees / payment status | Outstanding or paid summary |
| Principal | Finance dashboard | KPIs, defaulter cards |

### A6 — Inventory

| Persona | Steps | Expected |
|---------|-------|----------|
| Principal | Inventory dashboard | Distribution stats |
| Parent | Book kit (if linked) | Status or empty state |

### A7 — Intelligence

| Persona | Steps | Expected |
|---------|-------|----------|
| Principal | Intelligence hub tabs | Summary, health, risks load |
| Principal | Management dashboard | KPI row renders |

### A8 — Reports

| Persona | Steps | Expected |
|---------|-------|----------|
| Principal | Finance reports / executive | Charts or tables, export action |
| Principal | Admissions reports | Pipeline data |

---

## iPhone tests

### I1 — Safe area & notch

| # | Check | Expected |
|---|-------|----------|
| I1.1 | Login screen on notched device | No content under notch/Dynamic Island |
| I1.2 | Dashboard app bar | Title and actions fully visible |
| I1.3 | Bottom navigation (mobile) | Tabs above home indicator |

### I2 — Dynamic Island / status bar

| # | Check | Expected |
|---|-------|----------|
| I2.1 | Light status bar icons | Readable on light background |
| I2.2 | In-call / hotspot | Layout stable (no overlap) |

### I3 — Keyboard

| # | Check | Expected |
|---|-------|----------|
| I3.1 | Phone input on login | Numeric keyboard, done dismisses |
| I3.2 | OTP fields | Auto-advance or single field |
| I3.3 | Search fields (ERP) | Keyboard doesn't hide submit |

### I4 — Navigation

| # | Check | Expected |
|---|-------|----------|
| I4.1 | Tab switching | No lost state / flash |
| I4.2 | Back gesture | Returns to previous screen |
| I4.3 | Deep link from dashboard action | Correct screen, no dead end |

### I5 — Scrolling

| # | Check | Expected |
|---|-------|----------|
| I5.1 | Long dashboard scroll | Smooth, no jank |
| I5.2 | Student/parent lists | Momentum scroll works |
| I5.3 | Pull at list end | No overflow exception |

### I6 — Typography & accessibility

| # | Check | Expected |
|---|-------|----------|
| I6.1 | Settings → Larger Text (125%) | Layout usable, no clip |
| I6.2 | Settings → Larger Text (200%) | Critical actions reachable |
| I6.3 | Bold text enabled | Labels remain readable |

### I7 — Orientation

| # | Check | Expected |
|---|-------|----------|
| I7.1 | Portrait → landscape (dashboard) | Reflows, no overflow |
| I7.2 | Landscape → portrait | State preserved |

---

## Tablet tests

### T1 — Layout

| # | Check | Expected |
|---|-------|----------|
| T1.1 | Parent dashboard 834×1194 | Two-column or widened content |
| T1.2 | Teacher dashboard tablet | Schedule card readable |
| T1.3 | ERP finance dashboard | KPI grid uses width |

### T2 — Split views

| # | Check | Expected |
|---|-------|----------|
| T2.1 | ERP sidebar + content | Both panes visible |
| T2.2 | Resize split (iPad) | Content adapts |

### T3 — Large tables

| # | Check | Expected |
|---|-------|----------|
| T3.1 | SIS student list (500 rows) | Horizontal scroll if needed |
| T3.2 | Finance defaulters table | Columns aligned, ellipsis on long names |
| T3.3 | Admissions pipeline | No clipped action buttons |

---

## Regression smoke (all platforms)

Run after each build:

- [ ] Login → dashboard for each persona
- [ ] Logout → login again
- [ ] Rotate once on dashboard
- [ ] Toggle airplane mode → verify error message
- [ ] Force-quit → relaunch → session restore or login

---

## Sign-off

| Role | Name | Date | Build | Pass/Fail |
|------|------|------|-------|-----------|
| Android lead | | | 16.6.0+166 | |
| iOS lead | | | 16.6.0+166 | |
| QA | | | 16.6.0+166 | |
| Product | | | 16.6.0+166 | |

---

## Reference

- Demo accounts: `docs/Testing/Demo-Accounts.md`
- Bug template: `docs/Testing/Bug-Report-Template.md`
- Tester instructions: `docs/Testing/Tester-Instructions.md`
