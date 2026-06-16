# Akshara Real School Operations Audit

**Program:** Final Functional Verification Before Theme Modernization  
**Date:** 2026-06-16  
**Branch / HEAD:** `release/v1.0-preprod` · `114fc5b`  
**Mode:** Audit only — no code, UI, or implementation changes  
**Scope:** Real-world school operations — not roadmap, milestones, or completion percentages

**Classification key**

| Code | Meaning |
|------|---------|
| **A** | Fully adaptive / fully operational end-to-end |
| **B** | Partial — works with mock gaps, read-only segments, or incomplete adaptation |
| **C** | Static — configured but does not change behavior; or read-only shell |
| **D** | Missing / placeholder / dead |

---

## Executive summary

Akshara operates as a **strong administrative ERP** (admissions, fees, HR, transport, hostel, library, inventory, year rollover, multi-school portfolio) but has a **broken academic examination chain** and **incomplete Smart School adaptation** beyond admin navigation. Patrol certifies navigation and mock workflows; it does not certify that a school can run a full exam cycle or that every dashboard action works.

| Persona | Daily operations viable? | Academic cycle complete? |
|---------|:------------------------:|:------------------------:|
| School admin / finance / HR | **Yes** (mock/staging) | N/A |
| Teacher | **Partial** | **No** — no exam create; marks entry orphaned |
| Parent | **Partial** | **Partial** — reads exist; rankings/PTM/report-card gaps |
| Principal | **Mostly** | **Partial** — intelligence reads; exam publish missing |
| Owner / Director / Trust | **Yes** (portfolio UI) | N/A |

**Largest operational gap:** No ERP exam administration (create → configure → marks → publish → report card). Teacher mobile marks entry exists but has no upstream exam schedule source of truth.

**Before M15:** Theme layer will make dead export buttons and “coming soon” surfaces more visible. Functional work on the exam chain and Smart School adaptation is recommended in parallel with or immediately before M15.

---

## 1. Smart School Configuration Audit

**Implementation:** `lib/core/school_config/` · wizard at `/school-config/discovery`  
**Board note:** There is no separate “Board” field — **curriculum enum serves as board** (`SchoolCurriculum`: CBSE, ICSE, State Board, IB, Cambridge, Custom).

### Per-capability adaptation matrix

| Capability | Navigation | Dashboard | Reports | Copilot | Widgets | Visibility | Overall |
|------------|:----------:|:---------:|:-------:|:-------:|:-------:|:----------:|:-------:|
| **School Type** | C | C | C | B | C | C | **C** |
| **Curriculum / Board** | C | C | C | B | C | C | **C** |
| **Hostel** | A | B | C | B | C | A | **B** |
| **Transport** | A | B | C | B | C | A | **B** |
| **Library** | A | B | C | B | C | A | **B** |
| **Inventory** | A | B | C | B | C | A | **B** |
| **HR** | A | B | C | B | C | A | **B** |
| **Alumni** | A | C | C | B | C | A | **B** |
| **Multi-school** (`multiBranch`) | A | C | C | B | C | A | **B** |
| **Trust** (`trustOrganization`) | A | C | C | B | C | A | **B** |
| **Branches** (`branchCount`) | C | C | C | B | C | C | **C** |

**Legend for columns**

- **Navigation (A):** `SchoolCapabilityRegistry.isAdminModuleEnabled` filters `adminNavDestinationsProvider` — verified in `school_configuration_test.dart`
- **Dashboard (B):** `adaptManagementDashboard` filters KPIs + approval queue; `adaptParentDashboard` strips transport notices — **teacher/student dashboards not adapted**
- **Reports (C):** No capability filtering on finance/admissions/module report screens
- **Copilot (B):** `copilotMetadata()` injects school type, curriculum, capability booleans into every context — **`isCopilotTopicEnabled` is defined but has zero call sites** (topics not blocked when module disabled)
- **Widgets (C):** Dynamic Widget Platform (`lib/features/dynamic_widget/`) has **no** `SchoolCapability` integration
- **Visibility (A):** Admin rail correctly hides disabled modules

### School type & curriculum behavior gap

School type and curriculum are **stored and sent to copilot metadata** but do **not** drive module visibility, syllabus templates, or report formats. Only capability booleans change navigation and partial dashboard filtering.

### Smart School configuration gaps

