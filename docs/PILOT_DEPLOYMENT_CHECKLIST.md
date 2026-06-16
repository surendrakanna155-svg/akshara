# Pilot Deployment Checklist — Akshara v1.0

**Program:** Release Candidate — Pilot Readiness  
**Branch:** `release/v1.0-preprod`  
**Date:** June 2026  
**Question:** Can each persona operate Akshara for a full academic year?

---

## Verdict matrix

| Persona | Classification | Academic-year viable? |
|---------|----------------|----------------------|
| **Owner** | Ready with Conditions | Yes (mock/staging) |
| **Director** | Ready with Conditions | Yes (portfolio mock) |
| **Principal** | Ready | Yes |
| **Teacher** | Ready | Yes |
| **Parent** | Ready | Yes |
| **Student** | Ready | Yes |
| **Finance** | Ready | Yes |
| **HR** | Ready | Yes |

**Overall pilot:** **Ready with Conditions** — single-school, mock or staging backend, PI1 signed.

---

## Persona evidence

### Owner

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Management dashboard + KPIs | ✅ | Golden + stress tests |
| Multi-school portfolio | ✅ | `multi_school_portfolio_screen_test` |
| Approvals + exports | ✅ | `management_approval_e2e`, export e2e |
| Live multi-tenant SaaS | ⚠️ | RLS partial — single-tenant pilot only |

### Director

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Portfolio overview + trust metrics | ✅ | Director dashboard RC polish |
| Cross-school reports | ✅ | Director Patrol workflows |
| Production director API | ⚠️ | Mock/staging |

### Principal

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Daily priorities + approvals | ✅ | `ManagementPrincipalOverviewPanel` |
| Alert center | ✅ | Fee defaulter + approval banners |
| SIS / finance quick actions | ✅ | `principal_workflows_test` Patrol |
| Intelligence drill-down | ✅ | Management intelligence routes |

### Teacher

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Class workload dashboard | ✅ | Teacher golden + stress |
| Attendance + grading | ✅ | `teacher_workflows_test`, attendance e2e |
| Intervention queue | ✅ | Teacher module screens |
| Mobile navigation | ✅ | `teacher_navigation_pilot_test` |

### Parent

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Today's overview + hero | ✅ | Parent golden + RC hero card |
| Homework + fees + attendance | ✅ | Parent dashboard provider tests |
| Experience hub | ✅ | Parent feature tests |
| Patrol mobile journeys | ✅ | `parent_workflows_test` |

### Student

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Timetable + homework | ✅ | Student dashboard tests |
| Performance + notices | ✅ | Student module screens |
| AI study insight | ✅ | `AksharaInsightCard` on dashboard |

### Finance

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Fee structures → collection | ✅ | `finance_full_journey_e2e` |
| Defaulters + refunds | ✅ | Finance phase 2 tests (RC KPI fix) |
| PO / reconciliation | ✅ | Finance Patrol suites |
| Live payment gateway | ⚠️ | QR/offline mock OK for pilot |

### HR

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Employee CRUD | ✅ | `hr_employee_crud_e2e` |
| Leave + payroll | ✅ | `hr_leave_e2e`, `hr_payroll_e2e` |
| Attendance | ✅ | HR workflows Patrol |

---

## Academic-year workflows

| Workflow | Status | Evidence |
|----------|--------|----------|
| Admissions → enrollment → SIS | ✅ | E2E journeys (enrollment sticky actions RC) |
| Promote / reshuffle | ✅ | `sis_academic_operations_e2e` |
| Fee assignment → collection | ✅ | Finance full journey |
| Year rollover | ✅ | `continuity_e2e_test` |
| HR payroll cycle | ✅ | HR payroll e2e |

---

## Pre-go-live checklist

| # | Item | Owner | Done? |
|---|------|-------|-------|
| 1 | `flutter analyze` = 0 | Dev | ✅ |
| 2 | `flutter test` all pass | Dev | ✅ (1688) |
| 3 | Patrol full certification stable | QA | 🔄 In progress |
| 4 | PI1 `PilotSchoolChecklist.md` signed | Operations | ☐ |
| 5 | Mock mode (`ENABLE_API_MODE=false`) OR staging | DevOps | ☐ |
| 6 | Demo OTP disabled for real PII | Backend | ☐ |
| 7 | Support + restore runbook acknowledged | Operations | ☐ |
| 8 | Single-tenant scope agreed | Product | ☐ |

---

## Not ready (without additional work)

- Multi-tenant production SaaS at scale  
- Public internet without pen test  
- Real payment gateway production  
- GA without backup restore drill (B2)

---

## References

- `docs/PILOT_SIGNOFF_REPORT.md`
- `docs/WORKFLOW_CERTIFICATION_REPORT.md`
- `docs/PilotSchoolChecklist.md`
- `docs/PRODUCTION_HARDENING_REPORT.md`
