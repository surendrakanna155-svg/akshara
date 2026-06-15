# Pilot Readiness Report — Release v1.0-preprod

**Date:** June 2026  
**Question:** Can a real school operate on Akshara for a full academic year?

---

## Verdict: **Ready with Conditions**

A school can operate on Akshara for a full academic year **in pilot mode** (demo/mock API or staging backend with known limitations). Production SaaS GA requires infrastructure blockers to close.

---

## Evidence

### Academic year workflows ✅

| Term activity | Application support | Test evidence |
|---------------|--------------------|--------------| 
| Admissions & enrollment | Full workflow | Patrol `admissions_e2e_journey` |
| Student records (SIS) | Full read/write mock | Contract + `sis_workflows` |
| Promotion / reshuffle | M1 complete | `sis_academic_operations_e2e` |
| Fee plans & collection | Finance module | `finance_full_journey_e2e` |
| Attendance & academics | Education + SIS | Widget + integration tests |
| HR (staff, leave, payroll) | Full module | HR Patrol suites |
| Transport | Routes, allocation | `transport_*` e2e |
| Hostel | Allocation, mess, leave | `hostel_*` workflows |
| Library | Issue/return | `library_issue_return_e2e` |
| Inventory | PO, lifecycle | `inventory_*` e2e |
| Year rollover / continuity | M2 complete | `continuity_e2e_test` |
| Intelligence & AI copilot | M8 complete | AI Patrol suites |
| Parent / teacher / student apps | Mobile shells | Mobile stress tests |

### Operations & governance ✅

| Capability | Status |
|------------|--------|
| Management approvals | Verified |
| Principal workflows | Patrol |
| Audit logging (client) | Shipped |
| RBAC per role | 120+ routes guarded |
| Pilot dashboard | `viewPilotDashboard` |

### Not required for single-school pilot

- Multi-school portfolio (available if chain pilot)
- Industry vertical packs (salon/hospital/restaurant)
- White label (optional)

---

## Conditions for pilot

| # | Condition | Owner |
|---|-----------|-------|
| 1 | Deploy with `ENABLE_API_MODE=false` (mock) OR staging API with write parity for admissions/finance/SIS | DevOps |
| 2 | Disable demo OTP before any real PII (A9) | Backend |
| 3 | Run `ERP_COVERAGE_MODE=full` Patrol on CI before go-live | QA |
| 4 | Pilot school checklist (PI1) signed | Operations |
| 5 | Backup / support runbook acknowledged | Operations |
| 6 | Known limitation: live RLS not GA — single-tenant pilot only | Product |

---

## Not ready for (without infra)

- Multi-tenant production SaaS at scale
- Real payment gateway production (QR/offline mock OK for pilot)
- Pen-test-certified public internet deployment
- Multi-school chain without staging API

---

## Pilot deployment profile

```
Environment:  Staging or demo-mode production
Tenant:       Single school
Users:        Admin, teachers, parents, students
Data:         Mock repositories OR staging API
Duration:     Full academic year (2026–27)
Rollback:     Documented (D6 ✅)
```

---

## Recommendation

**Approve school pilot** under conditions above. Schedule infrastructure program in parallel for GA.