1. Teacher/student dashboard adaptation not wired (`school_dashboard_adapter.dart` — management + parent only)
2. Reports, widgets, and module report exports ignore capabilities
3. Copilot topic gating registry exists but is **unwired**
4. Branch count is metadata only — does not change dashboard density or nav
5. No Patrol E2E for discovery wizard or post-config navigation verification
6. Config persists locally (`SharedPreferences`) — no server sync for multi-device schools

---

## 2. Academic Lifecycle Audit

```
Curriculum → Syllabus → Subject Planning → Lesson Plans → Homework → Assessments
    → Exams → Marks Entry → Result Processing → Report Card → Parent/Student View → Copilot
```

| Step | UI | Workflow | Persistence | Parent visibility | Student visibility | Copilot | Class |
|------|:--:|:--------:|:-----------:|:-----------------:|:------------------:|:-------:|:-----:|
| Curriculum | B | C | B | — | — | B | **C** |
| Syllabus | A | A | A | — | — | C | **B** |
| Subject planning | A | A | A | — | — | C | **B** |
| Lesson plans | D | D | B | — | — | C | **D** |
| Homework | A | B | A | A | A | B | **B** |
| Assessments | B | C | B | — | — | B | **C** |
| Exams (admin) | D | D | D | — | — | B | **D** |
| Marks entry | B | B | B | — | — | C | **B** |
| Result processing | D | D | D | B | B | C | **D** |
| Report card | B | B | B | B | C | B | **B** |
| Copilot insights | B | B | B | B | B | B | **B** |

### Evidence paths

| Step | Primary files |
|------|---------------|
| Curriculum | `school_configuration_models.dart` (onboarding only) |
| Syllabus | `school_completion/syllabus_automation_screen.dart`, `school_completion_repository` |
| Subject planning | `school_completion/subjects_screen.dart`, `subject_assignment_screen.dart` |
| Lesson plans | **Absent** — `lesson_logs_screen.dart` records outcomes; `teacher_assistant_screen.dart` has AI suggestions only |
| Homework | Mobile: `teacher/homework/`, `student/homework/`, `parent/homework/`; ERP AI: `education/education_screen.dart` |
| Assessments | `education_screen.dart` (AI question papers); no formal assessment entity |
| Exams | Mobile read lists only; **no** `createExam` / `scheduleExam` in `lib/` |
| Marks entry | `teacher/exams/teacher_exams_screen.dart` → `updateExamMark` mutation |
| Results | Parent/student `exams/` read repos; **no** `publishResult` |
| Report card | `education_screen.dart` (remarks + PDF); `parent/academics/parent_academic_report_screen.dart` |
| Copilot | Route-level context; rich scope on management dashboard only |

### Missing links (operational)

1. **Curriculum → syllabus** — no automated chain from school config
2. **Syllabus → lesson plans** — lesson logs are not plan authoring
3. **Education homework generation → teacher mobile assignments** — parallel paths, not linked
4. **Question papers → exam schedule** — AI content not tied to exam calendar
5. **Exam create → teacher marks entry** — marks UI fed by mock fixtures, no admin schedule
6. **Marks entry → result publish → parent notification** — publish workflow absent
7. **Exam results → unified report card** — remarks and marks not assembled into one document
8. **Parent `report_card` nav** → routes to `parentExams`, not `parentAcademicReport` (`parent_navigation.dart:47-48`)

---

## 3. Examination & Results Audit

### Teacher capabilities

| Action | Class | Evidence |
|--------|:-----:|----------|
| Create exam | **D** | No create UI in ERP or teacher app |
| Configure exam | **D** | No schedule/seating/invigilation |
| Enter marks | **B** | `teacher_exams_screen.dart` per-student `TextField` + `updateExamMark` |
| Bulk upload marks | **D** | No CSV/spreadsheet import for marks |
| Publish results | **D** | No publish mutation or principal approval gate |

### Principal capabilities

| Action | Class | Evidence |
|--------|:-----:|----------|
| Review results | **B** | `exam_intelligence_screen.dart` — analytics read |
| Compare classes | **B** | `management_performance_screen.dart` — class rank table |
| Identify weak students | **B** | `student_success_screen.dart`, intelligence hub recommendations |

### Parent capabilities

