# Akshara ERP — Operational Remediation Roadmap

**Version:** 1.0  
**Date:** 2026-06-17  
**Branch:** `feature/m15-theme`  
**Companion:** [`OPERATIONAL_GAP_MASTER_TRACKER.md`](./OPERATIONAL_GAP_MASTER_TRACKER.md)  
**Status:** Planning only — **no code, tests, routes, or commits**

---

## Purpose

Convert the Operational Audit into an **execution-ordered remediation program** for a real-school pilot. Prioritization:

| Severity | Rule |
|----------|------|
| **P0** | Pilot blocking — school cannot go live without fix |
| **P1** | Important operational capability — pilot degraded or high risk |
| **P2** | Enhancement — post-pilot or parallel track |

**Overall baseline readiness:** 42% operational · **Pilot target after Phase A–E:** ~68% · **Pilot target after Phase A–H:** ~78% · **Production target (all phases):** ~88%

---

## Executive summary

| Phase | Name | Duration (est.) | Pilot blockers closed | Readiness delta |
|-------|------|-----------------|----------------------|-----------------|
| **A** | Exams & Academic Governance | 6–8 weeks | 4 P0 | Academics 25% → 65% |
| **B** | Attendance Governance | 3–4 weeks | 2 P0 | Attendance 40% → 70% |
| **C** | Student 360 Unification | 3–4 weeks | 2 P0 | Student 360 35% → 70% |
| **D** | Principal Approval Center | 4–5 weeks | 0 P0 (enables P0 workflows) | Principal 50% → 75% |
| **E** | Finance Operational Completion | 3–4 weeks | 3 P0 | Finance 70% → 85% |
| **F** | Inventory Operational Completion | 5–6 weeks | 4 P0 | Inventory 20% → 60% |
| **G** | Transport Operational Completion | 4–5 weeks | 2 P0 | Transport 35% → 65% |
| **H** | Marketing Platform | 6–8 weeks | 1 P0 | Marketing 10% → 70% |
| **I** | Advanced Reports & Compliance | 4–5 weeks | 0 P0 (closes RPT-018) | Cross-module reporting |

**Recommended pilot scope:** Phases **A + B + C + D + E** (minimum credible school). Descope **F, G, H** if pilot school does not run store, bus fleet, or marketing team.

---

## Execution order (strict)

```
Phase D (foundation, parallel track from week 1)
    ↓
Phase A ──→ Phase C (after A marks data exists)
    ↓
Phase B (parallel with A after week 2)
    ↓
Phase E (parallel with B/C; depends D for concessions approval)
    ↓
Phase F | Phase G | Phase H (parallel streams; pilot-dependent)
    ↓
Phase I (after E exports + A/B data models stable)
```

**Critical path:** D (approval infrastructure) → A (exam admin + marks) → E (finance exports) → I (compliance reports)

---

## Wiring-first strategy (do before net-new)

Complete these in **Week 1–2** across phases to maximize ROI:

| Priority | Action | Gap IDs | Effort |
|----------|--------|---------|--------|
| 1 | Wire `ExamAdministrationStore` → API repository + admin UI shell | P0-EXAM-001, P0-EXAM-004 | WIRE + API |
| 2 | Wire marks selectors to active exam list + subject assignments | P0-EXAM-002, P1-EXAM-007 | WIRE |
| 3 | Wire SIS registry → Student 360 navigation | P0-S360-001 | WIRE |
| 4 | Wire scholarship catalog → student assign mutation + UI | P0-FIN-001 | WIRE |
| 5 | Wire refund create dialog to existing approve/reject | P0-FIN-002 | WIRE |
| 6 | Wire subject FAB → real form + `manageSubjects` | P1-EXAM-001, P1-EXAM-003 | WIRE |
| 7 | Wire `Student360Profile.communication` → UI tab | P1-S360-004 | WIRE |
| 8 | Wire parent academic report → `ExamAdministrationStore` published results | P1-PAR-001, DISC-004 | WIRE |
| 9 | Wire homework create → `TeacherRepository` | P1-TCH-001, DISC-006 | WIRE |
| 10 | Fix teacher audit event types for marks | P1-AUD-001 | WIRE |

