# Akshara Final Roadmap

**Version:** 1.1  
**Date:** June 2026  
**Status:** Post P0 program (10/10 complete) · ERP ~83% · INTEL-02 complete  
**Sources:** FutureVision · Master Registry v1.1 · Advanced Feature Status · ERP Completion Plan

---

## Program status

| Metric | Value |
|--------|-------|
| P0 program | **10/10 complete** |
| Weighted ERP completion | **~88%** |
| QA readiness | **~97%** |
| Flutter tests | **1405+** |
| Patrol journeys | **45+** |
| Intelligence (functional) | **~72%** |
| Copilot vision | **~80%** (see `AI_COPILOT_STATUS.md`) |
| Multi-school intelligence | **~52%** (M4) |
| Vision reconciliation | Complete |

---

## Priority tiers

| Tier | Definition | Target |
|------|------------|--------|
| **P0** | Core ERP pilot blockers | ✅ **Done** (June 2026) |
| **P1** | High-value vision + remaining ERP writes | Q3 2026 |
| **P2** | Advanced automation & structural workflows | Q4 2026 |
| **P3** | AI live inference · multi-industry · exam scope | 2027+ |

---

## P0 — Core ERP (complete)

| # | Feature | Module | Status |
|---|---------|--------|--------|
| 1 | Executive approval approve/reject | Management | ✅ |
| 2 | Library issue / return | Library | ✅ |
| 3 | Hostel allocation | Hostel | ✅ |
| 4 | HR employee CRUD | HR | ✅ |
| 5 | Transport student allocation | Transport | ✅ |
| 6 | Finance invoice / cancel collection | Finance | ✅ |
| 7 | Inventory PO approve | Inventory | → **P1** (was P0#7) |
| 8 | RBAC mutation registry | Platform | → **P1** (was P0#8) |
| 9 | Admissions settings save | Admissions | → **P1** (was P0#9) |
| 10 | Notifications broadcast | Notifications | → **P1** (was P0#10) |

---

## P1 — High-value vision features (next sprint)

| ID | Feature | Vision # | Est. | Business value |
|----|---------|----------|------|----------------|
| P1-01 | **Owner dashboard export wiring** | #5 | 1 d | Executive reporting — **Done** |
| P1-02 | KPI drill-down (MG-01) | #5 | 2–3 d | **Done** (INTEL-02) |
| P1-03 | Intelligence insight card routes | #5 | 1–2 d | **Done** (INTEL-01) |
| INTEL-03 | Context-aware copilot | #3, #29 | 2–3 d | **Done** (`1d116d2`) |
| INTEL-04 | Floating copilot dock + mobile shells | #29 | 3–5 d | **Done** |
| INTEL-05 | AI access modes + at-risk MVP | #29, #3 | 3–5 d | **Done** |
| P1-04 | Inventory PO approve + receive | — | 4–5 d | **Next** |
| P1-05 | Admissions settings persistence | — | 2–3 d | Config consistency |
| P1-06 | Notifications broadcast admin | #2 | 4–5 d | School-wide comms |
| P1-07 | RBAC mutation registry sync | — | 2–3 d | Security completeness |
| P1-08 | Academic year promotion engine (minimal) | #21 | 5–7 d | **Done** (Completion M1) |
| P1-09 | Substitute teacher wizard | #6/#9 | 4–5 d | Daily ops coverage |
| P1-10 | Book Distribution tracking (#11) | #11 | 3–4 d | Shipped v10.1 parity |
| P1-11 | SIS profile edit + documents | — | 4–5 d | Data quality |
| P1-12 | HR leave approve/reject | — | 3–4 d | HR workflow |
| P1-13 | Finance receipt PDF (real) | #14 | 2 d | Compliance |

---

## P2 — Advanced automation

| ID | Feature | Vision # | Depends on |
|----|---------|----------|------------|
| P2-01 | Student reshuffle workflow | — | P1-08 | **Done** (M1) |
| P2-02 | Section balancing engine | — | P2-01 | **Done** (M1) |
| P2-03 | Teacher reassignment | #9 | Timetable |
| P2-04 | Timetable optimization apply | #8–9 | Timetable read |
| P2-05 | Reassignment continuity protocol | — | P1-08, P1-06 | **Done** (M2) |
| P2-06 | Workflow automation engine MVP | design doc | Architecture | **Done** (M3) |
| P2-07 | Smart routing for approvals | — | P2-06 | **Done** (M3) |
| P2-08 | School Memories admin (#17) | #17 | Evolution module |
| P2-09 | Growth Platform campaigns (#18) | #18 | Marketing |
| P2-10 | API write parity (batch) | — | Agent A per module |

---

## P3 — AI intelligence & platform

| ID | Feature | Vision # | Notes |
|----|---------|----------|-------|
| P3-01 | Live AI inference | #3, #29 | Replace mock intelligence |
| P3-02 | ERP Exam Admin scope | — | Product decision |
| P3-03 | Universal Organization Builder | #30 | Design complete |
| P3-04 | Dynamic Widget Platform | #31 | Ops Hub schema seed |
| P3-05 | Multi-industry verticals | #32–36 | Post-education |
| P3-06 | QR / offline payments | #15–16 | Finance |
| P3-07 | School Branding | #20 | White label |
| P3-08 | Server RLS enforcement | DEBT | Backend |

---

## Recommended execution order (Q3 2026)

```
P1-01 Export wiring ✅
  → P1-02 KPI drill-downs ✅ (INTEL-02)
  → P1-03 Insight actions ✅ (INTEL-01)
  → INTEL-03 Context-aware copilot ✅
  → INTEL-04 Floating copilot dock ✅
  → P1-04 Inventory PO ← next
  → P1-05 Admissions settings
  → P1-06 Notifications broadcast
  → P1-07 RBAC registry
  → P1-08 Promotion engine
```

---

## Release targets

| Release | Scope | ERP % target |
|---------|-------|--------------|
| **v3.1** | P1-01–03 Owner dashboard actions | ~85% |
| **v3.2** | P1-04–07 Remaining ERP writes | ~88% |
| **v3.3** | P1-08–09 Academic + substitute | ~90% |
| **v4.0** | P2 automation cluster | ~92% |

---

## Traceability

Every item maps to:

- `AKSHARA_MASTER_FEATURE_REGISTRY.md` row  
- `FUTURE_VISION_RECONCILIATION.md` # ID (if applicable)  
- `ADVANCED_FEATURE_STATUS.md` classification  

---

## Related documents

| Document | Role |
|----------|------|
| `AKSHARA_MASTER_FEATURE_REGISTRY.md` | Feature SSOT |
| `AKSHARA_IMPLEMENTATION_BACKLOG.md` | Detailed backlog |
| `ERP_FINAL_COMPLETION_PLAN.md` | Module grades |
| `FUTURE_VISION_RECONCILIATION.md` | Vision vs registry |
| `ADVANCED_FEATURE_STATUS.md` | Advanced feature audit |
| `docs/Vision/FutureVision.md` | Original vision |