| Action | Class | Evidence |
|--------|:-----:|----------|
| View marks | **B** | `parent_exams_screen.dart` — results tab |
| View report cards | **B** | `parent_academic_report_screen.dart` (summary text); `report_card` shortcut → exams only |
| View rankings | **D** | No rank field in `parent/exams/` models |
| View subject performance | **B** | Results list per subject in mock data |

### Student capabilities

| Action | Class | Evidence |
|--------|:-----:|----------|
| View marks | **B** | `student_exams_screen.dart` |
| View report cards | **C** | Exams screen only; no dedicated report-card PDF |
| View performance trends | **B** | Trend icon in UI; mock trend data |

### Exam types (operational vs AI-only)

`EduExamType` in `education_models.dart` defines: **unit test, weekly, monthly, quarterly, half-yearly, annual** — used for **AI question paper generation** in Education Suite, **not** for operational exam scheduling or calendar.

| Exam type | Scheduled in ERP | Marks workflow | Parent/student view |
|-----------|:----------------:|:--------------:|:-------------------:|
| Unit test | D | B (orphaned marks) | B (mock read) |
| Weekly test | D | B | B |
| Monthly test | D | B | B |
| Quarterly | D | B | B |
| Half-yearly | D | B | B |
| Annual | D | B | B |

**Product decision:** P3-02 ERP Exam Admin scope is **blocked** — no owner chosen for exam administration module.

---

## 4. Parent Journey Audit

```
Admissions → Enrollment → Attendance → Homework → Fees → Transport → Exams
    → Results → Report Cards → Notices → PTM → Copilot
```

| Step | Status | Evidence | Gap |
|------|:------:|----------|-----|
| Admissions | **A** | Parent linked via SIS; ERP admissions Patrol certified | Parent does not apply through parent app |
| Enrollment | **A** | Post-conversion parent mapping | — |
| Attendance | **A** | `parent/attendance/` | — |
| Homework | **A** | `parent/homework/` — pending/completed | — |
| Fees | **A** | `parent/fees/`, `parent/payment/`, QR/offline Patrol | Live gateway env-dependent |
| Transport | **B** | Transport notices + fee line items; **no** dedicated bus tracking screen | No live GPS |
| Exams | **B** | `parent/exams/` — upcoming + results | Mock-fed; no publish event |
| Results | **B** | Same screen, results tab | No rankings |
| Report cards | **B** | `parent/academic-report` exists; dashboard shortcut misroutes | `report_card` → exams |
| Notices | **A** | `parent/notices/` with transport filter | Capability-adapted notices |
| PTM | **D** | Dashboard notice text only (`parent_dashboard_provider.dart:115`); **no parent-app PTM screen** | ERP `parent_meetings_screen.dart` is staff-facing at `/parent-meetings` |
| Copilot | **B** | Persona shell + dock; stub replies | Not native guidance depth |

---

## 5. Teacher Journey Audit

```
Class Management → Attendance → Homework → Lesson Planning → Assessments
    → Exams → Marks → Student Analysis → Parent Communication → Copilot
```

| Step | Status | Evidence | Gap |
|------|:------:|----------|-----|
| Class management | **B** | Dashboard shows schedule; hardcoded class context in places | No multi-class switcher depth |
| Attendance | **A** | `teacher/attendance/` + Patrol `teacher_attendance_e2e` | — |
| Homework | **B** | Review/grade submissions | **No create/assign on teacher mobile** |
| Lesson planning | **D** | `lesson_logs_screen.dart` (ERP school completion) not in teacher app | No teacher lesson-plan UI |
| Assessments | **C** | Education Suite AI (ERP staff) | Teacher cannot create assessments |
| Exams | **B** | `teacher/exams/` — upcoming list + marks entry | No exam create |
| Marks | **B** | `updateExamMark` mutation + contract test | Orphaned from exam admin |
| Student analysis | **C** | `teacher_assistant_screen.dart` insights (evolution) | Not integrated in teacher shell |
| Parent communication | **B** | Messages route exists | No deep thread from marks/PTM |
| Copilot | **B** | App-bar AI + persona shell | Stub replies; results tab insight `onAction: () {}` |

---

## 6. Principal Journey Audit

