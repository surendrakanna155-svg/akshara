# Master Milestone Tracker

**Program:** Akshara Completion Program — Four Milestone Execution  
**Date:** June 2026  
**SSOT:** `docs/AKSHARA_MASTER_FEATURE_REGISTRY.md` · `docs/AKSHARA_FINAL_ROADMAP.md` · `docs/Vision/FutureVision.md`

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

## Deferred (explicit — not in four-milestone scope)

| Item | Reason |
|------|--------|
| Live ML inference | P3 — backend model service |
| Production RLS | P3-08 |
| Director portal (DR-01–08) | Spec only — separate program |
| ERP Exam Admin scope | Product decision P3-02 |

---

## Related documents

- `docs/FOUR_MILESTONE_EXECUTION_REPORT.md`
- `docs/PROJECT_BASELINE_STATUS.md`
- `docs/QA/vision_completion_progress.md`
- `docs/ADVANCED_FEATURE_STATUS.md`
