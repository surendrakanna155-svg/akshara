# Autonomous QA Backlog — Akshara ERP v18.7+

**Updated:** 13 June 2026 (Continuous mode — Cycle 3 complete)  
**Baseline:** Fee collection E2E live; E2E ~47%; production readiness ~92%

---

## Priority legend

| Tier | Meaning |
|------|---------|
| **P0** | Missing business journey (write + cross-module assert) |
| **P1** | Missing mutation/write validation (integration or Patrol write) |
| **P2** | Missing RBAC validation on journeys |
| **P3** | Missing navigation/render coverage |

Ranked by: production risk → user impact → QA confidence gain.

---

## P0 — Business journeys

| ID | Item | Journey | Status | Blocker | Agent |
|----|------|---------|--------|---------|-------|
| P0-1 | Lead → SIS registry E2E | Admission | **DONE** | — | A |
| P0-2 | Approved → finance handoff → fee account | Admission + Fee | **DONE** | — | A + B |
| P0-3 | Teacher mark → submit → persisted | Attendance | **DONE** (integration) | Parent chain static | C |
| P0-4 | Fee collection → receipt | Fee | **DONE** | — | B |
| P0-5 | ERP academic attendance chain | Attendance | **BLOCKED** | No ERP admin attendance write module | C |
| P0-6 | Exam creation / marks (ERP) | Exam | **BLOCKED** | Product scope — no ERP exam admin | — |
| P0-7 | HR hire / leave workflow | HR | **BLOCKED** | No mutation providers | C |
| P0-8 | Inventory stock write | Inventory | **BLOCKED** | No mutation providers | D |
| P0-9 | Transport route create | Transport | **BLOCKED** | No mutation providers | D |

---

## P1 — Mutation / write validation

| ID | Item | Module | Status | Agent |
|----|------|--------|--------|-------|
| P1-1 | Mock approve → handoff sync | Admissions mock | **DONE** | A |
| P1-2 | Integration: admission → finance assign | Cross-module | **DONE** | A + B |
| P1-3 | Integration: teacher attendance submit | Teacher | **DONE** | C |
| P1-4 | Patrol: fee assignment write | Finance | **DONE** | B |
| P1-5 | Admission RBAC deny integration | Admissions | QUEUED | A |
| P1-7 | createCollection provider + RBAC | Finance | **DONE** | B |
| P1-8 | Integration assign → collect → receipt | Cross-module | **DONE** | B |
| P1-9 | Patrol fee collection write | Finance | **DONE** | B |

---

## P2 — RBAC validation

| ID | Item | Persona | Status |
|----|------|---------|--------|
| P2-1 | Counselor cannot approve admission (provider) | admissionsCounselor | **DONE** |
| P2-2 | Inventory role cannot assign fee plan | inventoryManager | **DONE** |
| P2-3 | Admissions clerk lead create deny | admissions clerk | QUEUED |

---

## P3 — Navigation / render

| ID | Item | Status |
|----|------|--------|
| P3-1 | Intelligence/copilot screens Patrol | OPEN |
| P3-2 | Maestro write assertions (118 YAML) | OPEN |
| P3-3 | SIS export file assertion | OPEN |
| P3-4 | HR / transport write Patrol smoke | OPEN |

---

## Coverage targets

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| E2E journey coverage (7 journeys) | **~47%** | 60% | +13 pts |
| Production readiness | **~92%** | 95% | +3 pts |
| P0 items complete | **4/9** | 9/9 | 5 product-blocked |

---

## Execution order (Coordinator)

1. P1-1 + P1-2 — mock handoff sync + admission→finance integration  
2. P1-3 — teacher attendance integration  
3. P1-4 — finance fee assignment Patrol E2E  
4. P2-1 — admission RBAC deny Patrol variant  
5. P0-4 — finance collection UI (feature — defer until product assigns)