| Capability | Status | Evidence | Gap |
|------------|:------:|----------|-----|
| School overview | **A** | `management_dashboard_screen.dart` — health, KPIs, priorities | Priority cards display-only (no tap) |
| Attendance overview | **B** | MG analytics + quick action → analytics | KPIs mock |
| Academic overview | **B** | MG academics, school completion hub, exam intelligence | Exam cycle incomplete |
| Finance overview | **B** | MG finance, fee defaulter alert | Executive export snackbar-only on FN exec dashboard |
| Teacher overview | **B** | HR dashboard, teacher effectiveness intelligence | HR export dead button |
| Intelligence | **A** | `intelligence_hub_screen.dart` — risk, health, trends | Read-only tabs |
| Interventions | **B** | Unified recommendations + `teacherIntervention` routes | No one-click intervention write |
| Reports | **B** | Management export **works** (PDF); module exports mixed | Many module exports dead |
| Copilot | **B** | `CopilotContextScope` on MG-01 with KPIs | Sub-screens dock-only |
| Settings | **A** | `management_settings_screen.dart` — `_saveDraft` persists | Stale audit claimed stub — **now functional** |

---

## 7. Owner / Trust / Director Journey Audit

| Step | Status | Evidence | Gap |
|------|:------:|----------|-----|
| Owner school overview | **A** | Management dashboard (principal persona) | Mock data |
| Trust layer | **A** | Trust intelligence hub + capability-gated nav | Production RLS deferred |
| Schools portfolio | **B** | Director dashboard school list | Cards **not tappable** (`director_dashboard_screen.dart:64-93`) |
| Principals | **B** | RBAC principal role → management; multi-school onboarding | No principal-assignment UI depth |
| Intelligence | **A** | Platform intelligence + trust intelligence Patrol | — |
| Financials | **A** | Director reports export + AI summary | — |
| Portfolio monitoring | **A** | Franchise portfolio, branch ops, multi-school operations | — |
| Growth | **A** | Growth campaigns + platform intelligence growth tab | — |
| Risk | **A** | Risk tab + alert center | — |

**Visibility:** Trust/director/control-center nav requires `trustOrganization || multiBranch` capability flag — works in Smart School wizard.

---

## 8. Copilot Integration Audit

**Architecture:** `buildCopilotScreenContext()` merges route, role, and `schoolConfig.copilotMetadata()`. Rich `CopilotContextScope` (KPIs/records) only on: management dashboard, platform intelligence, student success, director shells (label only).

| Module | Context injection | Screen awareness | Role awareness | School awareness | Capability awareness | Class |
|--------|:-----------------:|:----------------:|:--------------:|:----------------:|:--------------------:|:-----:|
| Admissions | B | B | A | B | C | **B** |
| SIS | B | B | A | B | C | **B** |
| Attendance | B | B | A | B | C | **B** |
| Academics / Education | B | B | A | B | C | **B** |
| Exams | B | B | A | B | C | **B** |
| Results | C | C | A | B | C | **C** |
| Finance | C | B | A | B | C | **C** |
| HR | B | B | A | B | B (nav) | **B** |
| Inventory | C | B | A | B | B (nav) | **C** |
| Library | B | B | A | B | B (nav) | **B** |
| Transport | B | B | A | B | B (nav) | **B** |
| Hostel | B | B | A | B | B (nav) | **B** |
| Alumni | B | B | A | B | B (nav) | **B** |
| Notifications | B | B | A | B | C | **B** |
| Multi-school | B | B | A | B | B | **B** |

**Missing integrations**

1. `isCopilotTopicEnabled` never called — copilot answers about disabled modules
2. Finance/Inventory `*CopilotScreen` panels are mock-only (**C**), not unified chat
3. No `CopilotContextScope` on admissions, finance, SIS, HR screens
4. Quick actions in copilot use `buildContextAwareStubReply` — dialog stub, not inference
5. Academic/timetable features have no copilot references in feature code

---

## 9. Dashboard Reality Audit

### Placeholder / mock / dead surfaces

