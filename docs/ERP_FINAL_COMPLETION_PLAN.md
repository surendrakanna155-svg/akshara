# Akshara ERP — Final Completion Plan

**Version:** 2.0  
**Date:** June 2026  
**Baseline:** QA-ready (~95% test readiness, ~62% E2E journey coverage)  
**Target:** ERP feature-complete (business workflows, not test inflation)

---

## Executive Summary

Akshara ERP has strong **read surfaces** across most modules (Admissions, Finance, SIS, Management dashboards). The remaining gap is **write workflows**, **mutation providers with RBAC**, **exports/reports actions**, and **ERP-native exam admin**. This plan audits all 16 modules, prioritizes P0–P3 work, and tracks autonomous implementation.

| Metric | Start | Current | Target |
|--------|-------|---------|--------|
| Weighted ERP completion | ~68% | ~75% | ≥90% |
| Modules with mutation layer | 8/16 | 11/16 | 14/16 |
| P0 gaps closed | 4/10 (Phase 1) | 7/10 | 10/10 |
| Flutter tests | 1304 | 1316+ | — |
| Patrol regression | 25/25 | 25/25+ | green |

**Phase 1 completion workflows (done):** HR payroll run, inventory lifecycle event, transport route activate, education remark publish.

**Final completion P0 #1 (done):** Management executive approval approve/reject.

**Final completion P0 #2 (done):** Library issue book + return book workflows.

---

## Module Audits

Grading: **A** Fully complete · **B** Partially complete · **C** Missing business logic · **D** Missing UI · **E** Missing provider layer · **F** Product scope undefined

### Admissions — **B · ~88%**

| Gap | Priority |
|-----|----------|
| Settings persistence (MG handoff) | P1 |
| Bulk import / campaign automation | P3 |
| Full API write parity | P2 |

**Missing:** settings save, bulk lead import UI. **Writes:** create lead, application, approve/reject, enrollment. **RBAC:** complete. **Tests:** strong. **Effort:** 2–3 d (settings), 5 d (bulk).

---

### SIS — **B · ~85%**

| Gap | Priority |
|-----|----------|
| Student profile edit / document upload | P1 |
| Bulk class promotion | P2 |
| API write parity | P2 |

**Missing:** profile mutation screens, promotion wizard. **Writes:** register, convert enrollment, academic assign. **RBAC:** complete. **Effort:** 4–5 d.

---

### Finance — **B · ~82%**

| Gap | Priority |
|-----|----------|
| Invoice create / cancel collection (repo exists, UI unwired) | P0 |
| Receipt PDF export action | P1 |
| Executive dashboard drill write-back | P2 |

**Missing:** invoice workflow UI, collection cancel. **Writes:** fee structure, refund approve, scholarship, collect fee. **Effort:** 3–4 d (P0).

---

### Attendance — **C · ~55%**

| Gap | Priority |
|-----|----------|
| ERP attendance admin module (bulk mark, reports) | P1 |
| Teacher mobile mark (exists); ERP reconciliation | P1 |

**Missing:** ERP admin screens, bulk import, absence workflow. **Writes:** teacher mobile only. **Effort:** 6–8 d.

---

### HR — **B · ~72%**

| Gap | Priority |
|-----|----------|
| Employee CRUD | P0 |
| Leave approve/reject (manager) | P1 |
| Attendance integration | P2 |

**Missing:** create/edit employee, leave approval chain. **Writes:** leave create, payroll run (done). **Effort:** 5 d (employee CRUD).

---

### Payroll — **B · ~70%** (subset of HR)

| Gap | Priority |
|-----|----------|
| Per-entry adjustment | P1 |
| Payroll export PDF | P1 (export snackbar partial) |
| Mark paid / bank file | P2 |

**Writes:** process payroll run (done). **Effort:** 3 d (adjustments + export).

---

### Inventory — **B · ~68%**

| Gap | Priority |
|-----|----------|
| PO approve / receive API wiring | P0 |
| Stock move / allocation writes | P1 |
| Asset approve workflow | P0 |

**Missing:** PO receive UI beyond handoff snackbar, stock moves. **Writes:** PO draft, lifecycle event (done), procurement handoff. **Effort:** 4–5 d.

---

### Transport — **B · ~65%**

| Gap | Priority |
|-----|----------|
| Student route allocation | P0 |
| Bus assignment / driver roster writes | P1 |
| Live tracking (placeholder) | P3 |

**Writes:** route draft, activate route (done). **Effort:** 4 d (allocation).

---

### Exams — **C/F · ~35%**

| Gap | Priority |
|-----|----------|
| ERP Exam Admin module (schedule, marks, publish) | P3 (XL) |
| Education remark publish | done |
| Mobile teacher/parent exam views | partial |

**Product scope undefined** for unified ERP exam module. Fragmented across Education Suite + Intelligence + mobile. **Effort:** 15–20 d (new module).

---

### Library — **B · ~58%** (↑ from ~45%)

| Gap | Priority |
|-----|----------|
| Issue / return write layer | **done** |
| Fine payment / waive | P1 |
| Catalog add / edit book | P1 |

**Writes:** `issueLibraryBook`, `returnLibraryBook` (mock + RBAC + UI + Patrol). **Effort remaining:** 3 d (fines + catalog).

---

**Final completion P0 #3 (done):** Hostel admission, room assignment, transfer, and checkout.

