# Akshara Master Feature Registry

**Version:** 1.3  
**Date:** June 2026  
**Purpose:** Single source of truth — every planned feature traced to source documents and current implementation status  
**Baseline:** ERP completion ~91% · Post-RT operational layer · QA readiness ~97% · `release/v1.0-preprod`

---

## How to use this document

| Question | Section |
|----------|---------|
| Was feature X in the original vision? | Find row → **Original source** |
| Is it built? | **Classification** + **Validation** columns |
| What files/tests cover it? | **Implementation refs** |
| What's next? | `docs/AKSHARA_FINAL_ROADMAP.md` M6–M13 |
| Is every FutureVision item tracked? | **FutureVision Capability Registry** (below) + `FUTURE_VISION_MASTER_INDEX.md` |

**Classification key**

| Code | Meaning |
|------|---------|
| **A** | Fully implemented — functional in mock/API with tests |
| **B** | Partially implemented — read or write gaps |
| **C** | UI only — screens without repository writes |
| **D** | Mock only — repository mock; API stub or no UI action |
| **E** | Not implemented — specified but no code surface |
| **F** | Deprecated / superseded / scope undefined |

**Validation columns (Phase 3)**

| Column | Definition |
|--------|------------|
| **In code** | Yes/No — any lib/ surface |
| **Functional** | Yes/Partial/No — end-to-end user action works |
| **Tested** | Yes/Partial/No — unit/contract/Patrol |
| **Prod ready** | Yes/No — server API + RBAC + audit (most = No in pilot) |

---

## Source document index

| ID | Document | Role |
|----|----------|------|
| SRS | `docs/Akshara_ERP_Master_SRS_Part_*.txt` (20 parts) | Full PRD / NFR corpus |
| ROAD | `docs/Roadmap.md` | Shipped release history |
| VISION | `docs/Vision/FutureVision.md` | Long-term capability map |
| VROAD | `docs/Vision/ImplementationRoadmap.md` | Dependency-ordered evolution |
| PLAN | `docs/ERP_FINAL_COMPLETION_PLAN.md` | P0–P3 ERP completion |
| SPEC-* | `docs/{Module}.md` | Screen-level module specs |
| AUDIT | `docs/OWNER_DASHBOARD_AUDIT.md` | Owner dashboard functional audit |
| QA | `docs/QA/autonomous_backlog.md` | Journey QA backlog |
| AGENTS | `AGENTS.md` | Agent ownership boundaries |
| FUTURE | `docs/FUTURE_VISION_MASTER_INDEX.md` | Permanent capability index |
| PRESERVE | `docs/FUTURE_VISION_PRESERVATION_AUDIT.md` | Preservation audit |
| SYNC | `docs/DOCUMENTATION_SYNC_REPORT.md` | June 2026 documentation sync |
| POSTRT | `docs/ArchitectureReview/v1.0-Post-RedTeam-Operational-Hardening.md` | Post-RT architecture |

---

## FutureVision Capability Registry

**Rule:** No FutureVision item may exist without a row here. Canonical index: `docs/FUTURE_VISION_MASTER_INDEX.md`.