| Dashboard | Issue | Location |
|-----------|-------|----------|
| **Owner / Management** | Priority cards look actionable but have no `onTap` | `management_principal_overview_panel.dart:128-187` |
| **Owner / Management** | Admissions/fee snapshot cards display-only | `management_dashboard_screen.dart:354-451` |
| **Owner / Management** | FY/Q period filter — UI state only, not repo query | `managementDashboardFilterProvider` |
| **Director** | School portfolio cards not navigable | `director_dashboard_screen.dart:64-93` |
| **Principal** | MG-02–06 AI insight cards were stubbed historically; insight **routes** now wired — verify per screen | `management/intelligence/` sub-routes |
| **Intelligence Hub** | All tabs read-only | `intelligence_hub_screen.dart` |
| **Platform Intelligence** | Mock portfolio data | `platform_intelligence_screen.dart` |
| **Trust Intelligence** | Deterministic mock recommendations (RC-stable) | `trust_intelligence_hub_screen.dart` |
| **Parent Home** | PTM notice — no action | `parent_dashboard_provider.dart:115` |
| **Parent Home** | Quick actions wired | `parent_navigation.dart` |
| **Teacher Home** | Profile nav → dashboard (no profile screen) | `teacher_navigation.dart:42-43` |
| **Student Home** | Settings row “coming soon” with no-op tap | `student_profile_screen.dart:144-162`, `app_router.dart` student profile |
| **ERP Admin Hub** | Placeholder screen | `/admin` → `AdminModulePlaceholderScreen` |
| **Module dashboards** | Dead Export buttons | HR, transport, hostel, alumni, control center, library (see §10) |
| **Finance executive** | Export → snackbar queue only | `finance_executive_dashboard_screen.dart:42` |
| **Inventory dashboard** | Export → snackbar queue only | `inventory_dashboard_screen.dart:42` |
| **Operations Hub** | Alert actions display-only | `operations_hub_screen.dart` |

### Empty / misleading labels

- `admin_content_scaffold.dart:86-88` — ERP web profile: “Profile menu coming soon.”
- `student_profile_screen.dart` — “App settings, coming soon”
- Copilot quick actions — stub dialog replies (`copilot_ai_quick_actions.dart`)

---

## 10. Dead Route / Dead Action Audit

### Routes

| Route | Status | Notes |
|-------|--------|-------|
| `/admin` | **Live placeholder** | `AdminModulePlaceholderScreen` — not admin hub |
| `/management` | **OK** | Redirects to dashboard |
| `managementRouteBuilder` in `admin_navigation.dart` | **Dead code** | Never registered in `app_router.dart` |
| `/parent-meetings` | **Staff ERP only** | Not exposed in parent mobile shell |
| `/school-config/discovery` | **OK** | Reachable from Organization Builder; no Patrol |

### Dead buttons (`onPressed: () {}`) — confirmed in `lib/features/`

| File | Line | Control |
|------|-----:|---------|
| `hr/dashboard/hr_dashboard_screen.dart` | 42 | Export |
| `transport/dashboard/transport_dashboard_screen.dart` | 41 | Export |
| `hostel/dashboard/hostel_dashboard_screen.dart` | 41 | Export |
| `alumni/dashboard/alumni_dashboard_screen.dart` | 41 | Export |
| `control_center/dashboard/control_center_dashboard_screen.dart` | 44 | Export |
| `control_center/analytics/control_center_analytics_screen.dart` | 30 | Export |
| `library/dashboard/library_dashboard_screen.dart` | 43 | Scan issue |
| `sis/registry/sis_registry_screen.dart` | 60 | Export |
| `finance/reports/finance_reports_screen.dart` | 119, 124 | Excel, Email export |
| `library/reports/library_reports_screen.dart` | 151 | Download |
| `alumni/reports/alumni_reports_screen.dart` | 151 | Download |
| `hr/settings/hr_settings_screen.dart` | 130 | Edit setting |
| `transport/settings/transport_settings_screen.dart` | 135 | Edit setting |
| `control_center/settings/control_center_settings_screen.dart` | 134 | Edit setting |
| `alumni/settings/alumni_settings_screen.dart` | 132 | Edit setting |
| `sis/academic_assignment/sis_academic_assignment_screen.dart` | 379 | Bulk template |
| `intelligence/intelligence_screen.dart` | 568 | Print progress report |
| `evolution/parent_insights_screen.dart` | 121 | Print |
| Multiple alumni/library/hostel/control_center list screens | various | Header action buttons |

### Fake exports (snackbar only)

- `inventory_dashboard_screen.dart`, `finance_executive_dashboard_screen.dart`, `admissions_reports_screen.dart` — `showAksharaExportQueuedSnackBar`
- `akshara_analytics_panel.dart:130-138` — “Export queued” helper

