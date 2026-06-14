# Akshara Implementation Backlog

**Version:** 1.0  
**Date:** June 2026  
**Purpose:** Prioritized, traceable backlog after vision reconciliation  
**Sources:** `AKSHARA_MASTER_FEATURE_REGISTRY.md` · `AKSHARA_VISION_GAP_ANALYSIS.md` · `ERP_FINAL_COMPLETION_PLAN.md`

---

## Priority definitions

| Tier | Definition | Gate |
|------|------------|------|
| **P0** | Core ERP required for school pilot operations | Must complete before declaring ERP-complete |
| **P1** | High-value business features from original vision | Complete after P0; owner/academic impact |
| **P2** | Advanced automation & structural workflows | Requires P1 foundations |
| **P3** | AI live inference, exam scope, platform expansion | Product / architecture decisions |

**Standard delivery process (each item):** Implement → unit/contract tests → Patrol (if UI) → fix → `flutter analyze` → commit → push → CI `analyze-and-test` green.

---

## P0 — Core ERP (remaining)

| ID | Feature | Module | Vision/registry ref | Est. | Status | Owner |
|----|---------|--------|---------------------|------|--------|-------|
| P0-6 | Finance invoice create + cancel collection UI | Finance | REG-Finance invoice; PLAN #6; SRS Part Finance | 4–5 d | **Done** | Agent B |
| P0-7 | Inventory PO approve + asset approve | Inventory | REG-Inventory PO; PLAN #7 | 4–5 d | Open | Agent B + A |
| P0-8 | Mutation RBAC registry + mobile mutation audit | Platform | REG-RBAC; PLAN #8; AGENTS Agent D | 2–3 d | Open | Agent D |
| P0-9 | Admissions settings persistence | Admissions | REG-Admissions settings; PLAN #9 | 2–3 d | Open | Agent B |
| P0-10 | Notifications broadcast / template admin | Notifications | REG-Notifications broadcast; PLAN #10; VISION #2 | 4–5 d | Open | Agent B |

**P0 closed (reference):** P0-1 Management approvals · P0-2 Library issue/return · P0-3 Hostel allocation · P0-4 HR employee CRUD · P0-5 Transport student allocation

---

## P1 — High-value business features

| ID | Feature | Module | Vision source | Est. | Depends on | Notes |
|----|---------|--------|---------------|------|------------|-------|
| P1-01 | **Finance invoice UI** *(if escalated from P0)* | Finance | Payment chain VISION #13–14 | — | P0-6 | Same as P0-6 |
| P1-02 | Owner dashboard export wiring | Management | AUDIT #1, VISION #5 | 1 d | **Done** (Phase E) | Routes to FN reports |
| P1-03 | Intelligence insight card actions | Management | AUDIT #2, VISION #5 | 1–2 d | — | Replace stubs with `context.go` targets |
| P1-04 | KPI drill-down (MG-01) | Management | AUDIT #6 | 2–3 d | Module routes | Tap KPI → finance/SIS/HR screens |
| P1-05 | Management settings save (MG-08) | Management | AUDIT #7 | 1–2 d | Repository write | Align with P0-9 pattern |
| P1-06 | SIS student profile edit + documents | SIS | PLAN P1, SPEC-SIS | 4–5 d | RBAC | Mutation providers |
| P1-07 | HR leave approve/reject (manager) | HR | SPEC-HR HR-05 | 3–4 d | RBAC | Mirror management approvals |
| P1-08 | **Academic year promotion engine (minimal)** | SIS | VISION #21, GAP Academic | 5–7 d | SIS assign | Rules + batch promote; not full reshuffle |
| P1-09 | Substitute teacher wizard (PR-10) | Teacher/Principal | GAP Teacher, SPEC-Principal | 4–5 d | Timetable, HR leave | Use existing substitute suggestions |
| P1-10 | Library fines + catalog writes | Library | PLAN P1 | 3–4 d | — | Follow library P0 pattern |
| P1-11 | Hostel leave approve + visitors register | Hostel | PLAN P1 | 3–4 d | — | Extend hostel mutations |
| P1-12 | Attendance ERP admin reconciliation | Academic | PLAN P1, QA P0-5 | 4–5 d | Teacher attendance | Bulk + reports |
| P1-13 | Finance receipt PDF (real) | Finance | AUDIT #10 | 2 d | Export infra | Replace snackbar stub |
| P1-14 | Alumni events admin create | Alumni | PLAN P1 | 3 d | — | First alumni write |