| ID | Feature | Priority | Status | Completion % | Milestone | Test | Prod | Registry module |
|----|---------|----------|--------|:------------:|-----------|:----:|:----:|-----------------|
| FV-01 | AI Communication Assistant | P1 | Partial | 55 | M8 | Partial | No | Notifications |
| FV-02 | Communication Hub Expansion | P1 | Partial | 45 | M6 | Partial | No | Notifications |
| FV-03 | Student Risk Intelligence | P2 | Partial | 60 | M8 | Yes | No | Intelligence |
| FV-04 | Parent Guidance Assistant | P2 | Partial | 50 | M8 | Partial | No | Mobile / AI |
| FV-05 | Principal Copilot | P2 | Partial | 65 | M8 | Partial | No | Management / AI |
| FV-06 | Teacher Copilot | P2 | Partial | 50 | M8 | Partial | No | Teacher |
| FV-07 | Multi-Role Employee System | P3 | Partial | 40 | M10 | Contract | No | HR / Phase5 |
| FV-08 | Smart Timetable Expansion | P2 | Partial | 85 | M7 | Yes | Partial | Timetable |
| FV-09 | Workload Engine Expansion | P2 | Partial | 35 | M7 | Contract | No | Timetable / Teacher |
| FV-10 | Inventory & Asset Expansion | P3 | Partial | 60 | M6 | Yes | No | Inventory |
| FV-11 | Book Distribution System | P3 | Shipped | 95 | M7 ✅ | Yes | Partial | Evolution |
| FV-12 | Inventory Replacement Workflow | P3 | Shipped | 95 | M7 ✅ | Yes | Partial | Inventory |
| FV-13 | Unified Payment Request Engine | P1 | Partial | 55 | M6 | Yes | No | Finance |
| FV-14 | Online Payment Enhancements | P1 | Partial | 60 | M6 | Yes | No | Finance / Parent |
| FV-15 | QR Payment Support | P1 | Planned | 0 | M6 | No | No | Finance |
| FV-16 | Offline Payment Tracking | P1 | Planned | 0 | M6 | No | No | Finance |
| FV-17 | School Memories | P2 | Shipped | 95 | M7 ✅ | Yes | Partial | Evolution |
| FV-18 | Akshara Growth Platform | P2 | Partial | 45 | M7 | Partial | No | Marketing |
| FV-19 | Achievement Promotion Engine | P2 | Partial | 65 | M7 | Partial | No | Evolution |
| FV-20 | School Branding System | P2 | Planned | 0 | M13 | No | No | Platform |
| FV-21 | Academic Year Transition Engine | P1 | Shipped | 100 | M1 ✅ | Yes | Partial | SIS |
| FV-22 | AI Education Suite (umbrella) | P2 | Shipped | 95 | M7 ✅ | Yes | No | Academic / AI |
| FV-23 | AI Question Paper Generator | P2 | Shipped | 95 | M7 ✅ | Yes | No | Academic |
| FV-24 | AI Question Bank | P2 | Shipped | 95 | M7 ✅ | Yes | No | Academic |
| FV-25 | AI Homework Generator | P2 | Shipped | 90 | M7 ✅ | Yes | No | Academic |
| FV-26 | AI Worksheet Generator | P2 | Shipped | 90 | M7 ✅ | Yes | No | Academic |
| FV-27 | AI Report Card Remarks | P2 | Shipped | 90 | M7 ✅ | Yes | No | Academic |
| FV-28 | AI Parent Meeting Summary | P2 | Planned | 0 | M8 | No | No | Intelligence |
| FV-29 | Universal AI Assistant | P3 | Planned | 20 | M8 | Partial | No | Platform / AI |
| FV-30 | Universal Organization Builder | P3 | Design | 10 | M10 | No | No | Platform |
| FV-31 | Dynamic Widget Platform | P3 | Design | 15 | M11 | No | No | Platform / Management |
| FV-32 | Multi-Industry Vertical Framework | P4 | Shipped | 85 | M13 | Yes | No | Platform |
| FV-33 | Salon ERP Foundation / Healthcare (mission) | P4 | Shipped MVP | 75 | M13 | Yes | No | Platform |
| FV-34 | Hospital ERP Foundation / Salon (mission) | P4 | Shipped MVP | 75 | M13 | Yes | No | Platform |
| FV-35 | Restaurant ERP Foundation | P4 | Shipped MVP | 75 | M13 | Yes | No | Platform |
| FV-36 | Hostel ERP Foundation (full) | P4 | Shipped MVP | 80 | M13 | Yes | No | Hostel |
| FV-A | AI School Setup Wizard | P3 | Design | 25 | M10 | Partial | No | Platform |
| FV-P4-01 | Security & Penetration Testing | P4 | Design | 5 | M12 | No | No | Platform |
| FV-P4-02 | Observability Platform | P4 | Shipped | 90 | M12 | Yes | No | Platform |
| FV-P4-03 | Franchise Management | P4 | Shipped MVP | 70 | M9 | Yes | No | Platform |
| FV-P4-04 | Multi-Branch Management | P4 | Shipped MVP | 70 | M9 | Yes | No | Platform |
| FV-P4-05 | WhatsApp Business Integration | P1/P2 | Partial | 35 | M6/M8 | Contract | No | Notifications |
| FV-P4-06 | Universal Workflow Engine | P3 | Shipped | 90 | M3 ✅ | Yes | Partial | Operations |
| FV-PLAT-01 | Universal Employee System | P3 | Design | 10 | M10 | No | No | Platform |
| FV-PLAT-02 | Multi-School SaaS Operations | P4 | Shipped | 85 | M9 | Yes | No | Control Center |
| FV-PLAT-03 | Director Portal (DR-01–09) | P4 | Shipped | 90 | M9 | Yes | No | Director |
| FV-PLAT-04 | Organization / Trust Intelligence | P4 | Shipped | 90 | M9 | Yes | No | Control Center |
| FV-PLAT-05 | Resource Optimization Engine | P2 | Planned | 5 | M8 | No | No | Intelligence |
| FV-PLAT-06 | Production Readiness Program | P4 | Shipped | 85 | M12 | Yes | Partial | Platform |
| FV-PLAT-07 | AI Content Generation (platform) | P2 | Design | 15 | M8 | No | No | Academic / AI |
| FV-PLAT-08 | Tenant Isolation Verification | P4 | Shipped | 90 | M12 | Yes | Partial | Platform |
| FV-PLAT-09 | Monitoring & Alerting | P4 | Shipped | 85 | M12 | Yes | No | Platform |
| FV-PLAT-10 | Live AI Inference | P3 | Planned | 15 | M8 | Partial | No | Intelligence / AI |
| FV-PLAT-11 | White Label Platform Expansion | P4 | Shipped | 85 | M13 | Yes | No | Platform |
| FV-PLAT-12 | Security Hardening | P4 | Shipped | 88 | M12 | Yes | Partial | Platform |
| FV-PLAT-13 | RLS Enforcement | P4 | Partial | 65 | M12 | Yes | Partial | Platform |

### Post-RT Operational Hardening Registry (June 2026)

