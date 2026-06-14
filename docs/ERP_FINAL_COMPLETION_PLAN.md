# Akshara ERP — Final Completion Plan

**Version:** 2.1  
**Date:** June 2026  
**Baseline:** QA-ready (~95% test readiness, ~62% E2E journey coverage)  
**Target:** ERP feature-complete (business workflows, not test inflation)  
**Post Batch A:** ERP ~91% · Tests 1412 · Patrol ~49

---

## Vision Reconciliation (June 2026)

A full audit of Roadmap, Vision, SRS (20 parts), module specs, PRDs, backlog, dashboard audit, release/QA docs, and AGENTS produced a **single source of truth** so no original capability is lost.

| Deliverable | Purpose |
|-------------|---------|
| [`AKSHARA_MASTER_FEATURE_REGISTRY.md`](AKSHARA_MASTER_FEATURE_REGISTRY.md) | ~215 features — source, classification A–F, code/test/Patrol validation |
| [`AKSHARA_VISION_GAP_ANALYSIS.md`](AKSHARA_VISION_GAP_ANALYSIS.md) | Advanced gaps: academic reshuffle, teacher ops, comms continuity, automation, owner dashboard, AI |
| [`AKSHARA_IMPLEMENTATION_BACKLOG.md`](AKSHARA_IMPLEMENTATION_BACKLOG.md) | P0–P3 prioritized backlog reconciled with vision |

**Key findings:**

- **P0 program (9/10 done)** aligns with core ERP pilot needs — no P0 item dropped from vision.  
- **Vision differentiators** largely P1–P2: promotion/reshuffle, substitute wizard, communication migration, workflow engine, owner dashboard actions.  
- **Timetable** is strongest advanced area (drag-drop, conflicts, generate — mock-functional).  
- **AI surfaces** exist; **live inference** is P3.  
- **Exam Admin** remains product-blocked (P3, scope undefined).

**Next P0 after reconciliation:** #6 Finance invoice / cancel collection UI (repo exists, spec clear, billing-chain vision gap).

---

## Executive Summary

Akshara ERP has strong **read surfaces** across most modules (Admissions, Finance, SIS, Management dashboards). The remaining gap is **write workflows**, **mutation providers with RBAC**, **exports/reports actions**, and **ERP-native exam admin**. This plan audits all 16 modules, prioritizes P0–P3 work, and tracks autonomous implementation.

| Metric | Start | Current | Target |
|--------|-------|---------|--------|
| Weighted ERP completion | ~68% | ~91% | ≥90% |
| Modules with mutation layer | 8/16 | 14/16 | 14/16 |
| P0 gaps closed | 4/10 (Phase 1) | 9/10 | **10/10** |
| Flutter tests | 1304 | 1412 | — |
| Patrol regression | 25/25 | 49/~49 | green |

**Phase 1 completion workflows (done):** HR payroll run, inventory lifecycle event, transport route activate, education remark publish.

**Final completion P0 #1 (done):** Management executive approval approve/reject.

**Final completion P0 #2 (done):** Library issue book + return book workflows.

**Final completion P0 #3 (done):** Hostel admission, room assignment, transfer, and checkout.

**Final completion P0 #4 (done):** HR employee create, edit, activate/deactivate with audit.

**Final completion P0 #5 (done):** Transport student assign, transfer, remove with capacity validation.

**Final completion P0 #6 (done):** Finance invoice issue/cancel UI + collection cancel on detail.

---

Grading: **A** Fully complete · **B** Partially complete · **C** Missing business logic · **D** Missing UI · **E** Missing provider layer · **F** Product scope undefined

### Admissions — **A · ~92%**

| Gap | Priority |
|-----|----------|
| Bulk import / campaign automation | P3 |
| Full API write parity | P2 |

**Missing:** bulk lead import UI. **Writes:** create lead, application, approve/reject, enrollment, **settings save**. **RBAC:** complete. **Tests:** strong. **Effort:** 5 d (bulk).

---

### SIS — **A · ~90%**

| Gap | Priority |
|-----|----------|
| Bulk class promotion | P2 |
| API write parity | P2 |

**Writes:** register, assign, **profile edit**, **document upload**, year transition. **Effort:** P2 bulk/API.

**Missing:** profile mutation screens, promotion wizard. **Writes:** register, convert enrollment, academic assign. **RBAC:** complete. **Effort:** 4–5 d.

---

### Finance — **A · ~88%**

| Gap | Priority |
|-----|----------|
| Executive dashboard drill write-back | P2 |

**Writes:** fee structure, refund approve, scholarship, collect fee, invoice/cancel, **receipt PDF export**. **Effort:** P2 drill-back only.

---

### Attendance — **C · ~55%**

| Gap | Priority |
|-----|----------|
| ERP attendance admin module (bulk mark, reports) | P1 |
| Teacher mobile mark (exists); ERP reconciliation | P1 |

**Missing:** ERP admin screens, bulk import, absence workflow. **Writes:** teacher mobile only. **Effort:** 6–8 d.