---

## Phase A — Exams & Academic Governance

**Goal:** Coordinators create exams; teachers enter marks with selectors; principal approves publication; data persists.

**Duration:** 6–8 weeks  
**Owner persona:** Academic coordinator, Subject teacher, Principal  
**Pilot blocker:** Yes

### Scope

| # | Gap IDs | Deliverable |
|---|---------|-------------|
| 1 | P0-EXAM-001, DISC-001, DISC-002 | ERP Exam Administration screens: create/schedule/open marks by class, section, subject, `EduExamType`, max marks, date |
| 2 | P0-EXAM-004 | `ExamRepository` (mock + API) replacing in-memory-only store for production |
| 3 | P0-EXAM-002, P1-EXAM-005, P1-EXAM-007 | Teacher marks entry: class/section/subject/exam selectors; validation; teacher–subject RBAC from assignments |
| 4 | P0-EXAM-003, P1-EXAM-006, P1-EXAM-008, APR-002 | Publish workflow: teacher submit → coordinator verify (`processResults` UI) → principal approve → publish |
| 5 | P1-EXAM-001, P1-EXAM-002, P1-EXAM-003, P1-AUD-002 | Subject catalog form, edit, RBAC, audit |
| 6 | P1-EXAM-004 | Grading scheme configuration (MVP: % bands + pass marks) |
| 7 | P1-PAR-001, DISC-004 | Parent academic summary from published marks |
| 8 | WF-001, WF-002, WF-003 | Unify Education exam types with operational exam admin (single entry point) |

### Dependencies

- **Phase D** for principal publish approval (can ship with temporary principal screen in A if D delayed)
- `docs/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` as north star (do not rebuild question bank)

### Files likely touched

```
lib/core/exams/
lib/core/repositories/interfaces/ (exam_repository)
lib/features/education/ OR lib/features/academics/exam_admin/
lib/features/teacher/exams/
lib/features/school_completion/subjects_screen.dart
lib/features/parent/academics/
lib/core/security/permissions.dart
```

### Exit criteria

- [ ] Coordinator creates half-yearly exam for Class 8-A Mathematics, 80 marks
- [ ] Subject teacher sees only assigned class/subject exams
- [ ] Principal approves before parent/student see results
- [ ] Data survives app restart (API or persistent mock)
- [ ] Contract tests for exam repository CRUD + publish approval

### Readiness after Phase A

| Module | Before | After |
|--------|--------|-------|
| Academics & Exams | 25% | **65%** |
| Teacher App | 55% | **68%** |
| Parent App | 60% | **68%** |

---

## Phase B — Attendance Governance

**Goal:** Mark attendance with lock; request corrections; approve via principal; audit trail.

**Duration:** 3–4 weeks  
**Owner persona:** Class teacher, Parent, Principal  
**Pilot blocker:** Yes

### Scope

| # | Gap IDs | Deliverable |
|---|---------|-------------|
| 1 | P0-ATT-001, P0-ATT-002, APR-003, WF-005 | Correction request entity: parent/teacher → class teacher → principal approve |
| 2 | P1-ATT-005 | Post-submit lock with configurable correction window |
| 3 | P1-ATT-004, P1-ATT-008, RPT-004 | Teacher history view + ERP attendance admin screen |
| 4 | P1-ATT-003, P2-ATT-002 | Student search on teacher mobile; row tap → Student 360 |
| 5 | P1-ATT-006, P1-ATT-007 | Class teacher vs subject-period clarity; parent ticket (not WhatsApp-only) |
| 6 | RBAC-003, RBAC-004, P1-RBAC-002 | Attendance permissions + mutation registry |
| 7 | P1-TCH-002, DISC-005 | Separate staff HR punch from class attendance on teacher dashboard |