| ID | Feature | Priority | Status | Completion % | Milestone | Test | Prod | Registry module |
|----|---------|----------|--------|:------------:|-----------|:----:|:----:|-----------------|
| FV-POST-01 | Exam Administration Publish Workflow | P1 | Shipped | 85 | Post-RT | Yes | No | Teacher / Exams |
| FV-POST-02 | Parent Communication Governance | P1 | Shipped | 80 | Post-RT | Yes | No | Communication |
| FV-POST-03 | Class Teacher Governance | P1 | Shipped | 75 | Post-RT | Yes | No | Teacher / HR |
| FV-POST-04 | Subject Teacher Escalation | P1 | Shipped | 80 | Post-RT | Yes | No | Communication |
| FV-POST-05 | Student 360 Risk View | P2 | Shipped | 75 | Post-RT | Partial | No | Teacher mobile |
| FV-POST-06 | Students Requiring Attention Today | P2 | Shipped | 75 | Post-RT | Partial | No | Teacher mobile |
| FV-POST-07 | Unified Onboarding Wizard | P1 | Partial | 70 | Post-RT | Yes | Partial | Onboarding |
| FV-POST-08 | Translation Framework | P1 | Partial | 65 | Post-RT | Partial | No | i18n |
| FV-POST-09 | Backup & Restore Architecture | P2 | Partial | 40 | Post-RT | No | No | Admin |
| FV-POST-10 | Red Team Remediation | P0 | Shipped | 95 | Post-RT | Yes | Partial | Platform |
| FV-POST-11 | Parent Inbox Integration | P1 | Partial | 60 | Post-RT | Partial | No | Parent mobile |
| FV-POST-12 | HR/SIS Teacher Assignment Mapping | P2 | Partial | 35 | Post-RT | No | No | HR / SIS |
| FV-POST-13 | School Config Remote Sync | P2 | Partial | 30 | Post-RT | Partial | No | Platform |
| FV-M15-01 | M15 Theme Modernization | P3 | Planned | 5 | M15 | No | No | Theme |
| FV-DEF-01 | Academic Assessment Platform | P2 | Deferred | 10 | — | No | No | Academic |

**Status key:** Shipped = classification A/B mock-first + unit tests · Partial = persistence or rollout gaps · Deferred = explicit product decision

---

## Registry summary by module

| Module | Features tracked | A | B | C | D | E | F |
|--------|------------------|---|---|---|---|---|---|
| Admissions | 12 | 5 | 4 | 1 | 1 | 1 | 1 |
| SIS | 14 | 4 | 6 | 1 | 2 | 1 | 0 |
| Finance | 16 | 6 | 7 | 1 | 2 | 0 | 0 |
| Management / Owner | 18 | 2 | 11 | 2 | 3 | 0 | 0 |
| Academic / Education | 15 | 5 | 6 | 2 | 1 | 1 | 0 |
| HR / Payroll | 12 | 4 | 6 | 1 | 1 | 0 | 0 |
| Transport | 10 | 3 | 5 | 1 | 1 | 0 | 0 |
| Hostel | 10 | 2 | 6 | 1 | 1 | 0 | 0 |
| Library | 8 | 2 | 4 | 1 | 1 | 0 | 0 |
| Inventory | 11 | 3 | 5 | 1 | 2 | 0 | 0 |
| Alumni | 8 | 0 | 3 | 2 | 3 | 0 | 0 |
| Notifications | 6 | 0 | 2 | 2 | 2 | 0 | 0 |
| Intelligence / AI | 22 | 8 | 10 | 0 | 4 | 0 | 0 |
| Timetable | 8 | 3 | 4 | 0 | 1 | 0 | 0 |
| Teacher ops | 8 | 1 | 3 | 2 | 1 | 1 | 0 |
| Communication continuity | 6 | 0 | 1 | 0 | 0 | 5 | 0 |
| Operations automation | 5 | 0 | 2 | 0 | 1 | 2 | 0 |
| Mobile (P/T/S) | 18 | 10 | 6 | 0 | 2 | 0 | 0 |
| Control Center | 8 | 3 | 3 | 1 | 1 | 0 | 0 |
| Platform (auth/RBAC/audit) | 8 | 5 | 1 | 0 | 1 | 1 | 0 |
| **Total (approx.)** | **~215** | **65** | **86** | **18** | **28** | **12** | **2** |

---

## Admissions

| Feature | Module | Source | Business value | Dependencies | Class | In code | Functional | Tested | Prod | Implementation refs | Gaps |
|---------|--------|--------|----------------|--------------|-------|---------|------------|--------|------|---------------------|------|
| Lead CRM & pipeline | Admissions | SPEC-Admissions, ROAD | Enrollment funnel | Auth, RBAC | **A** | Yes | Yes | Yes | No | `lib/features/admissions/`, Patrol admissions E2E | API parity P2 |
| Application submit/approve/reject | Admissions | SPEC-Admissions, PLAN | Close enrollment loop | SIS handoff | **A** | Yes | Yes | Yes | No | `admissions_mutations_provider.dart` | — |
| Enrollment conversion | Admissions | SPEC-Admissions | Student onboarding | SIS | **A** | Yes | Yes | Yes | No | `enrollment_*`, Patrol | — |
| Document verification queue | Admissions | SPEC-Admissions | Compliance | — | **B** | Yes | Partial | Partial | No | Read screens | Write workflow |
| Fee handoff to Finance | Admissions | SPEC-Admissions | Revenue | Finance | **B** | Yes | Partial | Yes | No | FN handoff queue | — |
| Admissions analytics | Admissions | SPEC-Admissions AD-09 | Funnel insight | — | **B** | Yes | Read | Partial | No | Reports screens | Export |
| Settings persistence | Admissions | PLAN P0#9 | Config consistency | Management settings | **A** | Yes | Yes | Yes | No | `updateSettings`, Patrol | — |
| Bulk lead import | Admissions | PLAN P3 | Scale ops | — | **E** | No | No | No | No | — | Future |
| Marketing → AD funnel | Admissions | SPEC-Marketing | Growth | Marketing | **D** | Yes | Mock | Partial | No | Growth platform reads | Integration |
| Campaign automation | Admissions | VISION #18 | Lead gen | Marketing | **F** | Partial | Partial | No | No | Growth v11.4 | Not AD-native |

