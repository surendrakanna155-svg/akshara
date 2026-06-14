# Master Milestone Tracker

**Program:** Akshara Completion Program — Four Milestone Execution + Future Vision Preservation  
**Date:** June 2026  
**SSOT:** `docs/FUTURE_VISION_MASTER_INDEX.md` · `docs/AKSHARA_MASTER_FEATURE_REGISTRY.md` · `docs/AKSHARA_FINAL_ROADMAP.md` · `docs/Vision/FutureVision.md`

---

## Tracker legend

| Status | Meaning |
|--------|---------|
| ✅ | Complete — logic, UI, repo, RBAC, tests, Patrol, docs |
| 🔄 | In progress | 
| ⏳ | Planned |
| ❌ | Blocked |

**Completion rule:** No placeholders. Each row must pass analyze + test + affected Patrol before ✅.

---

## Phase 0 — Reconciliation

| ID | Deliverable | Status | Doc |
|----|-------------|--------|-----|
| P0-1 | Master milestone tracker | ✅ | This file |
| P0-2 | Project baseline status | ✅ | `docs/PROJECT_BASELINE_STATUS.md` |
| P0-3 | Vision/registry/roadmap sync | ✅ | Updated June 2026 |

---

## Milestone 1 — Promotion & Reshuffle Engine

| Feature | Registry | Status | Implementation |
|---------|----------|--------|------------------|
| Academic year promotion engine | SIS #21, P1-08 | ✅ | `academic_operations_repository`, `sis_promotion_screen.dart` |
| Student reshuffle engine | P2-01 | ✅ | `sis_reshuffle_screen.dart`, reshuffle preview/execute |
| Performance balancing | SIS merit grouping | ✅ | Performance balance tab in `sis_section_balance_screen.dart` |
| Quarterly reshuffle | Product vision | ✅ | Quarterly tab in section balance screen |
| Section balancing | P2-02 | ✅ | Section balance preview/execute |
| Backend transition API wire | v8.0 | ✅ | `/academic/transitions/*` client layer |

**Tests:** contract, integration, widget, Patrol `sis_academic_operations_e2e_test.dart` (+3)  
**Report:** `docs/MILESTONE_1_COMPLETION_REPORT.md`

---

## Milestone 2 — Continuity Platform

| Feature | Registry | Status | Implementation |
|---------|----------|--------|------------------|
| Teacher continuity | ADVANCED §Teacher | ✅ | `continuity_repository`, teacher handoff |
| Timetable continuity | P2-04 | ✅ | `migrateTimetableSlots` |
| Parent communication continuity | P-13/14 | ✅ | Parent messaging screens + repo parity |
| Notification continuity | Notifications | ✅ | `migrateParentNotifications` |
| Assignment continuity | Homework | ✅ | `migrateHomeworkAssignments` |
| Message ownership continuity | Comm continuity | ✅ | `transferMessageOwnership` |
| Continuity migration wizard | P2-07 | ✅ | `/sis/continuity`, post-reshuffle trigger |

**Tests:** contract, integration, widget, Patrol `continuity_e2e_test.dart` (+1)  
**Report:** `docs/MILESTONE_2_COMPLETION_REPORT.md`

---

## Milestone 3 — Workflow Automation Platform

| Feature | Registry | Status | Implementation |
|---------|----------|--------|------------------|
| Rule engine | P2-06 / design doc | ✅ | `workflow_engine.dart` |
| Trigger engine | P2-06 | ✅ | `WorkflowTrigger` + executeTrigger |
| Auto approvals | Finance/admissions pattern | ✅ | `autoApprove` transitions |
| Auto routing | P2-07 | ✅ | `autoRouteToRole` transitions |
| Escalation workflows | Design doc | ✅ | `EscalationPolicy` + escalate |
| Scheduled workflows | Design doc | ✅ | `ScheduledWorkflowJob` + runScheduledJobs |
| Management UI | — | ✅ | `/management/workflow-automation` |
| At-risk trigger wire | INTEL-05 | ✅ | Student success compute → workflow enqueue |

**Tests:** engine unit, contract, integration, widget, Patrol `workflow_automation_e2e_test.dart` (+1)  
**Report:** `docs/MILESTONE_3_COMPLETION_REPORT.md`

---

## Milestone 4 — Multi-School Intelligence