### Dependencies

- **Phase D** for principal approval queue (shared approval infrastructure)
- **Phase C** for Student 360 drill-down (can use risk screen as interim)

### Exit criteria

- [ ] Teacher submits attendance; rows lock after submit
- [ ] Parent raises correction request with reason
- [ ] Principal approves/rejects in Approval Center
- [ ] Audit log shows who changed roll X on date Y
- [ ] RBAC: only assigned teachers mark their classes

### Readiness after Phase B

| Module | Before | After |
|--------|--------|-------|
| Attendance | 40% | **70%** |
| Teacher App | 68% | **75%** |
| Parent App | 68% | **72%** |

---

## Phase C — Student 360 Unification

**Goal:** One student dossier reachable from SIS, teacher, and management; core domains visible.

**Duration:** 3–4 weeks  
**Owner persona:** Principal, Class teacher, SIS admin  
**Pilot blocker:** Yes (for discipline/safety oversight)

### Scope

| # | Gap IDs | Deliverable |
|---|---------|-------------|
| 1 | P0-S360-001, DISC-003, WF-013 | Navigation: SIS registry → 360; teacher at-risk → 360; intelligence drill-down |
| 2 | P0-S360-002 | Add behaviour, transport, documents tabs (read from SIS/transport/discipline repos) |
| 3 | P1-S360-003, P1-S360-004, P1-S360-005 | Merge SIS profile data; render communication; fix identity mapping |
| 4 | P2-S360-001, P2-S360-002 | Activities tab; dossier PDF export (basic) |
| 5 | Deprecate | Document path to retire `TeacherStudentRiskScreen` as primary (keep as quick risk widget) |

### Dependencies

- **Phase A** for marks tab live data
- **Phase B** for attendance history on 360
- Transport documents optional if Phase G descoped

### Exit criteria

- [ ] Principal opens any student from SIS registry in Student 360
- [ ] Class teacher opens at-risk student in same 360 (not separate risk-only screen)
- [ ] 360 shows: attendance, marks, homework, fees, comms, transport (if assigned), documents
- [ ] Single permission model: `viewStudent360`

### Readiness after Phase C

| Module | Before | After |
|--------|--------|-------|
| Student 360 | 35% | **70%** |
| SIS | 60% | **72%** |
| Management / Principal | 50% | **62%** |

---

## Phase D — Principal Approval Center

**Goal:** Unified inbox for all school approvals — financial, academic, attendance, leave, inventory.

**Duration:** 4–5 weeks (start Week 1 in parallel)  
**Owner persona:** Principal, Vice Principal  
**Pilot blocker:** No (standalone) — **blocks quality of A, B, E, F**

### Scope

| # | Gap IDs | Deliverable |
|---|---------|-------------|
| 1 | P1-PRIN-001, DISC-007, WF-011, WF-014 | `PrincipalApprovalCenter` — unified queue with filters by type/status |
| 2 | APR-002, APR-003, APR-004, APR-005, APR-006, APR-008, APR-012 | Wire approval types: exam publish, attendance correction, student leave, staff leave, fee concession, PO |
| 3 | P1-PRIN-002, P1-PRIN-003 | Student leave approval; same-day attendance exceptions |
| 4 | P1-FIN-004, P1-FIN-007 | Fee structure approval; principal refund threshold |
| 5 | P0-INV-003, RBAC-006 | PO maker-checker: storekeeper create, principal approve |
| 6 | Extend `ManagementApprovalType` enum + `management_workflow_actions.dart` pattern | Shared approval mutation + audit |

### Reference implementation

Copy patterns from **Admissions** (`approveAdmission` / `rejectAdmission`) — only module with complete approval chain today.

### Exit criteria

