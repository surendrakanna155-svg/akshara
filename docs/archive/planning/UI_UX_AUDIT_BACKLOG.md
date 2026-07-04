# UI/UX Audit Backlog

**Date:** 2026-06-18  
**Program:** Continuous capture during every Patrol execution  
**Orchestrator:** [`PATROL_QA_ORCHESTRATOR.md`](./PATROL_QA_ORCHESTRATOR.md)  
**Legacy register:** `qa/patrol/reports/bugs.json`

---

## Capture categories

| Category | Examples |
|----------|----------|
| Overflow | RenderFlex, horizontal scroll clipping |
| Layout breaks | Tablet/desktop breakpoint failures |
| Theme inconsistency | M15 token drift, wrong surface colors |
| Old M15 pages | Pre-theme scaffolds |
| Missing icons | Empty `IconButton` tooltips |
| Wrong spacing | `AksharaSpacing` violations |
| Dead buttons | `onPressed: null` without explanation |
| Broken navigation | Route guard redirect loops |
| Empty states | Missing illustration/copy |
| Accessibility | Contrast, semantics, focus order |
| RBAC violations | Visible actions user cannot perform |
| Mobile / tablet / desktop | Persona-specific layout |

---

## Severity scale

| Level | Definition |
|-------|------------|
| **Critical** | Blocks workflow / data loss / security |
| **High** | Major UX break on primary path |
| **Medium** | Workaround exists; pilot friction |
| **Low** | Cosmetic / non-blocking |

---

## Open issues

| ID | Severity | Category | Screen | Description | Screenshot | Status |
|----|----------|----------|--------|-------------|------------|--------|
| UX-005 | Medium | QA infra | `/qa-login` | Maestro persona flows stall on OTP when `ENABLE_QA_LOGIN=false` | `qa/screenshots/v18_2_baseline/` | **Open** (mitigated — use QA APK) |

---

## Resolved / mitigated (carry-forward)

| ID | Severity | Category | Screen | Description | Status | Resolution |
|----|----------|----------|--------|-------------|--------|------------|
| PATROL-001 | Medium | Broken navigation | `/qa-login` | Maestro OTP stall pre-v18.3 | Mitigated | `ENABLE_QA_LOGIN=true` + Patrol persona tests |
| PATROL-002 | Low | Broken navigation | logout | Logout to `/login` vs `/qa-login` | Resolved | `confirmAndLogout` QA redirect |
| PATROL-003 | Low | RBAC | ERP drawer | Module tiles RBAC-filtered | By design | Persona-specific anchors |
| PATROL-004 | High | Theme inconsistency | Parent dashboard | Golden drift after QA banner | Resolved | Masters updated |
| UX-001 | Low | Golden | Approval center | Golden diff artifacts in `test/golden/failures/` | Open (QA) | Stale artifacts — re-run golden to clear |
| UX-002 | Medium | Empty states | Cross-module reports | HR/library/transport export preview stubs | Open | Out of day-school pilot scope |
| UX-003 | Low | Mobile | Teacher attendance | Post-submit lock UI relies on banner key | Resolved | Batch 01 Patrol green |
| UX-004 | Low | Accessibility | Approval center | Filter chips lacked QA keys | Resolved | Keys added Batch 01 |

---

## Batch 02 — resolved

| ID | Severity | Category | Screen | Resolution |
|----|----------|----------|--------|------------|
| UX-B02-01 | High | Broken navigation | Parent attendance | Host scaffold messenger + deferred dialog after sheet pop |
| UX-B02-02 | Medium | Mobile | Finance discounts | Mobile layout stacks assign button below section header |
| UX-B02-03 | Low | QA infra | Finance discounts Patrol | `scrollModuleBody` + Patrol key scroll/tap |
| UX-B02-04 | Low | Accessibility | Parent/Finance workflows | Success snackbar QA keys for Patrol assertions |
| UX-B02-05 | Medium | QA infra | `switchQaPersona` | Logout before `/qa-login` — was redirected to home while authenticated |

---

## Batch 02b — in progress

| ID | Severity | Category | Screen | Status |
|----|----------|----------|--------|--------|
| UX-B02b-01 | Medium | QA infra | Android emulator | Patrol `connectedDebugAndroidTest` flaky (0 tests / adb offline) — blocks 02b cert |

---

## Batch 01 — resolved

| ID | Severity | Category | Screen | Resolution |
|----|----------|----------|--------|------------|
| UX-B01-03 | High | Layout breaks | Exam create dialog | Grade-scoped section dropdown |
| UX-B01-01 | Low | Accessibility | Approval center | QA keys for attendance/finance/inventory filters |
| UX-B01-04 | Medium | Mobile | Parent attendance | Patrol path: date row + correction key |
| UX-003 | Low | Mobile | Teacher attendance | Post-submit lock validated — **Monitoring → Resolved** |
| UX-004 | Low | Accessibility | Approval center | Filter QA keys added — **Resolved** |

---

## Defect workflow

```
Patrol failure / visual inspection
  → Log row in this file (ID, severity, screen, screenshot path)
  → If app defect: fix in feature layer (UI/UX only per program rules)
  → Re-run affected Patrol
  → Move to Resolved with resolution note
  → Update PATROL_QA_ORCHESTRATOR.md counts
```

---

## Screenshot reference paths

| Path | Purpose |
|------|---------|
| `qa/patrol/screenshots/` | Patrol runtime markers |
| `test/golden/failures/` | Golden diff artifacts (clean up after pass) |
| `qa/screenshots/` | Maestro baseline captures |

---

*Updated: 2026-06-18 — Batch 01 execution.*