| Feature | Registry | Status | Implementation |
|---------|----------|--------|------------------|
| Platform Owner intelligence | Control Center | ✅ | Platform Owner tab |
| Organization/Trust intelligence | Franchise design | ✅ | Organization tab |
| School comparison intelligence | CC analytics | ✅ | Comparison tab + `compareSchools` |
| Revenue intelligence | CC billing | ✅ | Revenue tab + MRR/ARR KPIs |
| Growth intelligence | VISION #18 | ✅ | Growth tab + pipeline |
| Risk intelligence | CC monitoring | ✅ | Risk tab + portfolio risks |
| Copilot KPI scope | INTEL-04 | ✅ | `CopilotContextScope` on intelligence screen |

**Tests:** contract, integration, widget, Patrol `platform_intelligence_e2e_test.dart` (+1)  
**Report:** `docs/MILESTONE_4_COMPLETION_REPORT.md`

---

## Intelligence program (INTEL-05–10) — included in baseline

| ID | Feature | Status |
|----|---------|--------|
| INTEL-05 | AI access modes + at-risk MVP | ✅ `c25d32f` |
| INTEL-06 | Teacher intervention suggestions | ✅ |
| INTEL-07 | Attendance intelligence | ✅ |
| INTEL-08 | Fee collection intelligence | ✅ |
| INTEL-09 | Promotion readiness scoring | ✅ |
| INTEL-10 | Unified recommendations | ✅ |

---

## Completed

Four-milestone program, intelligence program, and prior shipped evolution releases.

| Group | Items | Status | Report / refs |
|-------|-------|--------|---------------|
| **M1** Promotion & Reshuffle Engine | Promotion, reshuffle, section balance, performance balance, quarterly | ✅ | `MILESTONE_1_COMPLETION_REPORT.md` |
| **M2** Continuity Platform | Teacher/timetable/parent/notification/assignment/message continuity, wizard | ✅ | `MILESTONE_2_COMPLETION_REPORT.md` |
| **M3** Workflow Automation | Rule engine, triggers, auto-approve, routing, escalation, scheduled jobs, UI | ✅ | `MILESTONE_3_COMPLETION_REPORT.md` |
| **M4** Multi-School Intelligence | Platform Owner, org/trust, comparison, revenue, growth, risk, copilot scope | ✅ | `MILESTONE_4_COMPLETION_REPORT.md` |
| **INTEL-05–10** | AI access modes, at-risk MVP, teacher intervention, attendance/fee intel, promotion readiness, unified recommendations | ✅ | `intelligence_program_mvp_test.dart` |
| **P0 ERP writes (7 direct)** | Executive approval, library, hostel, HR CRUD, transport allocation, finance invoice/cancel | ✅ | P0 program |
| **P1 shipped** | Owner export, KPI drill-down, insight routes, INTEL-03/04, promotion engine (P1-08) | ✅ | INTEL completion reports |
| **Evolution v8–v10** | Year transition, intelligence layer, education suite, Phase 5 modules (v9.8–v10.4) | ✅ | `Roadmap.md`, release docs |
| **AI Education Suite** | FV-23–27 question papers, bank, homework, worksheet, remarks | ✅ | v8.5–v8.8 |

---

## Batch A — P1 Closure Program ✅

**Baseline:** `37c1676` · **Report:** `docs/BATCH_A_COMPLETION_REPORT.md`

| ID | Feature | Status | Implementation |
|----|---------|--------|----------------|
| P1-04 | Inventory PO approve + receive | ✅ | `approveProcurementHandoff`, `receiveProcurementHandoff`, approval history |
| P1-05 | Admissions settings persistence | ✅ | `updateSettings`, editable UI + Save |
| P1-06 | Notifications broadcast admin | ✅ | `broadcast_admin_screen.dart`, Communication Hub link |
| P1-07 | RBAC mutation registry sync | ✅ | 41 registry entries, `docs/RBAC_SYNC_REPORT.md` |
| P1-12 | HR leave approve/reject | ✅ | Comment dialog, audit, broadcast notification |
| P1-13 | Finance receipt PDF | ✅ | `finance_receipt_pdf_service.dart`, router download/share |

**Tests:** +7 (1412 total) · **Patrol:** +4 journeys (~49) · **ERP:** ~91%