- [ ] Principal sees single inbox with pending items from all modules
- [ ] Approve/reject with comment + audit event
- [ ] Mobile notification to requester on decision
- [ ] No approval type requires navigating to a separate module

### Readiness after Phase D

| Module | Before | After |
|--------|--------|-------|
| Management / Principal | 50% | **75%** |
| Cross-module governance | 30% | **70%** |

---

## Phase E — Finance Operational Completion

**Goal:** Concessions operable; refunds end-to-end; real report exports; cashier-ready flows.

**Duration:** 3–4 weeks  
**Owner persona:** Accountant, Principal  
**Pilot blocker:** Yes (concessions + exports)

### Scope

| # | Gap IDs | Deliverable |
|---|---------|-------------|
| 1 | P0-FIN-001, P0-FIN-002, RBAC-009, APR-006 | Concession assign UI + principal approval; refund create UI |
| 2 | P0-FIN-003, RPT-018 | Shared `AksharaReportExportService` — real PDF/Excel for finance (replace snackbars) |
| 3 | P1-FIN-005, P1-FIN-006, P1-FIN-008 | Discount rule CRUD; invoice picker on collection; receipt PDF name fix |
| 4 | P1-FIN-009, P2-FIN-005 | Offline payment verifier role; multi-level refund approval |
| 5 | P1-PAR-003 | Payment gateway integration path (if `PAYMENT_API_ENABLED`) |
| 6 | RPT-005, RPT-008, RPT-012 | Daily collection close, refund register, library fine export hooks |

### Dependencies

- **Phase D** for concession and refund approval
- Library fines (P2-FIN-004) can follow in Phase I

### Exit criteria

- [ ] Accountant assigns scholarship to student; principal approves
- [ ] Cashier creates refund; finance approves; receipt generated
- [ ] Finance reports export to PDF on disk
- [ ] Parent payment works with configured gateway

### Readiness after Phase E

| Module | Before | After |
|--------|--------|-------|
| Finance | 70% | **85%** |
| Parent App | 72% | **78%** |
| **Overall (A–E complete)** | 42% | **~68%** |

---

## Phase F — Inventory Operational Completion

**Goal:** Item master, stock ledger, consumption, maker-checker POs.

**Duration:** 5–6 weeks  
**Owner persona:** Store keeper, Inventory manager, Principal  
**Pilot blocker:** Yes if school runs a store; **descope otherwise**

### Scope

| # | Gap IDs | Deliverable |
|---|---------|-------------|
| 1 | P0-INV-001 | Catalog/item master CRUD (SKU, UOM, category, reorder level) |
| 2 | P0-INV-002, RPT-009 | Stock ledger — every movement logged; qty updates on issue |
| 3 | P0-INV-003, P0-INV-004, RBAC-006, RBAC-007 | `storekeeper` role; PO create ≠ approve |
| 4 | P1-INV-005, P1-INV-006, P1-INV-007 | Manual stock-in; consumption draw-down; partial PO receive |
| 5 | P1-INV-008 | Enforce lifecycle/procurement permissions |
| 6 | P2-INV-001, P2-INV-002, P2-INV-003 | Physical audit; barcode issue; asset return |

### Dependencies

- **Phase D** for principal PO approval
- **Phase E** for finance GRN reconciliation alignment

### Exit criteria

- [ ] Storekeeper creates item; manager approves catalog entry
- [ ] Stock in → issue → return → consumption reflected in ledger
- [ ] Principal approves PO > threshold
- [ ] Stock history visible per SKU

### Readiness after Phase F

| Module | Before | After |
|--------|--------|-------|
| Inventory | 20% | **60%** |

---

## Phase G — Transport Operational Completion

**Goal:** Fleet master data, route builder, attendance capture; optional GPS.

**Duration:** 4–5 weeks (+ GPS integration variable)  
**Owner persona:** Transport manager, Driver, Parent  
**Pilot blocker:** Yes if transport marketed to parents; **descope otherwise**

