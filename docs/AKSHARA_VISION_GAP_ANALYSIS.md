# Akshara Vision Gap Analysis

**Version:** 1.0  
**Date:** June 2026  
**Purpose:** Reconcile original Akshara vision against current codebase — focused gap analysis  
**Registry:** `docs/AKSHARA_MASTER_FEATURE_REGISTRY.md`

---

## Executive summary

| Area | Vision items checked | Fully met | Partial / mock | Missing |
|------|---------------------|-----------|------------------|---------|
| Academic reassignment | 5 | 0 | 1 | 4 |
| Teacher operations | 4 | 0 | 3 | 1 |
| Timetable advanced | 4 | 3 | 1 | 0 |
| Communication continuity | 3 | 0 | 0 | 3 |
| Operations automation | 3 | 0 | 1 | 2 |
| Owner dashboard | 4 | 0 | 4 | 0 |
| AI intelligence | 5 | 0 | 4 | 1 |
| **Total advanced check** | **28** | **3** | **14** | **11** |

**Conclusion:** Core ERP operational workflows (P0 program) are ~90% closed. **Vision differentiators** (reassignment, continuity, automation, executive actions) remain largely **partial or unbuilt**. Timetable is the strongest advanced area (mock-functional hub). Communication migration and workflow engine are **absent**.

---

## Phase 2 — Advanced feature audit

### Academic

| Vision feature | In code? | Functional? | Tested? | Prod ready? | Evidence | Gap severity |
|----------------|----------|-------------|---------|-------------|----------|--------------|
| Student promotion | Yes | **Partial** | Partial | No | `sis_academic_assignment_screen.dart` — status toggle; no year engine | **High** — blocks bulk promotion |
| Student reshuffle | No | No | No | No | Not in codebase | **High** |
| Performance-based section assignment | No | No | No | No | Manual dropdown only | **Medium** |
| Quarterly reshuffle | No | No | No | No | — | **Medium** |
| Section balancing | No | No | No | No | — | **Medium** |