### Disabled

- `admissions_settings_sections.dart:94` — lead-score tune tile `onTap: null`

**Count:** ~31 explicit no-op handlers in feature layer (grep `onPressed: () {}`).

---

## 11. Dashboard Adaptation Audit

| Dashboard | Adapts to | Class | Evidence |
|-----------|-----------|:-----:|----------|
| **Teacher** | Classes, subjects, responsibilities | **C** | `teacher_dashboard_provider.dart` — mock schedule; **no** `schoolCapabilitiesProvider` or class-assignment filter |
| **Student** | Grade, curriculum, school config | **C** | `student_dashboard_provider.dart` — static mock; no school config wiring |
| **Parent** | Child status, school capabilities | **B** | `adaptParentDashboard` filters transport notices; child switcher works; fees/homework not capability-filtered |
| **Management** | School capabilities | **B** | KPI + approval queue filtered |
| **Director** | Trust/multi-branch nav | **B** | Nav gated; dashboard content static |

---

## 12. Real School Scenario Audit

### Scenario 1: New CBSE school without hostel

| Check | Result |
|-------|--------|
| Disable hostel in discovery wizard | ✅ |
| Hostel hidden from admin nav | ✅ |
| Transport/library/etc. follow toggles | ✅ |
| Management KPIs hide hostel metrics | ✅ |
| Parent notices hide transport if disabled | ✅ |
| Copilot still answers hostel questions | ❌ **Failure** — topic gating unwired |
| Teacher dashboard unchanged | ❌ **Failure** — no adaptation |
| Reports still show all modules | ❌ **Failure** — static reports |

### Scenario 2: State board school with hostel and transport

| Check | Result |
|-------|--------|
| State board curriculum stored | ✅ |
| All modules visible | ✅ |
| Parent transport notices visible | ✅ |
| Fee transport line items | ✅ |
| Live bus tracking | ❌ Not implemented |
| Curriculum affects syllabus templates | ❌ Not automated |

### Scenario 3: Trust with 5 schools and 5 principals

| Check | Result |
|-------|--------|
| Enable trust + multi-branch in wizard | ✅ |
| Director + Control Center + Trust Intel in nav | ✅ |
| Director portal DR-01–09 | ✅ Patrol certified |
| School portfolio cards drill to school | ❌ Cards not tappable |
| Production multi-tenant isolation | ❌ RLS backend deferred |
| Per-school principal RBAC in one login | B — QA personas; production trust switching env-dependent |

### Scenario 4: Single branch private school

| Check | Result |
|-------|--------|
| Default single-school ops model | ✅ |
| Director/trust nav hidden | ✅ |
| Full ERP module set (capabilities on) | ✅ |
| Exam cycle end-to-end | ❌ **Failure** — no exam admin |

---

## 13. Final Operational Gap List

### Critical operational gaps

*Affect whether a school can complete core academic-year academic operations.*

| ID | Gap | Impact |
|----|-----|--------|
| OP-C01 | **No ERP exam administration** (create, schedule, configure) | Teachers cannot run formal exam cycle |
| OP-C02 | **No result publish workflow** | Parents/students see mock reads only; no authoritative publish |
| OP-C03 | **Marks entry orphaned from exam schedule** | Teacher marks UI disconnected from admin source of truth |
| OP-C04 | **No unified report card** (marks + remarks + grades) | Report season incomplete |
| OP-C05 | **PTM not in parent app** — staff ERP screen only | Parents cannot confirm slots or view summaries in app |
| OP-C06 | **Teacher cannot create/assign homework on mobile** | Daily classroom loop incomplete |

### Important operational gaps

| ID | Gap | Impact |
|----|-----|--------|
| OP-I01 | Smart School adaptation stops at nav + partial dashboards | Disabled modules still appear in reports/copilot |
| OP-I02 | Copilot topic gating unwired (`isCopilotTopicEnabled`) | Misleading AI answers for disabled modules |
| OP-I03 | ~31 dead export/action buttons across ERP modules | Users click Export — nothing happens |
| OP-I04 | Parent rankings absent in mobile exams | Parents cannot see class rank |
| OP-I05 | Bulk marks upload absent | Large schools cannot import marks |
| OP-I06 | Teacher/student dashboards ignore school config | Scenario testing fails adaptation |
| OP-I07 | `report_card` parent nav routes to exams not academic report | Confusing parent journey |
| OP-I08 | Finance/Inventory copilot panels mock-only, not unified chat | Split AI experience |
| OP-I09 | Director school cards not navigable | Portfolio drill-down friction |
| OP-I10 | Lesson plan authoring missing (only lesson logs) | Academic planning gap |
| OP-I11 | Education homework path disconnected from mobile homework | Two parallel systems |