---

## Active

Current sprint and in-flight work (Q3 2026).

| ID | Feature | Registry | Milestone | Status | Notes |
|----|---------|----------|-----------|--------|-------|
| P1-11 | SIS profile edit + documents | SIS | M6 | ✅ | Profile edit + upload |
| P1-09 | Substitute teacher wizard | Teacher | M7 | ✅ | `substitute_manager_screen.dart` |
| P2-03 | Teacher reassignment | Teacher | M7 | ✅ | `teacher_reassignment_screen.dart` |
| P2-04 | Timetable optimization apply | Timetable | M7 | ✅ | Apply on optimization screen |
| FV-18 | Growth Platform campaigns | Marketing | M7 | ✅ | `evolution_mutations_provider.dart` |
| FV-PLAT-04 | Organization / Trust Intelligence | Control Center | M9 | 🔄 | M4 tab shipped; full trust rollup pending |
| FV-PLAT-08 | Tenant Isolation Verification | Platform | M12 | 🔄 | 213 probes passing |
| FV-PLAT-13 | RLS Enforcement | Platform | M12 | 🔄 | TD-P0-01 partial |
| FV-PLAT-12 | Security Hardening | Platform | M12 | 🔄 | v2.7 baseline |

---

## Future Milestones

Post–four-milestone program. Full feature list: `docs/FUTURE_VISION_MASTER_INDEX.md`.

### M6 — Remaining P1 ERP Completion

| ID | Feature | Status |
|----|---------|--------|
| P1-04 | Inventory PO approve + receive | ✅ Batch A |
| P1-05 | Admissions settings persistence | ✅ Batch A |
| P1-06 | Notifications broadcast admin | ✅ Batch A |
| P1-07 | RBAC mutation registry sync | ✅ Batch A |
| P1-11 | SIS profile edit + documents | ✅ M6 |
| P1-12 | HR leave approve/reject | ✅ Batch A |
| P1-13 | Finance receipt PDF | ✅ Batch A |
| FV-15–16 | QR / offline payments | ⏳ |

### M7 — Advanced Academic Platform

| ID | Feature | Status |
|----|---------|--------|
| P1-09 | Substitute teacher wizard | ✅ |
| P2-03 | Teacher reassignment | ✅ |
| P2-04 | Timetable optimization apply | ✅ |
| FV-11 | Book Distribution parity | 🔄 |
| FV-12 | Inventory Replacement Workflow | ⏳ |
| FV-17 | School Memories admin | 🔄 |
| FV-18 | Growth Platform campaigns | ✅ |
| P3-02 | ERP Exam Admin scope decision | ❌ Blocked |

### M8 — AI Evolution

| ID | Feature | Status |
|----|---------|--------|
| FV-PLAT-10 | Live AI Inference | ⏳ |
| FV-29 | Universal AI Assistant | ⏳ |
| FV-28 | AI Parent Meeting Summary | ⏳ |
| FV-PLAT-07 | AI Content Generation (platform) | 📐 Design |
| FV-PLAT-05 | Resource Optimization Engine | ⏳ |
| FV-01–06 | Role copilots (live inference upgrade) | 🔄 |

### M9 — Multi-School SaaS

| ID | Feature | Status |
|----|---------|--------|
| FV-PLAT-02 | Multi-School SaaS Operations | 🔄 |
| FV-PLAT-03 | Director Portal (DR-01–09) | 📐 Spec |
| FV-PLAT-04 | Organization / Trust Intelligence (full) | 🔄 |
| FV-P4-03 | Franchise Management | 📐 Design |
| FV-P4-04 | Multi-Branch Management | 📐 Design |

### M10 — Organization Builder

| ID | Feature | Status |
|----|---------|--------|
| FV-30 | Universal Organization Builder | 📐 Design |
| FV-PLAT-01 | Universal Employee System | 📐 Design |
| FV-A | AI School Setup Wizard | 📐 Design |
| FV-07 | Multi-Role Employee (implementation) | 🔄 |

### M11 — Dynamic Widget Platform

| ID | Feature | Status |
|----|---------|--------|
| FV-31 | Dynamic Widget Platform | 📐 Design |
| — | Operations Hub widget persistence | ⏳ |

### M12 — Infrastructure & Security