---

## SIS (Student Information System)

| Feature | Module | Source | Business value | Dependencies | Class | In code | Functional | Tested | Prod | Implementation refs | Gaps |
|---------|--------|--------|----------------|--------------|-------|---------|------------|--------|------|---------------------|------|
| Student registry | SIS | SPEC-SIS, ROAD | Core record | Auth | **A** | Yes | Yes | Yes | No | `sis_*`, Patrol SIS | — |
| Register / convert enrollment | SIS | SPEC-SIS, PLAN | AD→SIS | Admissions | **A** | Yes | Yes | Yes | No | Mutations + E2E | — |
| Academic class/section assign | SIS | SPEC-SIS | Placement | Academic structure | **B** | Yes | Partial | Yes | No | `sis_academic_assignment_screen.dart` | Manual only |
| Student profile edit | SIS | PLAN P1 | Data quality | RBAC | **A** | Yes | Yes | Yes | No | `sis_profile_edit_sheet.dart`, Patrol | — |
| Document vault upload | SIS | SPEC-SIS SIS-07 | Compliance | Storage | **C** | Yes | No | No | No | UI placeholder | Upload API |
| **Student promotion (year rollover)** | SIS | SPEC-SIS, VISION #21 | Academic continuity | Timetable, Finance | **A** | Yes | Yes | Yes | Partial | `sis_promotion_screen.dart`, academic operations repo | API prod parity |
| **Student reshuffle** | SIS | SPEC-SIS, SRS | Section balance | Academic | **A** | Yes | Yes | Yes | Partial | `sis_reshuffle_screen.dart` | API prod |
| **Performance-based section assignment** | SIS | SRS / Principal | Merit grouping | Exams | **B** | Yes | Yes | Partial | Partial | Performance balance tab | Live exam feed |
| **Quarterly reshuffle** | SIS | Product vision | Flexibility | SIS | **B** | Yes | Yes | Partial | Partial | Quarterly tab | — |
| **Section balancing** | SIS | Product vision | Class size equity | SIS | **A** | Yes | Yes | Yes | Partial | `sis_section_balance_screen.dart` | API prod |
| Transfer & TC / exit | SIS | SPEC-SIS | Lifecycle | Alumni | **B** | Yes | Read | Partial | No | Exit screens | Write workflow |
| Bulk class promotion | SIS | PLAN P2 | Efficiency | Promotion engine | **E** | No | No | No | No | — | Depends promotion |
| Student 360 profile | SIS | ROAD v9.5 | Unified view | All modules | **D** | Yes | Mock | Yes | No | `student_360/` | Cross-module API |
| Parent mapping | SIS | SPEC-SIS | Parent app | Parent mobile | **A** | Yes | Yes | Yes | No | SIS + parent providers | — |

---

## Finance

| Feature | Module | Source | Business value | Dependencies | Class | In code | Functional | Tested | Prod | Implementation refs | Gaps |
|---------|--------|--------|----------------|--------------|-------|---------|------------|--------|------|---------------------|------|
| Fee collection | Finance | SPEC-Finance, ROAD | Cash flow | SIS | **A** | Yes | Yes | Yes | No | FN screens, Patrol fee E2E | — |
| Fee structure CRUD | Finance | PLAN | Billing setup | — | **A** | Yes | Yes | Yes | No | Mutations | — |
| Refund approve/reject | Finance | PLAN | Governance | RBAC | **A** | Yes | Yes | Yes | No | Mutations | — |
| Scholarship create | Finance | PLAN | Aid programs | — | **A** | Yes | Yes | Partial | No | Mutations | — |
| Defaulters / student accounts | Finance | SPEC-Finance | Recovery | SIS | **B** | Yes | Read | Yes | No | Read repos | — |
| Reconciliation UI | Finance | ROAD v7.2c | Audit | — | **B** | Yes | Partial | Partial | No | FN reconciliation | — |
| **Invoice create UI** | Finance | PLAN **P0#6**, SPEC-FN | Billing | Repo methods exist | **B** | Yes | Partial | Yes | No | Fee assignment invoice panel | Patrol pending |
| **Cancel collection UI** | Finance | PLAN P0#6 | Corrections | Invoice | **B** | Yes | Yes | Yes | No | Collection detail cancel | Patrol pending |
| Receipt PDF export | Finance | AUDIT, PLAN P1 | Compliance | — | **A** | Yes | Yes | Yes | No | `finance_receipt_pdf_service.dart`, Patrol | — |
| Payment engine (Razorpay) | Finance | VISION #13–16, ROAD | Online pay | Parent app | **B** | Yes | Partial | Yes | No | Parent payment | Production keys |
| QR / offline payment | Finance | VISION #15–16 | Counter pay | — | **A** | Yes | Yes | Yes | No | QR + offline payment screens, Patrol | — |
| Finance Copilot | Finance | ROAD v13.3 | Insights | Intelligence | **D** | Yes | Mock | Contract | No | `finance_copilot_screen.dart` | Live AI |
| Ledgers / budgets (full) | Finance | SPEC-Finance | Accounting | — | **B** | Yes | Read | Partial | No | FN read surfaces | Write depth |

---

## Management / Owner Dashboard