### Optional improvements

| ID | Gap |
|----|-----|
| OP-O01 | Student settings screen (labeled coming soon) |
| OP-O02 | Teacher profile screen (routes to dashboard) |
| OP-O03 | ERP web profile menu stub snackbar |
| OP-O04 | Module settings edit icon buttons (HR, transport, CC, alumni) |
| OP-O05 | Fake export snackbars (inventory, finance executive, admissions reports) |
| OP-O06 | Management priority cards — add navigation |
| OP-O07 | Live GPS transport parent view |
| OP-O08 | Dynamic widgets capability filtering |

---

## 14. Final Recommendation

| # | Question | Answer |
|---|----------|--------|
| 1 | Can a real school run **daily operations** completely? | **Mostly yes** for admissions, fees, attendance (teacher), HR, transport allocation, hostel, library, inventory, notifications, year rollover — in mock/staging. **No** for full classroom homework assignment loop and exam cycle. |
| 2 | Can teachers complete the **academic cycle**? | **No.** Exam create/configure/publish missing; homework create on mobile missing; lesson plans are logs not plans. Marks entry exists in isolation. |
| 3 | Can parents see **complete student progress**? | **Partial.** Attendance, homework, fees, exams (mock), academic summary exist. Missing: rankings, in-app PTM, unified report card, dedicated transport tracking. |
| 4 | Can principals **manage the school completely**? | **Mostly yes** for operations and approvals. **No** for end-to-end exam/results governance. |
| 5 | Can owners manage **multiple schools** completely? | **Yes** in portfolio UI (director portal, trust intel, multi-school ops). Production multi-tenant requires backend RLS. |
| 6 | Is Copilot **connected across the platform**? | **Partial (B).** Dock + metadata everywhere; rich context on few screens; stub replies on mobile; finance/inventory mock panels; topic gating unwired. |
| 7 | Hidden workflow gaps? | **Yes** — exam pipeline, homework dual path, result publish, parent report_card routing, copilot topic gating. |
| 8 | Placeholder experiences remaining? | **Yes** — dead exports (~31), admin hub placeholder, student settings no-op, ERP profile snackbar, director non-tappable cards, copilot stub quick actions. |
| 9 | Should **functional work continue**? | **Yes.** Exam administration chain and Smart School full adaptation are operational blockers for “complete school platform,” independent of theme. Dead export buttons should be fixed or hidden before premium theme makes them prominent. |
| 10 | Can **M15 Theme Modernization** safely begin? | **Yes for visual tokens only** — RC baseline is stable (88/88 Patrol). **Caveat:** M15 will amplify visibility of dead buttons and “coming soon” surfaces. Recommend either (a) hide/disable dead actions in a minimal pre-M15 pass, or (b) accept documented operational gaps and prioritize exam chain post-M15. M15 must not touch routes, workflows, or RBAC. |

---

## Audit method

- Full `lib/` route and feature scan via codebase exploration
- Pattern grep: `onPressed: () {}`, `onTap: null`, “coming soon”
- Smart School: `school_capability_registry.dart`, `school_dashboard_adapter.dart`, `admin_navigation_provider.dart`, `copilot_context_provider.dart`
- Academic chain: school_completion, education, teacher/parent/student exams and homework
- Cross-check against Patrol suites (navigation certified; exam publish not covered)
- Live gate: `flutter test` 1688 passed at `114fc5b`

**No code was modified during this audit.**

---

## Related documents

- `docs/FINAL_TRUTH_AUDIT.md` — roadmap/truth baseline
- `docs/M15_THEME_MODERNIZATION_READINESS.md` — theme scope and risks
- `docs/WORKFLOW_CERTIFICATION_REPORT.md` — Patrol workflow matrix (admin ops)
- `docs/OWNER_DASHBOARD_AUDIT.md` — dashboard functional baseline (partially superseded by this ops audit)