### Scope

| # | Gap IDs | Deliverable |
|---|---------|-------------|
| 1 | P1-TRN-003, P1-TRN-004, P1-TRN-005 | Vehicle/driver CRUD; route stop editor; route picker on assign |
| 2 | P0-TRN-002, P1-TRN-007, RBAC-008 | Transport attendance write; driver/conductor role |
| 3 | P0-TRN-001, DISC-008 | GPS integration MVP OR honest “scheduled route only” mode with parent ETA |
| 4 | P1-TRN-006, P2-TRN-001, P2-TRN-002 | Settings persistence; compliance alerts; parent pickup notifications |
| 5 | P2-FIN-003 | Transport fee link to finance |

### Exit criteria

- [ ] Transport manager adds bus, driver, route with stops
- [ ] Driver marks pickup/drop per student
- [ ] Parent sees attendance + route (GPS or static per pilot contract)
- [ ] No placeholder tracking screen in production pilot

### Readiness after Phase G

| Module | Before | After |
|--------|--------|-------|
| Transport | 35% | **65%** |
| Parent App | 78% | **82%** |

---

## Phase H — Marketing Platform

**Goal:** Implement MK-01–MK-06 (P0 spec) + Admissions handoff.

**Duration:** 6–8 weeks  
**Owner persona:** Marketing manager, Admissions counsellor  
**Pilot blocker:** Yes if school has marketing team; **descope if admissions-only**

### Scope

| # | Gap IDs | Deliverable |
|---|---------|-------------|
| 1 | P0-MKT-001 | `lib/features/marketing/` module shell + navigation + RBAC |
| 2 | MK-01, MK-02, MK-03 | Dashboard, acquisition leads, campaigns |
| 3 | MK-04, MK-06 | WhatsApp automation MVP, AI poster studio |
| 4 | MK-08 | Operator conversion analytics (beyond Director ROI) |
| 5 | P1-ADM-002, DISC-009, APR-014 | MK-D-10 handoff to Admissions CRM; campaign spend → management approval |
| 6 | P1-ADM-001 | Distinct enquiry capture screen (AD-03) |
| 7 | P2-MKT-001–004 | Social, content planner, reports, referrals (post-MVP) |

### Reference

`docs/Marketing.md` — screen inventory MK-01–MK-10, dialogs MK-D-01–10, AR-004 lead ownership.

### Exit criteria

- [ ] Marketing creates campaign; leads captured with source/CPL
- [ ] Handoff lead to Admissions with read-only acquisition banner (already stubbed)
- [ ] Admissions does not re-enter source data
- [ ] Director sees ROI; marketing sees operator funnel

### Readiness after Phase H

| Module | Before | After |
|--------|--------|-------|
| Marketing | 10% | **70%** |
| Admissions | 75% | **85%** |
| **Overall (A–H complete)** | 68% | **~78%** |

---

## Phase I — Advanced Reports & Compliance

**Goal:** School-wide reporting, audit packs, formal documents.

**Duration:** 4–5 weeks  
**Owner persona:** Principal, Accountant, Auditor  
**Pilot blocker:** No — required for accreditation / board inspection

### Scope

| # | Gap IDs | Deliverable |
|---|---------|-------------|
| 1 | RPT-001, P2-EXAM-004 | Official report card PDF (letterhead, attendance, remarks) |
| 2 | RPT-002, RPT-003, P2-RPT-001, P2-RPT-002 | Marks register; attendance register exports |
| 3 | RPT-007, P2-RPT-003 | Concession/waiver register |
| 4 | RPT-010, P2-INV-001 | Stock audit variance report |
| 5 | RPT-011, RPT-013 | Transport + payroll registers |
| 6 | RPT-016, P2-S360-002 | Student 360 dossier PDF |
| 7 | RPT-017, P2-RPT-004 | Cross-module compliance audit pack |
| 8 | P2-EXAM-003, P2-EXAM-006, P2-EXAM-007 | Term aggregation, publish notifications, rank (if in scope) |