| Feature | Module | Source | Business value | Dependencies | Class | In code | Functional | Tested | Prod | Implementation refs | Gaps |
|---------|--------|--------|----------------|--------------|-------|---------|------------|--------|------|---------------------|------|
| Management dashboard MG-01 | Management | SPEC-Management, AUDIT | Owner home | All KPI repos | **B** | Yes | ~52% functional | Yes | No | `management_dashboard_screen.dart` | See AUDIT |
| Executive approval approve/reject | Management | PLAN P0#1 | Governance | RBAC | **A** | Yes | Yes | Yes | No | Mutations, Patrol E2E | — |
| **KPI drill-downs** | Management | AUDIT, SPEC-MG | Actionable metrics | Module routes | **C** | Yes | Partial | Partial | No | Finance drill only | **Most KPIs display-only** |
| **Dashboard export** | Management | AUDIT | Reporting | PDF service | **A** | Yes | Yes | Yes | No | `management_dashboard_pdf_service.dart` | — |
| **Period filters → repo** | Management | AUDIT | Accurate periods | Repository query | **A** | Yes | Yes | Yes | No | `managementDashboardQueryProvider` | — |
| **AI insight card actions** | Management | AUDIT, VISION #5 | Executive guidance | Intelligence routes | **A** | Yes | Yes | Yes | No | `management_insight_navigation.dart` | — |
| **Executive reports / PDF** | Management | SPEC-MG, Intelligence | Board reporting | Export | **D** | Yes | Text only | Partial | No | `intelligence_screen.dart` | Export stub |
| Intelligence hub | Management | ROAD v9.3 | Risk overview | Intelligence repos | **B** | Yes | Read + partial compute | Yes | No | `/intelligence` | Compute = mock |
| Operations Hub | Management | ROAD v10.0 | School health | All modules | **A** | Yes | Yes | Yes | No | `operations_hub_screen.dart` | Widget persistence M11 |
| Management settings save | Management | PLAN P1, AUDIT | Config | — | **A** | Yes | Yes | Yes | No | `updateManagementSettings` mutation | — |
| School health score | Management | VISION #5 | At-a-glance status | Intelligence | **D** | Yes | Mock | Contract | No | Phase5/intelligence | Live data |
| Principal Command Center | Management | ROAD v10.5 | Daily ops | Principal spec | **B** | Yes | Partial | Patrol | No | Principal routes | Priority cards null onTap |

---

## Academic / Education / Exams

| Feature | Module | Source | Business value | Dependencies | Class | In code | Functional | Tested | Prod | Implementation refs | Gaps |
|---------|--------|--------|----------------|--------------|-------|---------|------------|--------|------|---------------------|------|
| Homework (ERP + mobile) | Academic | SPEC-Academic | Daily learning | Teacher app | **A** | Yes | Yes | Yes | No | AC + teacher features | — |
| Report card remark publish | Academic | PLAN Phase 1 | Grading workflow | Education | **A** | Yes | Yes | Patrol | No | `education_*` | — |
| Subject / lesson management | Academic | ROAD v12.0 | Curriculum | — | **B** | Yes | Partial | Partial | No | `school_completion/` | — |
| Syllabus automation | Academic | ROAD v12.7 | Planning | AI suite | **B** | Yes | Partial | Contract | No | School completion | — |
| AI Question Paper / Bank / HW | Academic | VISION #22–26, ROAD | Content gen | Copilot | **A** | Yes | Yes | Yes | No | Education suite screens | — |
| **ERP Exam Admin (native)** | Academic | PLAN, QA P0-6 | Exam lifecycle | SIS | **F** | Partial | Partial | Partial | No | Mobile exams + AC reads | **Scope undefined P3** |
| Online classes | Academic | SPEC-AC | Remote learning | — | **E** | No | No | No | No | — | Future |
| Attendance ERP admin | Academic | PLAN P1 | Reconciliation | Teacher attendance | **B** | Yes | Read | Partial | No | Cross-module | Bulk admin |

---

## Timetable

| Feature | Module | Source | Business value | Dependencies | Class | In code | Functional | Tested | Prod | Implementation refs | Gaps |
|---------|--------|--------|----------------|--------------|-------|---------|------------|--------|------|---------------------|------|
| Timetable hub (read) | Timetable | SPEC-Principal PR-03, ROAD v7.5 | Schedule visibility | Academic | **A** | Yes | Yes | Yes | No | `timetable_hub_screen.dart`, Patrol | — |
| **Drag-drop period editor** | Timetable | VISION #8, SPEC-PR | Manual scheduling | Timetable repo | **A** | Yes | Yes (mock) | Yes | No | `timetable_editor_tab.dart` | API prod |
| **Conflict detection** | Timetable | VISION #8 | Quality | Timetable repo | **A** | Yes | Yes (mock) | Contract | No | Conflicts tab + API | — |
| **Auto scheduling / generate** | Timetable | VISION #8, school_completion | Time savings | Constraints engine | **B** | Yes | Yes (mock) | Integration | No | Generate tab, edge fn | Server rules |
| **Schedule optimization** | Timetable | VISION #9 | Load balance | Workload engine | **A** | Yes | Apply action | Yes | No | `timetable_optimization_screen.dart`, Patrol | — |
| Publish workflow | Timetable | VISION #8 | Go-live schedule | — | **B** | Yes | Partial | Partial | No | Publish in hub | Notification fan-out |
| Parent/teacher timetable views | Timetable | SPEC mobile | Visibility | Timetable | **A** | Yes | Yes | Patrol | No | Mobile + ERP views | — |

---

## Teacher operations