**Recommendation:** Build **Academic Year Transition Engine** (VISION #21) as P1 epic: promotion rules → section assign → timetable refresh → parent notification handoff.

---

### Teacher

| Vision feature | In code? | Functional? | Tested? | Prod ready? | Evidence | Gap severity |
|----------------|----------|-------------|---------|-------------|----------|--------------|
| Teacher reassignment | No | No | No | No | — | **High** |
| Teacher workload balancing | Yes | **Mock read** | Contract | No | `timetable_optimization_screen.dart`, Phase5 metrics | **Medium** |
| Substitute teacher assignment | Yes | **Partial** | Contract | No | `TimetableSubstituteSuggestion` in school_completion; no PR-10 wizard | **High** |
| Teacher schedule management | Yes | **Read-only** | Patrol read | No | `lib/features/teacher/timetable/` | **Low** (views exist) |

**Recommendation:** Substitute wizard (PR-10) is spec-ready P1; ties to timetable + HR leave.

---

### Timetable

| Vision feature | In code? | Functional? | Tested? | Prod ready? | Evidence | Gap severity |
|----------------|----------|-------------|---------|-------------|----------|--------------|
| Drag-and-drop builder | Yes | **Yes (mock)** | Yes | No | `timetable_editor_tab.dart`, `movePeriod` | **Low** — enhance API |
| Conflict detection | Yes | **Yes (mock)** | Yes | No | Conflicts tab, contract tests | **Low** |
| Auto scheduling | Yes | **Yes (mock)** | Integration | No | Generate tab + edge function | **Medium** — server rules |
| Schedule optimization | Yes | **Read-only** | Contract | No | Optimization screen scores only | **Medium** — no apply |

**Recommendation:** Wire optimization **apply** action + teacher workload rebalance as P2 under timetable epic.

---

### Communication

| Vision feature | In code? | Functional? | Tested? | Prod ready? | Evidence | Gap severity |
|----------------|----------|-------------|---------|-------------|----------|--------------|
| Parent continuity after reassignment | No | No | No | No | No migration logic | **High** |
| Notification migration | No | No | No | No | — | **High** |
| Message ownership migration | No | No | No | No | — | **High** |

**Related partial:** Communication Hub (ROAD v7.1), delivery analytics (`communication_delivery_screen.dart`), broadcast admin **P0#10 not started**.

**Recommendation:** Define **Reassignment Continuity Protocol** in SRS before SIS promotion engine — parent app thread IDs, class group memberships, bus route notifications.

---

### Operations

| Vision feature | In code? | Functional? | Tested? | Prod ready? | Evidence | Gap severity |
|----------------|----------|-------------|---------|-------------|----------|--------------|
| Workflow automation engine | No | No | No | No | Design doc only (`Vision/design/`) | **High** (P2) |
| Approval automation | Yes | **Manual only** | Yes | No | Management approve/reject; no rules | **Medium** |
| Smart routing | No | No | No | No | — | **High** (P2) |

---

### Owner Dashboard

| Vision feature | In code? | Functional? | Tested? | Prod ready? | Evidence | Gap severity |
|----------------|----------|-------------|---------|-------------|----------|--------------|
| KPI drill-downs | Yes | **Partial** | Partial | No | Finance drill links; KPI rows display-only (AUDIT §6) | **High** |
| Intelligence actions | Yes | **Stub** | Partial | No | ~12 insight cards `onAction` stubbed | **High** |
| AI recommendations | Yes | **Mock** | Partial | No | Approval chips, intelligence lists | **Medium** |
| Executive reports | Yes | **Partial** | Partial | No | Text summaries; export stubbed | **High** |

**Source:** `docs/OWNER_DASHBOARD_AUDIT.md` — functional ~52%, mock dependency ~85%.

**Recommendation:** P1 **Dashboard Action Wiring** sprint: export → existing report routes; insight cards → intelligence/sub-routes; KPI tap → module drill screens.

---

### AI features

| Vision feature | In code? | Functional? | Tested? | Prod ready? | Evidence | Gap severity |
|----------------|----------|-------------|---------|-------------|----------|--------------|
| Performance insights | Yes | Mock | Contract | No | Teacher effectiveness repos | Medium |
| At-risk student detection | Yes | Mock | Yes | No | Student success intelligence | Medium |
| Attendance predictions | Yes | Mock | Partial | No | `attendancePrediction` field | Medium |
| Fee collection insights | Yes | Mock | Yes | No | Finance copilot | Medium |
| Resource optimization | No | No | No | No | Inventory copilot only | Medium |

**Note:** AI **surfaces** are largely shipped (ROAD v8–v14); **live model + server inference** is the gap, not UI absence.

---

## Cross-cutting findings

### What the vision promised and we delivered

- Smart Timetable hub (generate, conflicts, drag-drop, publish path)
- AI Education Suite (question paper, homework, remarks)
- Mobile core journeys (parent pay, teacher attendance, student homework)
- Intelligence **read** dashboards + copilot shells
- P0 ERP writes: approvals, library, hostel, HR CRUD, transport allocation
- Growth platform, school memories, branding, payment stubs (evolution waves)

### What the vision promised and we did not deliver

| Category | Examples |
|----------|----------|
| **Structural academic ops** | Section reshuffle, balancing, promotion engine |
| **Staffing workflows** | Teacher reassignment, substitute wizard, workload apply |
| **Communication integrity** | Parent continuity on class/route change |
| **Automation** | Workflow engine, smart routing, rule-based approvals |
| **Owner actions** | KPI drill-downs, exports, intelligence navigation |
| **ERP exam admin** | Unified exam lifecycle (scope blocked) |

### Risk: features not lost but scattered

Features appear across **20 SRS parts**, **16 module specs**, **FutureVision 36 capabilities**, and **146 audit docs**. This reconciliation consolidates into `AKSHARA_MASTER_FEATURE_REGISTRY.md`. **No major module was dropped from planning** — gaps are **implementation depth**, not documentation absence.

---

## Traceability: vision doc → registry

| FutureVision # | Capability | Registry module | Status |
|----------------|------------|-----------------|--------|
| 21 | Academic Year Transition | SIS | **E** / partial promotion |
| 8 | Smart Timetable Expansion | Timetable | **A**–**B** |
| 9 | Workload Engine Expansion | Teacher / Timetable | **D** |
| 1–2 | AI Comms + Hub | Notifications | **D** / P0#10 |
| 3 | Student Risk Intelligence | Intelligence | **D** |
| 5 | Principal Copilot | Management / Intelligence | **B**–**D** |
| 13–16 | Payments | Finance / Parent | **B** |
| 29 | Universal AI Assistant | Copilot | **E** (P3) |
| 30–31 | Org Builder / Widgets | Evolution | **D** (design) |

---

## Prioritized gap closure (see backlog)

| Priority | Gap cluster | Rationale |
|----------|-------------|-----------|
| **P0** (remaining ERP) | Finance invoice UI, inventory PO approve, RBAC registry, admissions settings, notifications broadcast | Blocks ERP-complete |
| **P1** | Dashboard actions, promotion engine, substitute wizard, SIS profile writes, leave approve | High owner + academic value |
| **P2** | Reshuffle/balancing, workflow engine, timetable optimization apply, communication continuity | Advanced automation |
| **P3** | Live AI inference, exam admin scope, GPS tracking, multi-industry | Product decisions |

**Next implementation (post-reconciliation):** **P0#6 Finance invoice / cancel collection UI** — repo methods exist, spec clear (`finance.md`), original vision payment/billing chain incomplete without it.

---

## Validation methodology

1. Scanned `lib/features/` (33 modules) for write providers and workflow actions  
2. Cross-checked `docs/Vision/`, SRS, module specs, `ERP_FINAL_COMPLETION_PLAN.md`, `OWNER_DASHBOARD_AUDIT.md`  
3. Verified tests via `test/features/`, `test/contracts/`, `patrol_test/workflows/`  
4. Classified per registry A–F schema  

**Last validated:** June 2026 · ERP completion ~81% · Commit baseline `432d976`
