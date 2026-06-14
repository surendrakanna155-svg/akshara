# Akshara Master Feature Registry

**Version:** 1.1  
**Date:** June 2026  
**Purpose:** Single source of truth — every planned feature traced to source documents and current implementation status  
**Baseline:** ERP completion ~81% · QA readiness ~95% · P0 closed 9/10

---

## How to use this document

| Question | Section |
|----------|---------|
| Was feature X in the original vision? | Find row → **Original source** |
| Is it built? | **Classification** + **Validation** columns |
| What files/tests cover it? | **Implementation refs** |
| What's next? | `docs/AKSHARA_IMPLEMENTATION_BACKLOG.md` |

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
| DEBT | `docs/TechnicalDebtRegister.md` | Open technical debt |

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
| Settings persistence | Admissions | PLAN P0#9 | Config consistency | Management settings | **E** | No | No | No | No | MG-08 stub | **P0 open** |
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
| Student profile edit | SIS | PLAN P1 | Data quality | RBAC | **B** | Yes | Partial | Partial | No | Read profile | Write UI |
| Document vault upload | SIS | SPEC-SIS SIS-07 | Compliance | Storage | **C** | Yes | No | No | No | UI placeholder | Upload API |
| **Student promotion (year rollover)** | SIS | SPEC-SIS, VISION #21 | Academic continuity | Timetable, Finance | **B** | Yes | Partial | Partial | No | Status toggle only | **No promotion engine** |
| **Student reshuffle** | SIS | SPEC-SIS, SRS | Section balance | Academic | **E** | No | No | No | No | — | **Vision gap** |
| **Performance-based section assignment** | SIS | SRS / Principal | Merit grouping | Exams | **E** | No | No | No | No | — | **Vision gap** |
| **Quarterly reshuffle** | SIS | Product vision | Flexibility | SIS | **E** | No | No | No | No | — | **Vision gap** |
| **Section balancing** | SIS | Product vision | Class size equity | SIS | **E** | No | No | No | No | — | **Vision gap** |
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
| Receipt PDF export | Finance | AUDIT, PLAN P1 | Compliance | — | **D** | Yes | Snackbar only | Partial | No | Export stubs | Real PDF |
| Payment engine (Razorpay) | Finance | VISION #13–16, ROAD | Online pay | Parent app | **B** | Yes | Partial | Yes | No | Parent payment | Production keys |
| QR / offline payment | Finance | VISION #15–16 | Counter pay | — | **E** | No | No | No | No | — | Future |
| Finance Copilot | Finance | ROAD v13.3 | Insights | Intelligence | **D** | Yes | Mock | Contract | No | `finance_copilot_screen.dart` | Live AI |
| Ledgers / budgets (full) | Finance | SPEC-Finance | Accounting | — | **B** | Yes | Read | Partial | No | FN read surfaces | Write depth |

---

## Management / Owner Dashboard