| Feature | Module | Source | Business value | Dependencies | Class | In code | Functional | Tested | Prod | Implementation refs | Gaps |
|---------|--------|--------|----------------|--------------|-------|---------|------------|--------|------|---------------------|------|
| Mark attendance (mobile) | Teacher | SPEC-Teacher, QA | Daily ops | SIS | **A** | Yes | Yes | Patrol | No | Teacher mutations | — |
| Teacher Copilot | Teacher | VISION #6, ROAD | Productivity | AI | **D** | Yes | Mock | Partial | No | Copilot screens | — |
| **Teacher reassignment** | Teacher | SPEC-Principal, SRS | Staffing flexibility | Timetable, HR | **A** | Yes | Yes | Yes | No | `teacher_reassignment_screen.dart`, Patrol | — |
| **Substitute teacher assignment** | Teacher | SPEC-PR-10 (AR-043) | Coverage | Timetable | **A** | Yes | Yes | Yes | No | `substitute_manager_screen.dart`, Patrol | — |
| **Teacher workload balancing** | Teacher | VISION #9 | Fair load | Timetable | **D** | Yes | Metrics only | Contract | No | Phase5, optimization reads | No rebalance action |
| **Teacher schedule management (writes)** | Teacher | SPEC-Teacher | Self-service | Timetable | **B** | Yes | Read-only schedule | Patrol read | No | Teacher timetable | No swap requests |
| Class teacher dashboard | Teacher | SPEC-Teacher | Class ops | SIS | **B** | Yes | Partial | Partial | No | Teacher screens | — |
| Leave apply (teacher) | Teacher | SPEC-Teacher | HR integration | HR | **B** | Yes | Partial | Partial | No | Teacher leave | ERP approve chain |

---

## HR / Payroll

| Feature | Module | Source | Business value | Dependencies | Class | In code | Functional | Tested | Prod | Implementation refs | Gaps |
|---------|--------|--------|----------------|--------------|-------|---------|------------|--------|------|---------------------|------|
| Employee directory | HR | SPEC-HR | Staff registry | — | **A** | Yes | Yes | Yes | No | HR read | — |
| **Employee CRUD** | HR | PLAN P0#4 | Onboarding | RBAC | **A** | Yes | Yes | Yes | Patrol | `hr_mutations_provider.dart` | — |
| Leave request create | HR | SPEC-HR | Time off | — | **A** | Yes | Yes | Patrol | No | HR mutations | — |
| Leave approve/reject (manager) | HR | PLAN P1 | Governance | RBAC | **A** | Yes | Yes | Yes | No | `approveHrLeaveProvider`, Patrol | — |
| Payroll run process | HR | PLAN Phase 1 | Compensation | Finance | **A** | Yes | Yes | Patrol | No | HR payroll mutations | — |
| Payroll adjust / mark paid | HR | PLAN P1–P2 | Payroll completion | Finance | **B** | Yes | Partial | Partial | No | Read + export snackbar | Writes |
| Recruitment pipeline | HR | SPEC-HR | Hiring | — | **B** | Yes | Read | Partial | No | HR screens | Writes |
| Staff attendance (geo/face) | HR | SPEC-HR HR-04 | Compliance | — | **C** | Yes | Read/mock | Partial | No | HR attendance | Integration |
| Performance reviews | HR | SPEC-HR | Appraisal | — | **B** | Yes | Read | Partial | No | HR performance | Write workflow |
| Multi-role employee (v9.6) | HR | VISION #7, ROAD | Flexible staffing | RBAC | **D** | Yes | Mock | Contract | No | `employee/` Phase5 | — |

---

## Transport

| Feature | Module | Source | Business value | Dependencies | Class | In code | Functional | Tested | Prod | Implementation refs | Gaps |
|---------|--------|--------|----------------|--------------|-------|---------|------------|--------|------|---------------------|------|
| Route / vehicle / driver registry | Transport | SPEC-Transport | Fleet mgmt | — | **A** | Yes | Yes | Yes | No | TR read screens | — |
| Route create / activate | Transport | PLAN Phase 1 | Route lifecycle | — | **A** | Yes | Yes | Patrol | No | Transport mutations | — |
| **Student assign / transfer / remove** | Transport | PLAN **P0#5** | Enrollment on bus | SIS | **A** | Yes | Yes | Yes | Patrol | `transport_allocation_*` | — |
| GPS / live tracking | Transport | SPEC-TR-08 | Safety | Parent app | **C** | Yes | Placeholder | Partial | No | Tracking placeholder | Live GPS P3 |
| Attendance on route | Transport | SPEC-TR | Pickup proof | SIS | **B** | Yes | Read | Partial | No | TR attendance | — |
| Driver roster writes | Transport | PLAN P1 | Fleet ops | HR transport staff | **B** | Yes | Read | Partial | No | — | Write gap |

---

## Hostel · Library · Inventory · Alumni

*(Condensed — full traceability in module specs)*

| Feature | Module | Source | Class | P0/vision status | Key refs |
|---------|--------|--------|-------|------------------|----------|
| Hostel admit / assign / checkout | Hostel | PLAN P0#3 | **A** | Done | `hostel_mutations_provider.dart`, Patrol |
| Hostel leave / visitors / mess writes | Hostel | SPEC-Hostel | **B** | P1 | Read-heavy |
| Library issue / return | Library | PLAN P0#2 | **A** | Done | `library_mutations_provider.dart`, Patrol |
| Library fines / catalog writes | Library | PLAN P1 | **B** | Open | Mock reads |
| Inventory lifecycle event | Inventory | PLAN Phase 1 | **A** | Done | Mutations + Patrol |
| **PO approve / receive** | Inventory | PLAN P1 | **A** | Done | Approve/receive handoff + Patrol |
| Asset approve | Inventory | PLAN P0#7 | **E** | **P0 open** | — |
| Alumni registry | Alumni | SPEC-Alumni | **D** | P1 events | Read-only mock |
| Alumni events / donations writes | Alumni | PLAN P1–P2 | **E** | Open | — |