| ID | Feature | Status |
|----|---------|--------|
| FV-P4-02 | Observability Platform | 📐 Design |
| FV-PLAT-09 | Monitoring & Alerting | ⏳ |
| FV-PLAT-06 | Production Readiness Program | 🔄 |
| FV-PLAT-12 | Security Hardening | 🔄 |
| FV-PLAT-08 | Tenant Isolation Verification | 🔄 |
| FV-PLAT-13 | RLS Enforcement | 🔄 |
| FV-P4-01 | Penetration Testing | 📐 Design |

### M13 — Multi-Industry Expansion

| ID | Feature | Status |
|----|---------|--------|
| FV-32 | Multi-Industry Vertical Framework | 📐 Design |
| FV-PLAT-11 | White Label Platform Expansion | 🔄 |
| FV-20 | School Branding System | ⏳ |
| FV-33 | Salon ERP (Velora) | ⏳ |
| FV-34 | Hospital ERP | ⏳ |
| FV-35 | Restaurant ERP | ⏳ |
| FV-36 | Hostel ERP (full write path) | 🔄 |

---

## Platform Evolution

| Capability | Milestone | Status |
|------------|-----------|--------|
| Universal Employee System (FV-PLAT-01) | M10 | 📐 Design |
| Dynamic Widget Platform (FV-31) | M11 | 📐 Design |
| Universal Organization Builder (FV-30) | M10 | 📐 Design |
| Universal AI Assistant (FV-29) | M8 | ⏳ |

---

## Multi-School SaaS

| Capability | Milestone | Status |
|------------|-----------|--------|
| Multi-School Operations (FV-PLAT-02) | M9 | 🔄 |
| Director Portal (FV-PLAT-03) | M9 | 📐 Spec |
| Organization / Trust Intelligence (FV-PLAT-04) | M9 | 🔄 |
| Franchise Management (FV-P4-03) | M9 | 📐 Design |
| Multi-Branch Management (FV-P4-04) | M9 | 📐 Design |

---

## AI Evolution

| Capability | Milestone | Status |
|------------|-----------|--------|
| AI Question Paper Generation (FV-23) | M7 | ✅ |
| AI Content Generation (FV-PLAT-07) | M8 | 📐 Design |
| AI Parent Meeting Summary (FV-28) | M8 | ⏳ |
| Live AI Inference (FV-PLAT-10) | M8 | ⏳ |
| Resource Optimization Engine (FV-PLAT-05) | M8 | ⏳ |

---

## Infrastructure & Security

| Capability | Milestone | Status |
|------------|-----------|--------|
| Observability Platform (FV-P4-02) | M12 | 📐 Design |
| Monitoring & Alerting (FV-PLAT-09) | M12 | ⏳ |
| Production Readiness Program (FV-PLAT-06) | M12 | 🔄 |
| Security Hardening (FV-PLAT-12) | M12 | 🔄 |
| Tenant Isolation Verification (FV-PLAT-08) | M12 | 🔄 |
| RLS Enforcement (FV-PLAT-13) | M12 | 🔄 |
| Penetration Testing (FV-P4-01) | M12 | 📐 Design |

---

## Multi-Industry Expansion

| Capability | Milestone | Status |
|------------|-----------|--------|
| Multi-Industry Vertical Framework (FV-32) | M13 | 📐 Design |
| White Label Platform Expansion (FV-PLAT-11) | M13 | 🔄 |
| School Branding System (FV-20) | M13 | ⏳ |
| Salon / Hospital / Restaurant / Hostel packs (FV-33–36) | M13 | ⏳ / 🔄 |

---

## Deferred (explicit — product decisions)

| Item | Reason | Milestone |
|------|--------|-----------|
| ERP Exam Admin scope | Product decision | M7 (P3-02) |
| First non-education vertical pilot | Depends M10 + M13 | M13 |

---

## Related documents

- `docs/FUTURE_VISION_PRESERVATION_AUDIT.md` (new)
- `docs/FUTURE_VISION_MASTER_INDEX.md` (new — permanent capability index)
- `docs/FOUR_MILESTONE_EXECUTION_REPORT.md`
- `docs/PROJECT_BASELINE_STATUS.md`
- `docs/QA/vision_completion_progress.md`
- `docs/ADVANCED_FEATURE_STATUS.md`