---

### HR — **A · ~85%**

| Gap | Priority |
|-----|----------|
| Attendance integration | P2 |

**Writes:** employee CRUD, leave create, **leave approve/reject**, payroll run. **Effort:** P2 attendance integration.

---

### Payroll — **B · ~70%** (subset of HR)

| Gap | Priority |
|-----|----------|
| Per-entry adjustment | P1 |
| Payroll export PDF | P1 (export snackbar partial) |
| Mark paid / bank file | P2 |

**Writes:** process payroll run (done). **Effort:** 3 d (adjustments + export).

---

### Inventory — **A · ~82%**

| Gap | Priority |
|-----|----------|
| Stock move / allocation writes | P1 |
| Asset approve workflow | P2 |

**Writes:** PO draft, lifecycle event, **PO approve/receive handoff**, procurement chain. **Effort:** P1 stock moves.

---

### Transport — **B · ~72%** (↑ from ~65%)

| Gap | Priority |
|-----|----------|
| Bus assignment / driver roster writes | P1 |
| Live tracking (placeholder) | P3 |

**Writes:** route draft, activate route (done), student assign/transfer/remove (done). **Effort:** 3 d (attendance sync).

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

### RBAC — **A · ~88%**

| Gap | Priority |
|-----|----------|
| Secondary mutation registry entries (admissions/finance pipeline) | P2 |
| Server-side RBAC enforcement | P3 |

**Client guards strong; Batch A registry sync complete (41 entries).** **Effort:** P2 registry expansion, 10+ d (server).

---

### Notifications — **B · ~72%**

| Gap | Priority |
|-----|----------|
| Inbox mark-read persistence | P2 |
| Push channel integration | P3 |

**Broadcast admin + template CRUD shipped.** **Effort:** P2 inbox persistence.

---

## Phase 2 — Prioritization

### P0 — Required for Complete ERP

| # | Gap | Module | Value | Effort | Dependencies | Risk |
|---|-----|--------|-------|--------|--------------|------|
| 1 | Executive approval workflow | Management | **done** | S | RBAC | Low |
| 2 | Library issue / return writes | Library | **done** | M | SIS member link | Med |
| 3 | Hostel room allocation | Hostel | **done** | M | SIS students | Med |
| 4 | HR employee CRUD | HR | **done** | M | RBAC manageHr | Low |
| 5 | Transport student allocation | Transport | **done** | M | Routes active | Low |
| 6 | Finance invoice / cancel collection UI | Finance | High | M | Finance repo | Low |
| 7 | Inventory PO approve / asset approve | Inventory | **PO done** | M | Finance handoff | Med |
| 8 | Teacher/parent mutation RBAC audit | RBAC | High | S | Security | Med |
| 9 | Admissions settings persistence | Admissions | **done** | S | Management settings | Low |
| 10 | Notifications broadcast admin | Notifications | **done** | M | Communication repo | Med |

### P1 — High Value

Attendance ERP admin, SIS profile edit, payroll adjustments/export, library fines, alumni events, management settings save, inventory stock moves.

### P2 — Nice To Have

Bulk operations, API write parity per module, alumni donations, scheduled reports.

### P3 — Future Roadmap

ERP Exam Admin module, unified reports hub, live transport tracking, server RBAC, push notifications.

---

## Top 10 Remaining Gaps (post Management P0)

1. ~~**Library issue/return**~~ — done  
2. ~~**Hostel allocation**~~ — done  
3. ~~**HR employee CRUD**~~ — done  
4. ~~**Transport allocation**~~ — done  
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
2. ~~Hostel room allocation (P0 #3)~~ — done  
3. ~~HR employee create/edit (P0 #4)~~ — done  
4. ~~Transport student route assignment (P0 #5)~~ — done  
5. Finance invoice / cancel collection wiring (P0 #6)  

**Estimated sprint:** 3–4 weeks for P0 #2–6 at current velocity.

---

## References

- `docs/AKSHARA_MASTER_FEATURE_REGISTRY.md` — master feature registry (SSOT)  
- `docs/AKSHARA_VISION_GAP_ANALYSIS.md` — vision vs implementation gaps  
- `docs/FUTURE_VISION_RECONCILIATION.md` — FutureVision vs registry audit  
- `docs/ADVANCED_FEATURE_STATUS.md` — advanced feature classification  
- `docs/AKSHARA_FINAL_ROADMAP.md` — post-P0 prioritized roadmap  
- `docs/AKSHARA_IMPLEMENTATION_BACKLOG.md` — prioritized P0–P3 backlog  
- `docs/QA/final_completion_progress.md` — session log  
- `docs/QA/final_completion_summary.md` — executive rollup  
- `docs/QA/PHASE3_COVERAGE_INVENTORY.md` — E2E button coverage  
- `docs/OWNER_DASHBOARD_AUDIT.md` — owner dashboard functional audit  
- `docs/Vision/FutureVision.md` — long-term capability map  
- `AGENTS.md` — agent ownership boundaries  
