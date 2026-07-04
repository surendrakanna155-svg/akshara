# Patrol Coverage Audit

**Date:** 2026-06-18  
**Branch:** `feature/m15-theme`  
**Audit type:** Continuous program — initial inventory  
**Sources:** `qa/journeys/`, `qa/patrol/journey_manifest.json`, `patrol_test/`, `test/`, `qa/maestro/`

---

## Classification legend

| Status | Criteria |
|--------|----------|
| **COVERED** | Patrol E2E + (widget or integration) for primary workflows |
| **PARTIAL** | Nav smoke or single-path Patrol; missing approval/write depth |
| **NOT TESTED** | No Patrol; ≤1 widget test or stub YAML only |

| Risk | Criteria |
|------|----------|
| **P0** | Pilot-critical: login, dashboard, nav, approvals, attendance, exams, finance, S360 |
| **P1** | Operational: HR, hostel, library, inventory, transport |
| **P2** | Deferred: marketing, director advanced, industry verticals |

---

## Module audit

### Parent (mobile)

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 14 tests · 4 files | `parent_workflows_test.dart`, receipts, meeting summary, red-team |
| Maestro YAML | 22 `biz_parent_*` | Fees, homework, leave, attendance |
| Widget tests | 17 | Providers + attendance correction unit |
| Integration | 5 (mobile/) | Parent write contracts |
| Golden | 3 viewports | `parent_dashboard_golden_test.dart` |

| Coverage % | **62%** |
| Risk | **P0** |
| Status | **PARTIAL** |

**Gaps:** Parent attendance correction Patrol submit; pay-fee full journey; published exam results after approval.

---

### Student (mobile)

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 9 tests · 2 files | `student_workflows_test.dart`, red-team |
| Maestro YAML | 13 `biz_student_*` | Home, homework, exams, notices |
| Widget tests | 8 | Profile, timetable providers |
| Integration | 1 (mobile/student) | API integration |
| Golden | 2 viewports | Student dashboard |

| Coverage % | **55%** |
| Risk | **P1** |
| Status | **PARTIAL** |

**Gaps:** Exam results post-approval; homework detail submit; settings persistence.

---

### Teacher (mobile)

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 11+ tests · 4 files | Workflows, attendance, exams, substitute, reassignment |
| Maestro YAML | 19 `biz_teacher_*` | Classes, homework, exams, attendance |
| Widget tests | 10 | Homework, leave, attendance providers |
| Integration | 1 (teacher attendance governance) | Approval integration |
| Golden | 3 viewports | Teacher dashboard |

| Coverage % | **68%** |
| Risk | **P0** |
| Status | **PARTIAL** |

**Gaps:** Exam selector scoped marks save; homework create full; class-teacher scope consistency.

---

### Principal / Governance

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 9+ tests · 7 files | Principal workflows, management approval, KPI drill, pilot closure |
| Maestro YAML | 6 `biz_principal_*` + workflows | Approval, analytics, nav |
| Widget tests | 11 (management/) | Approval center, inbox redirect |
| Integration | 7 (approval/) | Exam, finance, attendance governance |
| Golden | 2 viewports | Management dashboard, approval center (drift artifacts) |

| Coverage % | **78%** |
| Risk | **P0** |
| Status | **PARTIAL** |

**Gaps:** Full cross-filter approval actions (finance PO, fee structure); principal command depth.

---

### SIS

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 6+ tests · 6 files | SIS workflows, filters, profile edit, academic ops |
| Maestro YAML | 3+ biz + workflows | Registry, onboarding, student creation |
| Widget tests | 3 | Registry, profile screens |
| Integration | 3 | F3 SIS 360 API, contract tests |
| Golden | — | — |

| Coverage % | **58%** |
| Risk | **P0** |
| Status | **PARTIAL** |

**Gaps:** Promotion E2E; profile edit persistence; API-mode registry export.

---

### Finance

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 9+ tests · 9 files | Workflows, exports, filters, full journey, offline/QR |
| Maestro YAML | 6+ biz + 3 workflows | Collections, structures, refunds, audit register |
| Widget tests | 7 | Reports, receipts, write tests |
| Integration | 2 | Finance approval, API |
| Golden | 2 viewports | Finance dashboard |

| Coverage % | **72%** |
| Risk | **P0** |
| Status | **PARTIAL** |

**Gaps:** Concession principal-approve chain (Batch 02b); fee structure principal approve → activate.

---

### Inventory

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 5+ tests · 4 files | Workflows, PO, lifecycle, replacement, book distribution |
| Maestro YAML | 2 biz + 2 workflows | Assets, distribution, PO approval |
| Widget tests | 3 | Procurement RBAC, write tests |
| Integration | 2 | Inventory finance, PO |
| Golden | 2 viewports | Inventory dashboard |

| Coverage % | **45%** |
| Risk | **P1** |
| Status | **PARTIAL** |

**Gaps:** Catalog CRUD; stock ledger; dual-persona PO approve (storekeeper vs manager).

---

### HR

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 8 tests · 5 files | HR workflows, leave, payroll, employee CRUD |
| Maestro YAML | 4 biz + 1 workflow | Employees, attendance, payroll |
| Widget tests | 2+ | Providers, screens |
| Integration | 1 | HR API |
| Golden | — | — |

| Coverage % | **52%** |
| Risk | **P1** |
| Status | **PARTIAL** |

**Gaps:** Leave approval full Patrol; payroll run; teacher create from HR nav.