| Feature | Module | Source | Business value | Dependencies | Class | In code | Functional | Tested | Prod | Implementation refs | Gaps |
|---------|--------|--------|----------------|--------------|-------|---------|------------|--------|------|---------------------|------|
| Management dashboard MG-01 | Management | SPEC-Management, AUDIT | Owner home | All KPI repos | **B** | Yes | ~52% functional | Yes | No | `management_dashboard_screen.dart` | See AUDIT |
| Executive approval approve/reject | Management | PLAN P0#1 | Governance | RBAC | **A** | Yes | Yes | Yes | No | Mutations, Patrol E2E | — |
| **KPI drill-downs** | Management | AUDIT, SPEC-MG | Actionable metrics | Module routes | **C** | Yes | Partial | Partial | No | Finance drill only | **Most KPIs display-only** |
| **Dashboard export** | Management | AUDIT | Reporting | PDF service | **D** | Yes | Stub | No | No | `onPressed: () {}` | **Vision gap** |
| **Period filters → repo** | Management | AUDIT | Accurate periods | Repository query | **D** | Yes | UI only | No | No | Local filter state | Not wired |
| **AI insight card actions** | Management | AUDIT, VISION #5 | Executive guidance | Intelligence routes | **D** | Yes | Stub (~12 cards) | No | No | Insight cards | Route targets |
| **Executive reports / PDF** | Management | SPEC-MG, Intelligence | Board reporting | Export | **D** | Yes | Text only | Partial | No | `intelligence_screen.dart` | Export stub |
| Intelligence hub | Management | ROAD v9.3 | Risk overview | Intelligence repos | **B** | Yes | Read + partial compute | Yes | No | `/intelligence` | Compute = mock |
| Operations Hub | Management | ROAD v10.0 | School health | All modules | **B** | Yes | Read-only | Partial | No | `operations_hub_screen.dart` | Actions display-only |
| Management settings save | Management | PLAN P1, AUDIT | Config | — | **D** | Yes | Stub | No | No | MG-08 | Save no-op |
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
| **Schedule optimization** | Timetable | VISION #9 | Load balance | Workload engine | **D** | Yes | Read-only scores | Contract | No | `timetable_optimization_screen.dart` | No apply action |
| Publish workflow | Timetable | VISION #8 | Go-live schedule | — | **B** | Yes | Partial | Partial | No | Publish in hub | Notification fan-out |
| Parent/teacher timetable views | Timetable | SPEC mobile | Visibility | Timetable | **A** | Yes | Yes | Patrol | No | Mobile + ERP views | — |

---

## Teacher operations

| Feature | Module | Source | Business value | Dependencies | Class | In code | Functional | Tested | Prod | Implementation refs | Gaps |
|---------|--------|--------|----------------|--------------|-------|---------|------------|--------|------|---------------------|------|
| Mark attendance (mobile) | Teacher | SPEC-Teacher, QA | Daily ops | SIS | **A** | Yes | Yes | Patrol | No | Teacher mutations | — |
| Teacher Copilot | Teacher | VISION #6, ROAD | Productivity | AI | **D** | Yes | Mock | Partial | No | Copilot screens | — |
| **Teacher reassignment** | Teacher | SPEC-Principal, SRS | Staffing flexibility | Timetable, HR | **E** | No | No | No | No | — | **Vision gap** |
| **Substitute teacher assignment** | Teacher | SPEC-PR-10 (AR-043) | Coverage | Timetable | **D** | Yes | Suggestions only | Contract | No | `TimetableSubstituteSuggestion` | No wizard |
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
| Leave approve/reject (manager) | HR | PLAN P1 | Governance | RBAC | **E** | No | No | No | No | — | **Gap** |
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
| **PO approve / receive** | Inventory | PLAN **P0#7** | **B** | **P0 open** | Partial handoff |
| Asset approve | Inventory | PLAN P0#7 | **E** | **P0 open** | — |
| Alumni registry | Alumni | SPEC-Alumni | **D** | P1 events | Read-only mock |
| Alumni events / donations writes | Alumni | PLAN P1–P2 | **E** | Open | — |

---

## Notifications & Communication

