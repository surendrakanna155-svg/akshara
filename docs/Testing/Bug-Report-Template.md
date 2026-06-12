# Bug Report Template — Akshara Pilot

Copy this template for each issue found during device testing.

---

## Standard format

```
Device:
Role:
Screen:
Issue:
Expected:
Actual:
Severity:
Screenshot:
```

### Field guide

| Field | Example |
|-------|---------|
| **Device** | Samsung Galaxy A54, Android 14 / iPhone 15 Pro, iOS 18.2 |
| **Role** | Parent / Teacher / Student / Principal |
| **Screen** | Parent Dashboard → Fees tab |
| **Issue** | One-line summary |
| **Expected** | Fee balance shows ₹12,500 outstanding |
| **Actual** | Blank white area, no error message |
| **Severity** | Blocker / Major / Minor / Cosmetic |
| **Screenshot** | Attach file or link |

### Severity definitions

| Level | Definition |
|-------|------------|
| **Blocker** | Cannot login, crash on launch, data loss |
| **Major** | Core workflow broken (attendance, fees, homework) |
| **Minor** | Workaround exists; UX defect |
| **Cosmetic** | Visual only; no functional impact |

---

## Spreadsheet-ready format (TSV)

Copy the header row into Google Sheets / Excel:

```
ID	Build	Device	OS	Role	Screen	Issue	Expected	Actual	Severity	Reporter	Date	Screenshot URL	Status
```

Example row:

```
BUG-001	16.6.0+166	Samsung A54	Android 14	Parent	Fees tab	Fee balance missing	Show outstanding amount	Empty panel	Major	Ravi K	2026-06-12	drive.link/open	MOpen
```

---

## CSV header (import-ready)

```csv
ID,Build,Device,OS,Role,Screen,Issue,Expected,Actual,Severity,Reporter,Date,Screenshot URL,Status
```

---

## Submission

1. File bugs in your tracker **or** save to `reports/pilot_validation/bugs/` as `BUG-NNN.md`
2. Include **build number** (16.6.0 build 166) from app About / install manifest
3. Attach screenshot or screen recording
4. Note **network state** (Wi‑Fi / 4G / offline)
5. Note **account phone** used (never share OTP)

---

## Quick checklist before filing

- [ ] Reproduced twice
- [ ] Tried logout/login
- [ ] Confirmed not airplane mode (unless testing offline)
- [ ] Checked correct persona account
- [ ] Screenshot includes status bar (shows time/battery for context)
