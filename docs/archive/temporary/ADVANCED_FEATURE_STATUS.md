# Advanced Feature Status

**Version:** 1.0  
**Date:** June 2026  
**Purpose:** Phase C audit — advanced / vision differentiator features  
**Classification:** **A** Fully Implemented · **B** Partial · **C** Mock Only · **D** Not Implemented

---

## Academic Operations

| Feature | Class | In code | Functional E2E | Tests | Key files | Gaps |
|---------|-------|---------|----------------|-------|-----------|------|
| Student promotion | **B** | Yes | Partial (status toggle) | Partial | `sis_academic_assignment_screen.dart` | No year engine, bulk rules |
| Student reshuffle | **D** | No | No | No | — | Spec only |
| Performance-based section assignment | **D** | No | No | No | — | Manual assign only |
| Quarterly reshuffle | **D** | No | No | No | — | — |
| Automatic section balancing | **D** | No | No | No | — | — |

---

## Teacher Operations

| Feature | Class | In code | Functional E2E | Tests | Key files | Gaps |
|---------|-------|---------|----------------|-------|-----------|------|
| Teacher reassignment | **D** | No | No | No | — | PR spec only |
| Teacher workload balancing | **C** | Yes | Read-only metrics | Contract | `timetable_optimization_screen.dart` | No apply/rebalance |
| Substitute teacher assignment | **C** | Yes | Suggestions only | Contract | `TimetableSubstituteSuggestion` | No PR-10 wizard |
| Teacher continuity workflows | **D** | No | No | No | — | Leave → substitute chain incomplete |

---

## Timetable

| Feature | Class | In code | Functional E2E | Tests | Key files | Gaps |
|---------|-------|---------|----------------|-------|-----------|------|
| Drag-and-drop scheduling | **A** | Yes | Yes (mock) | Yes | `timetable_editor_tab.dart` | API prod |
| Conflict detection | **A** | Yes | Yes (mock) | Contract | Conflicts tab | — |
| Auto timetable generation | **B** | Yes | Yes (mock) | Integration | Generate tab | Server rules |
| Timetable migration after reassignment | **D** | No | No | No | — | Depends promotion/reshuffle |

---

## Communication Continuity

| Feature | Class | In code | Functional E2E | Tests | Key files | Gaps |
|---------|-------|---------|----------------|-------|-----------|------|
| Parent communication migration | **D** | No | No | No | — | Reassignment protocol undefined |
| Teacher message ownership transfer | **D** | No | No | No | — | — |
| Notification continuity | **D** | No | No | No | — | — |
| Announcement continuity | **D** | No | No | No | — | Broadcast admin P1 |

---

## Owner Dashboard

| Feature | Class | In code | Functional E2E | Tests | Key files | Gaps |
|---------|-------|---------|----------------|-------|-----------|------|
| KPI drill-downs | **B** | Yes | Finance defaulter only | Partial | `management_dashboard_screen.dart` | ~85 KPIs display-only |
| Executive actions | **B** | Yes | Quick actions work | Partial | Quick action routes | Export was stub → **Phase E** |
| Approval shortcuts | **A** | Yes | Yes | Patrol | Tasks + approval E2E | Dashboard preview read-only |
| Intelligence actions | **C** | Yes | Stub (~12 cards) | Partial | Insight cards | `onAction` stubs |

---

## AI Features

| Feature | Class | In code | Functional E2E | Tests | Key files | Gaps |
|---------|-------|---------|----------------|-------|-----------|------|
| At-risk student detection | **C** | Yes | Mock compute | Yes | `student_success_screen.dart` | Live model |
| Performance insights | **C** | Yes | Mock | Contract | `teacher_effectiveness/` | Server inference |
| Attendance insights | **C** | Yes | Mock fields | Partial | `student_success_models.dart` | — |
| Fee insights | **C** | Yes | Mock | Patrol finance | `finance_copilot_screen.dart` | — |
| Resource optimization | **D** | No | No | No | Inventory copilot only | School-wide absent |

---

## Workflow Automation

| Feature | Class | In code | Functional E2E | Tests | Key files | Gaps |
|---------|-------|---------|----------------|-------|-----------|------|
| Workflow engine | **D** | No | No | No | `Vision/design/Universal-Workflow-Engine.md` | Design only |
| Auto approvals | **B** | Yes | Manual approve/reject | Patrol | Management mutations | No rules |
| Auto routing | **D** | No | No | No | — | — |
| Rule-based automation | **D** | No | No | No | — | — |

---

## Summary scorecard

| Domain | A | B | C | D |
|--------|---|---|---|---|
| Academic ops | 0 | 1 | 0 | 4 |
| Teacher ops | 0 | 0 | 2 | 2 |
| Timetable | 2 | 1 | 0 | 1 |
| Communication continuity | 0 | 0 | 0 | 4 |
| Owner dashboard | 1 | 2 | 1 | 0 |
| AI | 0 | 0 | 4 | 1 |
| Workflow automation | 0 | 1 | 0 | 3 |
| **Total** | **3** | **5** | **7** | **15** |

**Strongest:** Timetable drag-drop + conflicts (A)  
**Weakest:** Communication continuity + academic reshuffle (all D)  
**Highest ROI next:** Owner dashboard actions (B→A), Academic promotion engine (B→A), Substitute wizard (C→A)

---

## Validation method

1. Code search in `lib/features/` for write providers and workflow actions  
2. Patrol inventory (`qa/patrol/run_erp_coverage.sh`)  
3. Contract tests in `test/contracts/`  
4. Cross-check `OWNER_DASHBOARD_AUDIT.md` and `FutureVision.md`

**Baseline commit:** `eff64bb` (P0 #6 complete)

**Related:** `FUTURE_VISION_RECONCILIATION.md` · `AKSHARA_FINAL_ROADMAP.md`