| Feature | Module | Source | Business value | Class | In code | Functional | Tested | Gaps |
|---------|--------|--------|----------------|-------|---------|------------|--------|------|
| Notification inbox (read) | Notifications | SPEC-NT | Awareness | **B** | Yes | Read | Partial | No broadcast |
| **Broadcast / template admin** | Notifications | PLAN **P0#10** | School comms | **E** | Partial | No | No | **P0 open** |
| Communication Hub | Notifications | ROAD v7.1 | Unified comms | **D** | Yes | Stub providers | Partial | Live channels |
| AI Communication Assistant | Notifications | VISION #1, ROAD v9.0 | Draft messages | **D** | Yes | Mock | Partial | — |
| WhatsApp provider (MSG91) | Notifications | ROAD v12.0 | Delivery | **B** | Yes | Partial | Contract | Production config |
| **Parent continuity after reassignment** | Communication | Product vision | UX trust | **E** | No | No | No | **Vision gap** |
| **Notification migration on reassignment** | Communication | Product vision | Data integrity | **E** | No | No | No | **Vision gap** |
| **Message ownership migration** | Communication | Product vision | Thread continuity | **E** | No | No | No | **Vision gap** |

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
| Compute risk / refresh actions | AI | Intelligence UI | **B** | Partial | `intelligence_mutations_provider.dart` | Yes |
| Achievement Promotion Engine | AI | VISION #19 | **D** | Mock | `promotion/` | Partial |
| AI Education Suite (generative) | AI | VISION #22–27 | **A** | Yes (mock AI) | Education screens | Yes |

---

## Operations automation

| Feature | Module | Source | Class | In code | Functional | Gaps |
|---------|--------|--------|-------|---------|------------|------|
| **Workflow automation engine** | Operations | VISION design/Workflow | **E** | No | No | No rules engine |
| Approval automation (rules) | Operations | Product vision | **B** | Partial | Manual approvals only | Management P0#1 done; no auto-routing |
| **Smart routing (approvals/tasks)** | Operations | Product vision | **E** | No | No | — |
| Operations Hub alerts | Operations | ROAD v10.0 | **D** | Yes | Display-only | No actions |
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
| Akshara Growth Platform | VISION #18 | **B** | Partial | Growth / marketing reads |
| School Branding | VISION #20 | **E** | Not implemented | Design future |
| AI Parent Meeting Summary | VISION #28 | **E** | Not implemented | Intelligence backlog |
| Universal AI Assistant | VISION #29 | **E** | Not implemented | P3 |
| Universal Organization Builder | VISION #30 | **E** | Design only | `design/Universal-Organization-Builder-v2.md` |
| Dynamic Widget Platform | VISION #31 | **E** | Schema seed only | Ops Hub widgets |
| Multi-Industry Foundation | VISION #32 | **E** | Not implemented | P3 |
| Salon / Hospital / Restaurant / Hostel packs | VISION #33–36 | **E** | Not implemented | P3 |
| AI School Setup Wizard | VISION Section A | **E** | Design v10.6 | Onboarding partial |
| Inventory Replacement Workflow | VISION #12 | **E** | Not implemented | Inventory P2 |
| Security & Pen Testing | VISION P4 | **E** | Program not started | — |
| Observability & Monitoring | VISION P4 | **E** | Not implemented | — |
| Multi-School SaaS / Franchise / Multi-Branch | VISION P4 | **E** | Not implemented | Control Center partial |

---

## Platform · RBAC · Audit

| Feature | Source | Class | Status | Refs |
|---------|--------|-------|--------|------|
| JWT / OTP auth | ROAD v1.6+ | **A** | Done | `lib/core/auth/` |
| RBAC route guards | ROAD v2.0+ | **A** | Done | `route_guards.dart`, inventory test |
| Mutation permission registry | PLAN **P0#8** | **B** | Partial registry | `mutation_permission_registry.dart` |
| Mobile mutation audit | PLAN P0#8 | **E** | Not complete | — |
| Audit client queue | ROAD v2.7 | **A** | Done | `audit/` |
| Server RLS / RBAC | DEBT TD-P0-01 | **E** | Not production | Technical debt |
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
| Vision doc update | Sync `AKSHARA_VISION_GAP_ANALYSIS.md` |
| Release tag | Agent F updates registry + backlog |

**Owners:** Agent F (docs) · Agent B/E validate code/test columns · Agent G gates releases

**Related:** `docs/AKSHARA_VISION_GAP_ANALYSIS.md` · `docs/AKSHARA_IMPLEMENTATION_BACKLOG.md` · `docs/ERP_FINAL_COMPLETION_PLAN.md`