---

## Notifications & Communication

| Feature | Module | Source | Business value | Class | In code | Functional | Tested | Gaps |
|---------|--------|--------|----------------|-------|---------|------------|--------|------|
| Notification inbox (read) | Notifications | SPEC-NT | Awareness | **B** | Yes | Read | Partial | No broadcast |
| **Broadcast / template admin** | Notifications | PLAN P1 | School comms | **A** | Yes | Yes | Yes | No | `broadcast_admin_screen.dart`, Patrol | — |
| Communication Hub | Notifications | ROAD v7.1 | Unified comms | **D** | Yes | Stub providers | Partial | Live channels |
| AI Communication Assistant | Notifications | VISION #1, ROAD v9.0 | Draft messages | **D** | Yes | Mock | Partial | — |
| WhatsApp provider (MSG91) | Notifications | ROAD v12.0 | Delivery | **B** | Yes | Partial | Contract | Production config |
| **Parent continuity after reassignment** | Communication | Product vision | UX trust | **A** | Yes | Yes | Yes | M2 shipped |
| **Notification migration on reassignment** | Communication | Product vision | Data integrity | **A** | Yes | Yes | Yes | M2 shipped |
| **Message ownership migration** | Communication | Product vision | Thread continuity | **A** | Yes | Yes | Yes | M2 shipped |

---

## Intelligence / AI (cross-cutting)

| Feature | Module | Source | Class | Functional | Key refs | Patrol/tests |
|---------|--------|--------|-------|------------|----------|--------------|
| Student Risk Prediction | AI | VISION #3, ROAD v8.9 | **D** | Mock compute | `intelligence/student_success/` | Contract + provider |
| **At-risk student detection** | AI | VISION #3 | **D** | Mock | `student_success_screen.dart` | Yes |
| **Attendance predictions** | AI | Intelligence layer | **D** | Mock | `student_success_models.dart` | Partial |
| **Fee collection insights** | AI | Finance intelligence | **D** | Mock | `finance_copilot_screen.dart` | Patrol finance |
| **Performance insights** | AI | ROAD v13.6+ | **D** | Mock | `teacher_effectiveness/`, exam intelligence | Contract |
| **Resource optimization (school-wide)** | AI | Product vision | **E** | No | — | Inventory copilot only |
| Principal Copilot | AI | VISION #5 | **D** | Mock | Copilot + intelligence | Partial |
| **Context-aware ERP Copilot** | AI | INTEL-03 | **B** | Yes (stub) | `copilot_screen_context.dart`, Patrol | Done |
| **Floating copilot dock** | AI | INTEL-04 | **B** | Yes | `copilot_floating_dock.dart`, Patrol | Done |
| **Persona AI shells (8 roles)** | AI | INTEL-04 | **B** | Stub prompts | `copilot_persona_shell_screen.dart` | Live inference pending |
| **AI access mode preferences** | AI | INTEL-05 | **B** | Local prefs | `ai_assistant_settings_screen.dart` | Server sync pending |
| **At-risk student intelligence MVP** | AI | INTEL-05 | **B** | Deterministic tiers | `at_risk_student_intelligence.dart` | Live ML pending |
| Compute risk / refresh actions | AI | Intelligence UI | **B** | Partial | `intelligence_mutations_provider.dart` | Yes |
| Achievement Promotion Engine | AI | VISION #19 | **D** | Mock | `promotion/` | Partial |
| AI Education Suite (generative) | AI | VISION #22–27 | **A** | Yes (mock AI) | Education screens | Yes |

---

## Operations automation

| Feature | Module | Source | Class | In code | Functional | Gaps |
|---------|--------|--------|-------|---------|------------|------|
| **Workflow automation engine** | Operations | VISION FV-P4-06 | **A** | Yes | Yes | M3 · `workflow_engine.dart` |
| Approval automation (rules) | Operations | Product vision | **B** | Partial | Manual approvals only | Management P0#1 done; no auto-routing |
| **Smart routing (approvals/tasks)** | Operations | Product vision | **A** | Yes | Yes | M3 · `autoRouteToRole` |
| Operations Hub alerts | Operations | ROAD v10.0 | **A** | Yes | Dismiss + complete actions | Patrol E2E |
| Audit workflow events | Platform | AUDIT spec | **A** | Yes | Client queue | Server ingestion partial |

---

## Mobile personas (Parent · Teacher · Student)

| Feature | Source | Class | Patrol | Notes |
|---------|--------|-------|--------|-------|
| Parent dashboard, fees, pay | SPEC-Parent, ROAD | **A** | Yes | Fee collection E2E |
| Parent bus tracking | SPEC-Parent P1 | **E** | No | Spec only |
| Teacher attendance submit | SPEC-Teacher, QA | **A** | Yes | Phase 1 smoke |
| Student homework / timetable | SPEC-Student | **A** | Yes | Mobile workflows |
| Parent Guidance Assistant | VISION #4 | **D** | Partial | Mock AI |
| Parent Experience Bridge v9.8 | ROAD | **B** | Partial | Student 360 handoff |