### Hostel — **B · ~62%** (↑ from ~42%)

| Gap | Priority |
|-----|----------|
| Room allocation / check-in | **done** |
| Room transfer | **done** (via assign) |
| Leave approve/reject | P1 |
| Visitor register | P1 |

**Writes:** `admitHostelStudent`, `assignHostelRoom`, `checkoutHostelStudent`. **Effort remaining:** 4 d (leave, visitors).

---

### Alumni — **C · ~48%**

| Gap | Priority |
|-----|----------|
| Event create / RSVP admin | P1 |
| Donation record | P2 |
| Profile update | P2 |

**Read-only mock.** **Effort:** 4 d.

---

### Management — **B · ~62%** (↑ from ~55%)

| Gap | Priority |
|-----|----------|
| Executive approval approve/reject | **done** |
| Settings save | P1 |
| AI insight action stubs | P2 |

**Writes:** `resolveManagementApproval` (mock + RBAC + UI + Patrol). **Effort remaining:** 2 d (settings).

---

### Reports — **C · ~50%**

| Gap | Priority |
|-----|----------|
| Unified reports hub | P3 |
| Per-module export actions | P1 (partial — HR/Inventory/Transport/Education exports done) |
| Scheduled report delivery | P3 |

**Effort:** 8 d (hub), 1 d per module export.

---

### RBAC — **B · ~75%**

| Gap | Priority |
|-----|----------|
| `mutation_permission_registry` incomplete vs providers | P1 |
| Server-side RBAC enforcement | P3 |
| Teacher/parent mutation guards audit | P0 |

**Client guards strong; registry stale.** **Effort:** 2 d (registry sync), 10+ d (server).

---

### Notifications — **C · ~40%**

| Gap | Priority |
|-----|----------|
| ERP broadcast / template admin | P1 |
| Inbox mark-read persistence | P2 |
| Push channel integration | P3 |

**Inbox read-only.** **Effort:** 5 d (broadcast admin).

---

## Phase 2 — Prioritization

### P0 — Required for Complete ERP

| # | Gap | Module | Value | Effort | Dependencies | Risk |
|---|-----|--------|-------|--------|--------------|------|
| 1 | Executive approval workflow | Management | **done** | S | RBAC | Low |
| 2 | Library issue / return writes | Library | **done** | M | SIS member link | Med |
| 3 | Hostel room allocation | Hostel | **done** | M | SIS students | Med |
| 4 | HR employee CRUD | HR | High | M | RBAC manageHr | Low |
| 5 | Transport student allocation | Transport | High | M | Routes active | Low |
| 6 | Finance invoice / cancel collection UI | Finance | High | M | Finance repo | Low |
| 7 | Inventory PO approve / asset approve | Inventory | High | M | Finance handoff | Med |
| 8 | Teacher/parent mutation RBAC audit | RBAC | High | S | Security | Med |
| 9 | Admissions settings persistence | Admissions | Med | S | Management settings | Low |
| 10 | Notifications broadcast admin | Notifications | Med | M | Communication repo | Med |

### P1 — High Value

Attendance ERP admin, SIS profile edit, payroll adjustments/export, library fines, alumni events, management settings save, finance receipt PDF, inventory stock moves.

### P2 — Nice To Have

Bulk operations, API write parity per module, alumni donations, scheduled reports.

### P3 — Future Roadmap

ERP Exam Admin module, unified reports hub, live transport tracking, server RBAC, push notifications.

---

## Top 10 Remaining Gaps (post Management P0)

1. ~~**Library issue/return**~~ — done  
2. **Hostel allocation** — boarding schools blocked without check-in  
3. **HR employee CRUD** — staff onboarding incomplete  
4. **Transport allocation** — routes exist but students not assignable  
5. **Finance invoice UI** — repo methods orphaned  
6. **Inventory PO approve** — procurement chain incomplete  
7. **RBAC registry + mobile mutation audit** — security completeness  
8. **Admissions settings save** — config drift across modules  
9. **Notifications broadcast** — school-wide comms admin missing  
10. **Attendance ERP admin** — reconciliation with teacher mobile  

---

## Phase 3 — Implementation Rules

1. Smallest safe change first  
2. Reuse repository → mock + API stub → mutations → workflow → QA keys → tests → Patrol  
3. Preserve green `flutter analyze` + `flutter test` + Patrol regression  
4. Update progress docs after each P0  

---

## Phase 4 — Continuous Loop

```
Find P0 gap → Implement → flutter analyze → affected tests → Patrol (if UI) → Update docs → Next P0
```

**Stop when:** all P0 closed OR product decision required (Exam Admin scope).

---

## Recommended Next Sprint (ordered)

1. ~~Library issue book + return book (P0 #2)~~ — done  
2. Hostel room allocation (P0 #3)  
3. HR employee create/edit (P0 #4)  
4. Transport student route assignment (P0 #5)  
5. Finance invoice / cancel collection wiring (P0 #6)  

**Estimated sprint:** 3–4 weeks for P0 #2–6 at current velocity.

---

## References

- `docs/QA/final_completion_progress.md` — session log  
- `docs/QA/final_completion_summary.md` — executive rollup  
- `docs/QA/PHASE3_COVERAGE_INVENTORY.md` — E2E button coverage  
- `AGENTS.md` — agent ownership boundaries  
