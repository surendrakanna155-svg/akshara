# Akshara Final Roadmap

**Version:** 1.2  
**Date:** June 2026  
**Status:** Post P0 program (10/10 complete) · ERP ~88% · Four Milestone Program complete · Future Vision preserved  
**Sources:** FutureVision · Master Registry v1.2 · `FUTURE_VISION_MASTER_INDEX.md` · Four Milestone Execution Report

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
| Future vision preservation audit | Complete (`FUTURE_VISION_PRESERVATION_AUDIT.md`) |
| Tracked FutureVision capabilities | **58** (index) + **215** module rows (registry) |

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
| P1-04 | Inventory PO approve + receive | — | 4–5 d | ✅ Batch A |
| P1-05 | Admissions settings persistence | — | 2–3 d | ✅ Batch A |
| P1-06 | Notifications broadcast admin | #2 | 4–5 d | ✅ Batch A |
| P1-07 | RBAC mutation registry sync | — | 2–3 d | ✅ Batch A |
| P1-08 | Academic year promotion engine (minimal) | #21 | 5–7 d | **Done** (Completion M1) |
| P1-09 | Substitute teacher wizard | #6/#9 | 4–5 d | ✅ M7 |
| P1-10 | Book Distribution tracking (#11) | #11 | 3–4 d | Shipped v10.1 parity |
| P1-11 | SIS profile edit + documents | — | 4–5 d | ✅ M6 |
| P1-12 | HR leave approve/reject | — | 3–4 d | ✅ Batch A |
| P1-13 | Finance receipt PDF (real) | #14 | 2 d | ✅ Batch A |

---

## P2 — Advanced automation

| ID | Feature | Vision # | Depends on |
|----|---------|----------|------------|
| P2-01 | Student reshuffle workflow | — | P1-08 | **Done** (M1) |
| P2-02 | Section balancing engine | — | P2-01 | **Done** (M1) |
| P2-03 | Teacher reassignment | #9 | Timetable | ✅ M7 |
| P2-04 | Timetable optimization apply | #8–9 | Timetable read | ✅ M7 |
| P2-05 | Reassignment continuity protocol | — | P1-08, P1-06 | **Done** (M2) |
| P2-06 | Workflow automation engine MVP | design doc | Architecture | **Done** (M3) |
| P2-07 | Smart routing for approvals | — | P2-06 | **Done** (M3) |
| P2-08 | School Memories admin (#17) | #17 | Evolution module |
| P2-09 | Growth Platform campaigns (#18) | #18 | Marketing |
| P2-10 | API write parity (batch) | — | Agent A per module |

---

---

## Milestone groups (M6–M13)

Post–four-milestone execution program. SSOT index: `docs/FUTURE_VISION_MASTER_INDEX.md`.

### M6 — Remaining P1 ERP Completion

**Target:** Q3 2026 · ERP ~92%

| ID | Feature | Vision | Status |
|----|---------|--------|--------|
| P1-04 | Inventory PO approve + receive | — | ✅ Batch A |
| P1-05 | Admissions settings persistence | — | ✅ Batch A |
| P1-06 | Notifications broadcast admin | #2 | ✅ Batch A |
| P1-07 | RBAC mutation registry sync | — | ✅ Batch A |
| P1-11 | SIS profile edit + documents | — | ⏳ |
| P1-12 | HR leave approve/reject | — | ✅ Batch A |
| P1-13 | Finance receipt PDF (real) | #14 | ✅ Batch A |
| FV-15 | QR Payment Support | #15 | ✅ M6 |
| FV-16 | Offline Payment Tracking | #16 | ✅ M6 |
| FV-P4-05 | WhatsApp Business Integration | P4 | 🔄 Partial |

### M7 — Advanced Academic Platform

**Target:** Q3–Q4 2026 · Academic ops ~95%

| ID | Feature | Vision | Status |
|----|---------|--------|--------|
| P1-09 | Substitute teacher wizard | #6/#9 | ⏳ |
| P2-03 | Teacher reassignment | #9 | ⏳ |
| P2-04 | Timetable optimization apply | #8–9 | ⏳ |
| FV-11 | Book Distribution parity | #11 | ✅ v10.1 |
| FV-12 | Inventory Replacement Workflow | #12 | ⏳ |
| FV-17 | School Memories admin | #17 | ✅ v10.2 |
| FV-18 | Growth Platform campaigns | #18 | ✅ M7 |
| FV-23–27 | AI Education Suite maintenance | #22–27 | ✅ v8.5–v8.8 |
| P3-02 | ERP Exam Admin scope | — | ❌ Product decision |

### M8 — AI Evolution

**Target:** Q4 2026 · Intelligence live inference

| ID | Feature | Vision | Status |
|----|---------|--------|--------|
| FV-PLAT-10 | Live AI Inference | P3-01 | ⏳ |
| FV-29 | Universal AI Assistant | #29 | ⏳ |
| FV-28 | AI Parent Meeting Summary | #28 | ⏳ |
| FV-PLAT-07 | AI Content Generation (platform) | design | 📐 |
| FV-PLAT-05 | Resource Optimization Engine | — | ⏳ |
| FV-01–06 | Role copilot live upgrade | #1–6 | 🔄 Mock → live |

### M9 — Multi-School SaaS

**Target:** 2027 H1 · Chain/franchise operators

| ID | Feature | Vision | Status |
|----|---------|--------|--------|
| FV-PLAT-02 | Multi-School SaaS Operations | P4 | 🔄 |
| FV-PLAT-03 | Director Portal (DR-01–09) | Director.md | 📐 Spec |
| FV-PLAT-04 | Organization / Trust Intelligence | M4 | 🔄 Partial |
| FV-P4-03 | Franchise Management | P4 | 📐 Design |
| FV-P4-04 | Multi-Branch Management | P4 | 📐 Design |

### M10 — Organization Builder

**Target:** 2027 H1 · Declarative provisioning

| ID | Feature | Vision | Status |
|----|---------|--------|--------|
| FV-30 | Universal Organization Builder | #30 | 📐 v10.4 design |
| FV-PLAT-01 | Universal Employee System | design | 📐 |
| FV-A | AI School Setup Wizard | §A | 📐 v10.6 |
| FV-07 | Multi-Role Employee implementation | #7 | 🔄 v9.6 mock |

### M11 — Dynamic Widget Platform

**Target:** 2027 H2 · Tenant-scoped layouts

| ID | Feature | Vision | Status |
|----|---------|--------|--------|
| FV-31 | Dynamic Widget Platform | #31 | 📐 Ops Hub schema seed |
| — | Widget definition persistence | — | ⏳ |

### M12 — Infrastructure & Security

**Target:** Pre-GA hardening

| ID | Feature | Vision | Status |
|----|---------|--------|--------|
| FV-P4-02 | Observability Platform | P4 | 📐 |
| FV-PLAT-09 | Monitoring & Alerting | — | ⏳ |
| FV-PLAT-06 | Production Readiness Program | checklist | 🔄 70% |
| FV-PLAT-12 | Security Hardening | v2.7 | 🔄 |
| FV-PLAT-08 | Tenant Isolation Verification | probes | 🔄 213 probes |
| FV-PLAT-13 | RLS Enforcement | TD-P0-01 | 🔄 |
| FV-P4-01 | Penetration Testing | P4 | 📐 |

### M13 — Multi-Industry Expansion

**Target:** 2027+ · New verticals

| ID | Feature | Vision | Status |
|----|---------|--------|--------|
| FV-32 | Multi-Industry Vertical Framework | #32 | 📐 |
| FV-PLAT-11 | White Label Platform Expansion | ACC-08 | 🔄 |
| FV-20 | School Branding System | #20 | ⏳ |
| FV-33 | Salon ERP (Velora) | #33 | ⏳ |
| FV-34 | Hospital ERP | #34 | ⏳ |
| FV-35 | Restaurant ERP | #35 | ⏳ |
| FV-36 | Hostel ERP (full) | #36 | 🔄 Read v6.2 |

---

## P3 — AI intelligence & platform (legacy IDs → M6–M13)

| ID | Feature | Vision # | Notes |
|----|---------|----------|-------|
| P3-01 | Live AI inference | #3, #29 | **M8** FV-PLAT-10 |
| P3-02 | ERP Exam Admin scope | — | **M7** product decision |
| P3-03 | Universal Organization Builder | #30 | **M10** FV-30 |
| P3-04 | Dynamic Widget Platform | #31 | **M11** FV-31 |
| P3-05 | Multi-industry verticals | #32–36 | **M13** |
| P3-06 | QR / offline payments | #15–16 | **M6** |
| P3-07 | School Branding | #20 | **M13** FV-20 |
| P3-08 | Server RLS enforcement | DEBT | **M12** FV-PLAT-13 |

---

## Recommended execution order (Q3 2026)

```
P1-01 Export wiring ✅
  → P1-02 KPI drill-downs ✅ (INTEL-02)
  → P1-03 Insight actions ✅ (INTEL-01)
  → INTEL-03 Context-aware copilot ✅
  → INTEL-04 Floating copilot dock ✅
  → P1-04 Inventory PO ✅
  → P1-05 Admissions settings ✅
  → P1-06 Notifications broadcast ✅
  → P1-07 RBAC registry ✅
  → P1-08 Promotion engine ✅
  → P1-09 Substitute teacher wizard ✅
  → P1-11 SIS profile edit + documents ✅
  → P2-03 Teacher reassignment ✅
  → P2-04 Timetable optimization apply ✅
  → FV-18 Growth Platform campaigns ✅
  → FV-17 School Memories admin ✅
  → FV-11 Book Distribution parity ✅
  → OPS-01 Operations Hub actions ✅
  → FV-12 Inventory Replacement Workflow ← next
```

---

## Release targets

| Release | Scope | ERP % target |
|---------|-------|--------------|
| **v3.1** | P1-01–03 Owner dashboard actions | ~85% |
| **v3.2** | P1-04–07 Remaining ERP writes | ~91% ✅ |
| **v3.3** | P1-09–11 Academic + substitute | ~93% |
| **v4.0** | P2 automation cluster | ~92% |

---

## Traceability

Every item maps to:

- `FUTURE_VISION_MASTER_INDEX.md` row (canonical)  
- `AKSHARA_MASTER_FEATURE_REGISTRY.md` row  
- `MASTER_MILESTONE_TRACKER.md` section (Completed / Active / Future)  
- `FUTURE_VISION_PRESERVATION_AUDIT.md` validation (if FutureVision-sourced)  

---

## Related documents

| Document | Role |
|----------|------|
| `FUTURE_VISION_MASTER_INDEX.md` | Permanent capability index |
| `FUTURE_VISION_PRESERVATION_AUDIT.md` | Preservation audit + validation |
| `AKSHARA_MASTER_FEATURE_REGISTRY.md` | Feature SSOT |
| `MASTER_MILESTONE_TRACKER.md` | Execution status board |
| `AKSHARA_IMPLEMENTATION_BACKLOG.md` | Detailed backlog |
| `ERP_FINAL_COMPLETION_PLAN.md` | Module grades |
| `FUTURE_VISION_RECONCILIATION.md` | Prior reconciliation |
| `ADVANCED_FEATURE_STATUS.md` | Advanced feature audit |
| `docs/Vision/FutureVision.md` | Original vision |