---

## Platform · RBAC · Audit · Evolution (Phase 5)

| Feature | Source | Class | Status | Refs |
|---------|--------|-------|--------|------|
| Book Distribution System | VISION #11, ROAD v10.1 | **B** | Partial reads | `school_completion/book_distribution/` |
| School Memories | VISION #17, ROAD v10.2 | **B** | Partial | Evolution / memories routes |
| Achievement Promotion Engine | VISION #19, ROAD v10.3 | **C** | Mock workflow | `promotion/` |
| Akshara Growth Platform | VISION #18 | **A** | Campaign admin + mutations | `growth_platform_screen.dart`, Patrol |
| School Branding | VISION #20 | **E** | Not implemented | M13 · Design future |
| AI Parent Meeting Summary | VISION #28 | **E** | Not implemented | M8 · Intelligence backlog |
| Universal AI Assistant | VISION #29 | **E** | Not implemented | M8 · FV-PLAT-10 dependency |
| Universal Organization Builder | VISION #30 | **E** | Design only | M10 · `design/Universal-Organization-Builder-v2.md` |
| Dynamic Widget Platform | VISION #31 | **E** | Schema seed only | M11 · Ops Hub widgets |
| Multi-Industry Foundation | VISION #32 | **A** | Shipped | M13 · Industry hub |
| Salon / Hospital / Restaurant / Hostel packs | VISION #33–36 | **B** | MVP shipped | M13 · verticals/ |
| AI School Setup Wizard | VISION Section A | **E** | Design v10.6 | M10 · Onboarding partial |
| Inventory Replacement Workflow | VISION #12 | **E** | Not implemented | M7 · Inventory |
| Security & Pen Testing | VISION FV-P4-01 | **E** | Program not started | M12 |
| Observability Platform | VISION FV-P4-02 | **A** | Shipped | M12 · Platform Operations hub |
| Multi-School SaaS Operations | VISION FV-PLAT-02 | **A** | Shipped | M9 · Control Center |
| Franchise Management | VISION FV-P4-03 | **B** | MVP shipped | M9 |
| Multi-Branch Management | VISION FV-P4-04 | **B** | MVP shipped | M9 |
| Director Portal | Director.md FV-PLAT-03 | **A** | DR-01–09 shipped | M9 |
| Organization / Trust Intelligence | FV-PLAT-04 | **A** | Full hub shipped | M9 |
| Resource Optimization Engine | FV-PLAT-05 | **A** | Shipped | M8 |
| Production Readiness Program | FV-PLAT-06 | **A** | App layer 96% | M12 · `PRODUCTION_READINESS_PROGRESS.md` |
| AI Content Generation (platform) | FV-PLAT-07 | **A** | MVP shipped | M8 |
| Tenant Isolation Verification | FV-PLAT-08 | **A** | 213 probes UI | M12 |
| Monitoring & Alerting | FV-PLAT-09 | **A** | Shipped | M12 · Alert center |
| Live AI Inference | FV-PLAT-10 | **A** | Shipped | M8 |
| White Label Platform Expansion | FV-PLAT-11 | **A** | Shipped | M13 · white_label module |
| Universal Employee System | FV-PLAT-01 | **E** | Design only | M10 · `design/Universal-Employee-System.md` |

---

## Platform · RBAC · Audit

| Feature | Source | Class | Status | Refs |
|---------|--------|-------|--------|------|
| JWT / OTP auth | ROAD v1.6+ | **A** | Done | `lib/core/auth/` |
| RBAC route guards | ROAD v2.0+ | **A** | Done | `route_guards.dart`, inventory test |
| Mutation permission registry | PLAN **P0#8** | **B** | Partial registry | `mutation_permission_registry.dart` |
| Mobile mutation audit | PLAN P0#8 | **E** | Not complete | — |
| Audit client queue | ROAD v2.7 | **A** | Done | `audit/` |
| Server RLS / RBAC | DEBT FV-PLAT-13 | **B** | Partial — TD-P0-01 | M12 · Technical debt |
| API write parity (all modules) | PLAN P2 | **B** | Stubs | `ApiNotConnectedException` pattern |

---

## Deprecated / scope undefined

| Feature | Reason | Replacement |
|---------|--------|-------------|
| Unified ERP Exam Admin (full) | PLAN marks ~35%; QA blocks P0-6 | Product decision required — P3 |
| Legacy `ProjectStatus.md` metrics | Superseded by Roadmap v2.0 | Use `Roadmap.md` |
| Exam-only mobile without ERP admin | Partial coverage | Deferred with exam admin scope |

---

## Document maintenance

| Event | Action |
|-------|--------|
| P0 item closed | Update row classification → A; add refs |
| New spec in `docs/*.md` | Add rows with SPEC source |
| Vision doc update | Sync `FUTURE_VISION_MASTER_INDEX.md` + preservation audit |
| Release tag | Agent F updates registry + backlog + master index |

**Owners:** Agent F (docs) · Agent B/E validate code/test columns · Agent G gates releases

**Related:** `docs/FUTURE_VISION_MASTER_INDEX.md` · `docs/FUTURE_VISION_PRESERVATION_AUDIT.md` · `docs/AKSHARA_VISION_GAP_ANALYSIS.md` · `docs/AKSHARA_IMPLEMENTATION_BACKLOG.md` · `docs/ERP_FINAL_COMPLETION_PLAN.md`
