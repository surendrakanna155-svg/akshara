# Pilot Issue Tracker

**Version:** 1.0  
**Branch:** `production` (feature freeze — no new milestones)  
**Last updated:** 2026-06-10

---

## Purpose

Single source of truth for defects and operational fixes discovered during the v1.0 pilot.  
Only in-scope work is logged here: pilot bugs, onboarding/import, OTP/auth, attendance/fees/notifications/timetable, and deployment/configuration.

**Out of scope:** new modules, v7.8+ milestones, CRM, franchise, or feature requests unless explicitly approved.

---

## How to use

1. **Open an issue** when a school or ops run surfaces a defect (staging smoke, onboarding, or production pilot).
2. Assign the next **Issue ID** (`PILOT-YYYY-NNN`, sequential within the calendar year).
3. Fill all fields below before starting a fix.
4. After merge, set **Fix Commit** (full SHA or `pending`) and **Verification Status**.
5. Update the summary counts at the bottom of this file.

### Severity

| Level | When to use |
|-------|-------------|
| **Critical** | Production down, data loss, auth bypass, payment/compliance block |
| **High** | Core workflow blocked (enrollment, fees, attendance, OTP login) |
| **Medium** | Workaround exists; UX or partial module failure |
| **Low** | Cosmetic, copy, non-blocking edge case |

### Verification status

| Status | Meaning |
|--------|---------|
| **Open** | Reported; not yet fixed |
| **In progress** | Fix branch or PR active |
| **Fixed — pending verify** | Commit landed; awaiting staging/pilot re-test |
| **Verified** | Repro steps pass on target environment |
| **Won't fix (pilot)** | Accepted risk; documented reason in Root Cause |

---

## Issue log

| Issue ID | Date | School | Module | Severity | Reproduction Steps | Root Cause | Fix Commit | Verification Status |
|----------|------|--------|--------|----------|-------------------|------------|------------|---------------------|
| — | — | — | — | — | *No school-reported pilot issues logged yet.* | — | — | — |

---

## Issue detail (expand rows above as needed)

<!--
Copy this block when adding an issue with long reproduction steps or root-cause notes.

### PILOT-2026-001

| Field | Value |
|-------|-------|
| **Date** | YYYY-MM-DD |
| **School** | School name or `Operations` / `All tenants` |
| **Module** | e.g. Auth, Onboarding, Finance, Attendance, Deployment |
| **Severity** | Critical / High / Medium / Low |

**Reproduction steps**

1. …
2. …

**Root cause**

…

**Fix commit:** `abc1234` or `pending`

**Verification:** Open / In progress / Fixed — pending verify / Verified / Won't fix (pilot)

**Verified by:** name/script/date (e.g. `./scripts/pilot_staging_verify.sh` on staging)
-->

---

## Summary

| Metric | Count |
|--------|------:|
| Total issues | 0 |
| Open | 0 |
| In progress | 0 |
| Fixed — pending verify | 0 |
| Verified | 0 |
| Won't fix (pilot) | 0 |

### By severity (open + in progress)

| Critical | High | Medium | Low |
|--------:|-----:|-------:|----:|
| 0 | 0 | 0 | 0 |

---

## Related runbooks

- [Pilot Onboarding Runbook](./Pilot-Onboarding-Runbook.md)
- [SaaS Launch Checklist](./SaaS-Launch-Checklist.md)
- [Rollout Checklist](./Rollout-Checklist.md)
- [Rollback Checklist](./Rollback-Checklist.md)
- [Production Integrations](./Production-Integrations.md)