---

### Hostel

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 8 tests · 3 files | Hostel workflows, allocation, visitors |
| Maestro YAML | 1 biz | Rooms |
| Widget tests | 0 dedicated | — |
| Integration | 1 | Hostel API |
| Golden | — | — |

| Coverage % | **38%** |
| Risk | **P1** |
| Status | **PARTIAL** |

**Gaps:** Visitor check-in; room allocation write; fee linkage.

---

### Library

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 8 tests · 3 files | Library workflows, issue/return, digital resources |
| Maestro YAML | 1 biz | Catalog |
| Widget tests | 0 dedicated | — |
| Integration | 1 | Library API |
| Golden | — | — |

| Coverage % | **40%** |
| Risk | **P1** |
| Status | **PARTIAL** |

**Gaps:** Fine calculation; overdue list; student issue Patrol.

---

### Transport

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 9 tests · 4 files | Workflows, route, allocation, activate |
| Maestro YAML | 1 biz | Routes |
| Widget tests | 0 dedicated | — |
| Integration | 1 | Transport API |
| Golden | — | — |

| Coverage % | **35%** |
| Risk | **P1** |
| Status | **PARTIAL** |

**Gaps:** GPS tracking placeholder only; transport attendance; parent bus view.

---

### Admissions

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 5+ tests · 4 files | Workflows, E2E journey, exports, settings |
| Maestro YAML | 3 biz + workflows | Leads, enrollment, dashboard |
| Widget tests | 8 | Phase 3 screens, providers |
| Integration | 3 | Admissions API |
| Golden | — | — |

| Coverage % | **58%** |
| Risk | **P1** |
| Status | **PARTIAL** |

**Gaps:** Lead → enroll → approve full chain Patrol; counselor RBAC.

---

### Management (ERP shell)

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 7+ tests · 6 files | Management workflows, actions, KPI, insight routes, dashboard export |
| Maestro YAML | 3+ biz | Analytics, settings, tasks |
| Widget tests | 11 | Approval, attendance corrections admin |
| Integration | 1 | Management |
| Golden | 3 viewports | Management dashboard |

| Coverage % | **70%** |
| Risk | **P0** |
| Status | **PARTIAL** |

**Gaps:** Tasks approval queue depth; settings persistence.

---

### Director

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol | 2 tests · 2 files | Director portal, navigation |
| Maestro YAML | 0 dedicated | — |
| Widget tests | 0 | — |
| Integration | 0 | — |
| Golden | — | — |

| Coverage % | **22%** |
| Risk | **P2** |
| Status | **NOT TESTED** |

**Gaps:** Multi-school portfolio; trust intelligence; franchise flows.

---

## Summary matrix

| Module | Patrol | Maestro | Widget | Integration | Golden | Coverage % | Risk | Status |
|--------|--------|---------|--------|-------------|--------|------------|------|--------|
| Parent | PARTIAL | COVERED | PARTIAL | PARTIAL | COVERED | 62% | P0 | PARTIAL |
| Student | PARTIAL | COVERED | PARTIAL | NOT TESTED | COVERED | 55% | P1 | PARTIAL |
| Teacher | PARTIAL | COVERED | PARTIAL | PARTIAL | COVERED | 68% | P0 | PARTIAL |
| Principal | PARTIAL | PARTIAL | COVERED | COVERED | PARTIAL | 78% | P0 | PARTIAL |
| SIS | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT TESTED | 58% | P0 | PARTIAL |
| Finance | PARTIAL | PARTIAL | PARTIAL | PARTIAL | COVERED | 72% | P0 | PARTIAL |
| Inventory | PARTIAL | PARTIAL | PARTIAL | PARTIAL | COVERED | 45% | P1 | PARTIAL |
| HR | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT TESTED | 52% | P1 | PARTIAL |
| Hostel | PARTIAL | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | 38% | P1 | PARTIAL |
| Library | PARTIAL | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | 40% | P1 | PARTIAL |
| Transport | PARTIAL | NOT TESTED | NOT TESTED | PARTIAL | NOT TESTED | 35% | P1 | PARTIAL |
| Admissions | PARTIAL | PARTIAL | COVERED | PARTIAL | NOT TESTED | 58% | P1 | PARTIAL |
| Management | PARTIAL | PARTIAL | COVERED | PARTIAL | COVERED | 70% | P0 | PARTIAL |
| Director | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | 22% | P2 | NOT TESTED |

**Weighted module average:** ~48%  
**P0 modules average:** ~67%  
**Personas with Patrol login smoke:** 7/7 QA personas (`qa_login_personas_test.dart`)  
**Routes in protection inventory:** ~78% of ERP routes have guard tests

---

## Existing assets (reuse first)

| Asset | Path | Entries |
|-------|------|---------|
| Generated journeys | `patrol_test/journeys/generated_journeys_test.dart` | 81 |
| Journey manifest | `qa/patrol/journey_manifest.json` | 81 |
| Workflow specs | `qa/journeys/workflow_*.yaml` | 22 |
| Pilot closure | `patrol_test/workflows/pilot_closure_workflows_e2e_test.dart` | 9 |
| ERP smoke | `patrol_test/workflows/erp_coverage_smoke_test.dart` | 5 |
| Red team | `patrol_test/workflows/red_team_*` | 13 |

**Rule:** Extend these before creating duplicate journeys.

---

*Last updated: 2026-06-18 — Batch 02 certified (116 journeys).*