### Dependencies

- Phases A, B, E (data models)
- Phase E export infrastructure (RPT-018)

### Exit criteria

- [ ] Principal exports term report cards for class PDF zip
- [ ] Accountant exports fee + concession registers for auditor
- [ ] All module reports produce real files (not snackbars)

### Readiness after Phase I

| Module | Before | After |
|--------|--------|-------|
| Reporting / Compliance | 25% | **80%** |
| **Overall (all phases)** | 78% | **~88%** |

---

## Pilot deployment matrix

| School profile | Required phases | Can descope |
|----------------|-----------------|-------------|
| **Day school, no store, no buses** | A, B, C, D, E | F, G, H |
| **Day school + transport** | A–E, G | F, H |
| **Boarding school** | A–E, B, C, + Hostel P1 items | F, H |
| **Full K-12 with marketing team** | A–H | — |
| **Full ERP + compliance** | A–I | — |

### Minimum pilot checklist (Phases A–E)

- [ ] P0-EXAM-001 through P0-EXAM-004 closed
- [ ] P0-ATT-001, P0-ATT-002 closed
- [ ] P0-S360-001, P0-S360-002 closed
- [ ] P0-FIN-001, P0-FIN-002, P0-FIN-003 closed
- [ ] Phase D approval center live for exam publish, attendance correction, leave, concession
- [ ] No in-memory-only exam data in pilot build
- [ ] Parent academic data from live marks

---

## Resource & risk assumptions

| Assumption | Impact if wrong |
|------------|-----------------|
| Backend API team available for exam, attendance, approval APIs | Phase A/B slip 4+ weeks |
| GPS vendor selected before Phase G | Transport pilot blocked |
| `docs/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` deferred scope respected | Scope creep into question bank |
| Single school pilot (not multi-tenant ops) | Director Phase I items lower priority |
| QA uses mock repositories until API ready | Wire-first strategy mandatory |

---

## Final readiness projection

| Milestone | Overall % | Pilot viable? |
|-----------|-----------|---------------|
| Baseline (today) | **42%** | No |
| After A + D | 58% | No |
| After A + B + C + D + E | **68%** | **Yes** (limited scope) |
| After A–H | **78%** | Yes (full school) |
| After A–I | **88%** | Yes (production candidate) |

### Per-module targets (after all phases)

| Module | Current | Target |
|--------|---------|--------|
| Academics & Exams | 25% | 85% |
| Attendance | 40% | 80% |
| Student 360 | 35% | 85% |
| Principal / Management | 50% | 85% |
| Finance | 70% | 90% |
| Inventory | 20% | 75% |
| Transport | 35% | 80% |
| Marketing | 10% | 75% |
| Admissions | 75% | 90% |
| Teacher App | 55% | 85% |
| Parent App | 60% | 85% |
| Student App | 45% | 75% |

---

## Document cross-references

| Document | Relationship |
|----------|--------------|
| [`OPERATIONAL_GAP_MASTER_TRACKER.md`](./OPERATIONAL_GAP_MASTER_TRACKER.md) | Full gap backlog (94 items) |
| [`docs/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md`](./ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md) | Long-term assessment architecture (defer heavy scope) |
| [`docs/Marketing.md`](./Marketing.md) | Marketing module spec (Phase H) |
| [`docs/Admissions.md`](./Admissions.md) | Admissions pipeline reference |
| [`docs/PilotSchoolChecklist.md`](./PilotSchoolChecklist.md) | Update after Phase A–E complete |
| [`docs/ProductionReadinessChecklist.md`](./ProductionReadinessChecklist.md) | Gate checklist — sync after remediation |

---

## Change log

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-06-17 | Initial roadmap from Operational Audit |