---

## P2 — Advanced automation

| ID | Feature | Module | Vision source | Est. | Depends on |
|----|---------|--------|---------------|------|------------|
| P2-01 | Student reshuffle workflow | SIS | GAP Academic | 5 d | P1-08 promotion |
| P2-02 | Section balancing engine | SIS | GAP Academic | 5 d | P2-01 |
| P2-03 | Performance-based section assignment | SIS | SRS / Principal | 5 d | Exam marks API |
| P2-04 | Teacher reassignment workflow | HR / Timetable | GAP Teacher | 5 d | Timetable publish |
| P2-05 | Timetable optimization **apply** | Timetable | VISION #8–9 | 3–4 d | Optimization read |
| P2-06 | Teacher workload rebalance actions | Timetable | VISION #9 | 4 d | P2-05 |
| P2-07 | **Reassignment continuity protocol** | SIS + Notifications | GAP Communication | 5–7 d | P1-08, P0-10 | Parent threads, bus, class groups |
| P2-08 | Workflow automation engine (MVP) | Platform | VISION design | 10+ d | Architecture review | Rules: trigger → action |
| P2-09 | Smart routing for approvals | Management | GAP Operations | 5 d | P2-08 or manual rules |
| P2-10 | Bulk class promotion wizard | SIS | PLAN P2 | 3 d | P1-08 |
| P2-11 | Inventory stock moves / allocation writes | Inventory | PLAN P1 | 4 d | P0-7 |
| P2-12 | API write parity (module batch) | All ERP | PLAN P2 | Ongoing | Agent A per module |

---

## P3 — AI, intelligence, platform

| ID | Feature | Module | Vision source | Est. | Notes |
|----|---------|--------|---------------|------|-------|
| P3-01 | **ERP Exam Admin module** | Academic | PLAN Exams ~35%, QA blocked | 15–20 d | **Product scope decision required** |
| P3-02 | Live AI inference (replace mock intelligence) | Intelligence | VISION #3, #29 | TBD | Server + model governance |
| P3-03 | Live GPS transport tracking | Transport | SPEC-TR-08 | TBD | Parent app integration |
| P3-04 | Universal Organization Builder | Platform | VISION #30 | TBD | Design complete |
| P3-05 | Multi-industry verticals | Platform | VISION #33–36 | TBD | Post-education |
| P3-06 | Server RLS enforcement | Platform | DEBT TD-P0-01 | TBD | Backend sprint |
| P3-07 | Unified reports hub | Reports | PLAN P3 | TBD | — |
| P3-08 | Scheduled report delivery | Reports | PLAN P3 | TBD | — |

---

## Selected next feature (Phase 5)

After vision reconciliation, the **highest-value unimplemented feature** with:

- Original vision traceability (payment/billing chain)  
- Clear module spec (`docs/finance.md`, FN invoice flows)  
- Existing repository methods (orphaned from UI)  
- P0 program slot already assigned  

**→ P0-6: Finance invoice create + cancel collection UI**

| Criterion | Assessment |
|-----------|------------|
| In original vision? | Yes — VISION #13–14 Unified Payment / billing |
| Implemented? | Repository partial; UI missing (**C** class) |
| Clear requirements? | Yes — SPEC-Finance + existing repo interface |
| Business value | High — closes billing loop for pilot schools |
| Dependencies | None blocking (mock-ready) |

**Do not start P0-7+ until P0-6 completes** per completion program discipline.

---

## Backlog ↔ test expectations

| Tier | Required tests |
|------|----------------|
| P0 write | `*_write_tests.dart` + RBAC deny + mock repo parity |
| P0 UI | QA keys + Patrol E2E journey |
| P1 dashboard | Widget tests + optional Patrol smoke |
| P2 workflow | Contract tests + integration where multi-module |
| P3 | Product spike doc before code |

---

## Maintenance

Update this backlog when:

1. A P0 item closes → move to **P0 closed** section in registry  
2. Vision doc adds capability → add row with source ID  
3. Reconciliation audit re-run → bump version  

**Next reconciliation trigger:** After P0 program complete (10/10) or quarterly.
