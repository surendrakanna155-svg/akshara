# Akshara ERP — Red Team Operational Audit

**Audit date:** 16 June 2026  
**Auditor posture:** Assume go-live tomorrow. Break the product.  
**Method:** Code-verified navigation chains, RBAC matrices, repository wiring, mutation providers, mobile shells, copilot context, and lifecycle handoffs. Roadmap/milestone/doc completion **not** evaluated.

**Scope:** ~200+ registered routes, 253 feature screens, 14 ERP staff roles, 3 mobile personas, 207 permissions, 37 mutation-provider files.

---

## Executive Verdict

Akshara ERP is a **route-complete, mock-first operational prototype** with strong UI coverage and mature RBAC scaffolding. It is **not production-ready for a real school tomorrow**. The product will **appear** to work in a demo because mocks mask broken handoffs, but the first real operational day will expose:

1. **No unified student identity** across SIS, teacher attendance, exams, transport, and hostel.
2. **API write stubs** that throw when any module flag is enabled.
3. **Dead dashboard actions** (28 screens with `onPressed: () {}`).
4. **Stub copilot** with no live LLM and minimal screen context.
5. **Parent/staff route guard gaps** and RBAC bypass on `/school/*`, `/principal-command`, `/growth`.

**Estimated functional completion (real-school operations):** **58–62%**  
**Estimated UI/route coverage:** **~88%**  
**Estimated production backend readiness:** **~35%** (API flags default off; 18 write methods throw `ApiNotConnectedException`)

---

## Part 1 — Daily Workflow Audits by Role

### 1.1 School Owner (`ErpRole.schoolAdmin` / `ErpRole.management`)

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Login | Staff auth → management dashboard | ✅ | Demo/QA login available |
| Morning overview | Management dashboard KPIs | ✅ Partial | KPIs filtered by `SchoolCapabilityRegistry`; admissions/fee cards display-only (no drill) |
| Compare classes | Class performance comparison | ❌ | No class-vs-class report; intelligence is advisory only |
| Fee health | Defaulters, collections | ✅ | KPI → finance defaulters wired |
| Approvals | Management tasks queue | ✅ | Approve/reject mutations exist |
| Staff oversight | HR dashboard, employee 360 | ✅ View | Principal/owner can view HR; no owner-specific staff comparison |
| Export board pack | PDF export | ✅ Partial | Management PDF export works; most module exports are snackbar stubs |
| Multi-school view | Portfolio comparison | ⚠️ | `management` has `viewMultiSchoolOperations`; `schoolAdmin` does not; principal blocked |
| Logout | Session revoke | ✅ | Auth lifecycle implemented |

**Owner gaps:** Cannot compare principals across schools. Cannot compare class outcomes school-wide from one screen. `/admin` hub is still a construction placeholder despite live module dashboards elsewhere.

---

### 1.2 Trust Director (`ErpRole.management` + `trustOrganization` capability)

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Portfolio login | Director portal / trust intelligence | ✅ | `/director/*`, `/organization/intelligence` |
| Compare schools | School comparison tab | ⚠️ | UI exists; `schoolComparisonSelectionProvider` uses **hardcoded demo school IDs** |
| Compare principals | Principal effectiveness by school | ❌ | Teacher effectiveness intelligence exists but not principal comparison |
| Compare finances | Cross-school revenue | ⚠️ | Director revenue screen; mock data; no audited consolidation |
| Compare outcomes | Academic outcomes across trust | ⚠️ | Trust intelligence hub; no certified results export |
| Compliance | Director compliance screen | ✅ UI | Ack/export mutations partial; API director repo fully stubbed |
| Intervene | Activate/deactivate schools | ⚠️ | `manageMultiSchoolOperations` on management only; principal cannot |
| Reports | Director reports | ✅ Catalog | Export actions largely dead |

**Trust gaps:** Comparison data is demo-seeded, not live. Director API repository throws on all methods when API mode enabled. Copilot has label-only context on director screens (no KPIs).

---

### 1.3 Principal (`ErpRole.principal`)

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Arrival | Management dashboard | ✅ | "Owner Dashboard" label in copilot |
| Monitor attendance | School-wide attendance | ❌ | No ERP admin attendance rollup; only teacher mobile + hostel/transport module views |
| Monitor academics | Education suite, syllabus, lesson logs | ✅ | `/education`, `/school/*` routes exist |
| Monitor teachers | Teacher effectiveness, employee intelligence | ✅ View | `/intelligence/teacher-effectiveness`, `/employees/360/:id` |
| Monitor results | Exam intelligence, student success | ✅ Advisory | Not certified report cards; no class aggregate export |
| Intervene | Approvals, workflow automation | ✅ | `management_workflow_actions.dart` |
| Compare classes | Section balance, promotion readiness | ⚠️ | Section balance + promotion screens; promotion uses **isolated MockSisRepository** |
| Transport/hostel oversight | Module dashboards | ❌ | Principal RBAC **excludes** `viewTransport`, `viewHostel` even if school has those modules |
| Principal Command | NL ops queries | ⚠️ | `/principal-command` exists; **route guard bypass** (not in `adminErpRoutes`) |
| Timetable oversight | Management timetable | ⚠️ | Routed at `/management/timetable` but **not in management sub-nav** |
| Logout | ✅ | | |

**Principal gaps:** Cannot run transport/hostel day from principal login. Cannot see school-wide attendance in one place. Class comparison is intelligence-only, not operational. Principal Command and Growth routes bypass permission enforcement.

---

### 1.4 Vice Principal

**No `ErpRole.vicePrincipal` exists.** Vice Principal workflows must use `principal`, `management`, or `teacher` personas. There is no delegated-principal permission subset, no acting-principal workflow, and no VP-specific dashboard.

| Expected | Status |
|----------|--------|
| Acting principal approvals | ❌ No delegation model |
| Discipline / attendance escalation | ❌ No VP screen |
| Substitute teacher coordination | ❌ No VP workflow |
| Exam supervision dashboard | ❌ No VP view |

**Gap severity: Critical** — role does not exist in the product.

---

### 1.5 Teacher (`UserRole.teacher` mobile + `ErpRole.teacher` in matrix)

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Arrival / check-in | Dashboard check-in status | ✅ Display | Check-in action routes to attendance; no GPS/biometric |
| Attendance | Mark class attendance | ✅ | `teacher_mutations_provider.dart` submit |
| Homework | Create + review | ❌ Create | Screen is **Homework Review** only; `create_homework` nav → same screen |
| Lesson plan | Lesson logs | ❌ Mobile | ERP `/school/lesson-logs` only; teacher mobile has no lesson plan |
| Exam | Enter marks | ✅ | `updateExamMark` mutation |
| Parent communication | Messages | ❌ Compose | `sendTeacherMessageProvider` exists; conversation UI is **read-only** |
| Reports | Class report | ❌ | No teacher report generation on mobile |
| Notices | Publish class notice | ❌ | Broadcast admin is ERP-only |
| Logout | ✅ | | |

**Teacher gaps:** Cannot create homework from mobile. Cannot reply in messages. Marks entered do not propagate to student/parent exam providers (separate mock fixtures). Lesson plan entirely missing on mobile.

---

### 1.6 Class Teacher

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Class dashboard | Dedicated 8-A overview | ❌ | `ClassTeacherCard` exists; `class_teacher_dashboard` action routes to **attendance screen** (`teacher_navigation.dart:34-35`) |
| Class attendance | Mark + view trends | ⚠️ | Attendance only; no class trend |
| Class homework | Assign + track | ❌ | Review only |
| Class discipline | Behavior log | ❌ | No feature |
| Parent PTM | Schedule/summarize | ❌ | PTM is ERP admin only |
| Class report card remarks | Generate remarks | ❌ | Education Report Remarks tab is ERP-only |

**Class Teacher gaps:** The "Class Teacher Dashboard" is a **misleading dead-end** — it opens attendance, not a class command center.

---

### 1.7 Accountant (`ErpRole.financeAdmin`)

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Login | Finance dashboard | ✅ | |
| Fee structures | CRUD | ✅ Mock | API mode depends on backend |
| Student accounts | View/create | ✅ | |
| Collections | Record payments | ✅ | Offline + QR screens |
| Defaulters | Follow-up list | ✅ | |
| Refunds | Request/approve flow | ⚠️ | Approval requires `approveRefunds` (principal/management, not financeAdmin alone) |
| Reconciliation | Bank reconciliation screen | ✅ UI | |
| Reports | Collection, outstanding, discount | ⚠️ | Static catalog; export = snackbar "queued" |
| Admissions handoff | Fee assignment from enrollment | ⚠️ | `completeFinanceHandoffAssignment` updates **client StateProvider only** — no SIS trigger |
| Payroll integration | HR payroll costs | ❌ | No cross-module finance-HR report |
| Logout | ✅ | | |

**Accountant gaps:** Handoff completion does not create persistent SIS link. Report exports are fake. Cannot approve own refunds without principal.

---

### 1.8 HR Manager (no dedicated role — `viewHr` on principal/management)

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Employee registry | CRUD | ✅ Mock | API writes throw `ApiNotConnectedException` |
| Attendance | Staff attendance | ✅ UI | |
| Leave | Approve leave | ✅ | `hr_workflow_actions.dart` |
| Payroll | Process payroll run | ⚠️ | UI + mutation; API stubbed; export = snackbar |
| Recruitment | Pipeline | ✅ UI | |
| Performance | Reviews | ✅ UI | |
| Reports | Headcount, attrition, leave balance | ❌ | **No HR reports module**; `HrRepository` has no `getReports` |
| Settings | HR settings | ⚠️ | Export button dead (`onPressed: () {}`) |

**HR gaps:** Zero formal reports. API payroll/leave/employee writes fail in API mode.

---

### 1.9 Librarian (`ErpRole.librarian`)

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Catalog | Browse/manage books | ✅ Mock | Create action dead on catalog screen |
| Issue / Return | Circulation | ✅ | API issue/return throw `ApiNotConnectedException` |
| Members | Student linkage | ✅ | Uses SIS seed IDs only |
| Fines | Fine management | ⚠️ | "Finance FN-02 placeholder" in mock |
| Resources | Digital resources | ⚠️ | Screen exists; actions dead |
| Reports | Circulation, overdue, fines | ⚠️ | Catalog reports; export stubbed |
| Copilot | Library-aware assistant | ❌ | Librarian mapped to **HR copilot persona**; no `CopilotContextScope` |

**Librarian gaps:** No `viewAiCopilot` in role matrix. Fines don't post to finance. New SIS students don't auto-appear as members.

---

### 1.10 Hostel Warden (`ErpRole.hostelManager`)

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Student intake | Admit from enrollment | ❌ | No trigger from admissions `needsHostel` flag |
| Room allocation | Assign rooms | ✅ Mock | API admit/assign/checkout throw |
| Daily attendance | Hostel attendance | ✅ | |
| Leave | Hostel leave | ✅ | |
| Mess | Mess management | ✅ | |
| Visitors | Visitor log + QR | ⚠️ | `_QrPlaceholder` widget — not functional QR |
| Reports | Occupancy, incidents | ⚠️ | Catalog; export stubbed |
| Dashboard | Morning overview | ⚠️ | Export dead |

**Hostel gaps:** Enrollment → hostel pipeline broken. Visitor QR is placeholder. Principal cannot access hostel module.

---

### 1.11 Transport Manager (`ErpRole.transportManager`)

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Route planning | Create/activate routes | ✅ Mock | API create/activate/assign throw (5 methods) |
| Vehicle/driver registry | ✅ | | |
| Student allocation | Assign to routes | ✅ Mock | No sync when SIS converts new student |
| Daily attendance | Bus attendance | ✅ | |
| Live tracking | GPS map | ❌ | `TransportTrackingPlaceholderData`; map is placeholder label |
| Reports | On-time, fuel, utilization | ⚠️ | Catalog; export stubbed |
| Parent visibility | Parent sees bus | ❌ | No parent transport screen |

**Transport gaps:** Live tracking is fake. Parent has zero transport visibility beyond fee line item. API writes entirely stubbed.

---

### 1.12 Parent (`UserRole.parent` mobile)

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Morning check | Dashboard summary | ✅ | Mock fallback if null |
| Attendance | Child calendar | ✅ | |
| Homework | View status | ✅ Read-only | Cannot see teacher feedback inline on all states |
| Notices | School notices | ✅ | Not in bottom nav — dashboard/deep link only |
| Fees | View + pay | ✅ | Payment mutation exists |
| Transport | Route, bus, ETA | ❌ | Fee breakdown + notice filter only |
| Exams | Schedule + results | ✅ | |
| Marks | Subject scores | ✅ | Via exams screen |
| Report cards | Download PDF | ❌ | Text academic report only; `report_card` action → **exams route**, not report |
| PTM | Book slot, join meeting | ❌ | Mock notice on dashboard only; no mobile route |
| Recommendations | Teacher/AI guidance | ⚠️ | Academic report + experience hub; no live recommendations API |
| Messages | Chat with teacher | ❌ Read-only | `ParentRepository.sendMessage` not wired to UI |
| Leave | Apply for child | ✅ | |
| Receipts | PDF download | ✅ | Hardcoded receipt ID map in router (`ph_1` → `rcpt_term_1`) |
| Logout | ✅ | | |

**Parent gaps:** Transport, PTM, messaging reply, formal report card PDF. Staff-only routes (`/parent/insights`, `/parent/experience`) accessible without permission check inside ParentShell.

---

### 1.13 Student (`UserRole.student` mobile)

| Step | Expected | Verified | Gap |
|------|----------|----------|-----|
| Timetable | Daily schedule | ✅ | |
| Homework | View + submit | ✅ | `student_mutations_provider.dart` |
| Attendance | Own calendar | ✅ View-only | |
| Marks / results | Exam results | ✅ | Separate mock from teacher-entered marks |
| Report cards | View/download | ❌ | No report card screen |
| Progress tracking | Academic progress | ❌ | No student progress view |
| AI guidance | Recommendations | ❌ | No student-facing AI guidance screen |
| Notices | Read notices | ✅ | Routed but **not in bottom nav** |
| Fees | View/pay | ❌ | No student fee routes |
| Transport | Bus info | ❌ | |
| PTM | Join/book | ❌ | |
| Messages | Contact teacher | ❌ | |
| Join class (live) | Video/class link | ❌ | `join_class` → timetable (misleading) |
| Profile settings | App settings | ❌ | `onSettingsTap: () {}` — "coming soon" |
| Logout | ✅ | | |

**Student gaps:** No report cards, progress, AI guidance, fees, transport, messaging, or PTM. Exam marks may disagree with teacher-entered marks (data silo).

---

## Part 2 — End-to-End Lifecycle Audit

```
Admissions → Enrollment → Finance Handoff → SIS Conversion → Attendance → Academics → Exams → Results → Promotion → Alumni
```

| Handoff | Status | Evidence |
|---------|--------|----------|
| Lead → Application → Approval | ✅ Works (mock) | `admissions_workflow_actions.dart` |
| Approval → Enrollment | ✅ | `createEnrollment` in mock write store |
| Enrollment → Finance | ⚠️ Partial | `sendToFinance` updates admissions store; finance reads queue |
| Finance assignment → SIS | ❌ **Broken** | `completeFinanceHandoffAssignment` = client `StateProvider` only |
| Enrollment → SIS conversion | ⚠️ Partial | `mock_admissions_sis_bridge.dart`; dual queue sources can diverge |
| SIS → Class attendance | ❌ **Broken** | Teacher mock students ≠ SIS registry (Arjun Das vs Arjun Patel) |
| Attendance → Academics | ❌ | No ERP academics attendance module in chain |
| Academics → Exams | ❌ | `EducationRepository` = papers/homework/remarks only |
| Teacher marks → Student/parent results | ❌ **Broken** | Separate mock fixtures per persona |
| Results → Promotion | ⚠️ Weak | `promotion_readiness_provider` uses intelligence predictions, not exam marks |
| Promotion → Alumni | ❌ **Broken** | `SisStudentStatus.alumni` exists; no `graduateToAlumni` code |
| Alumni auto-onboard | ❌ **UI lie** | Copy says "Auto-onboard Class 12 exits"; alumni data is static seed |
| Admissions `needsTransport`/`needsHostel` → modules | ❌ | Flags exist; conversion does not allocate |

**Additional SIS spec gaps (documented but not built):** Transfer & TC, Exit workflow, Parent mapping, Document vault, SIS Reports (SIS-04 through SIS-08).

**Academic operations isolation:** `MockAcademicOperationsRepository` uses a **second** `MockSisRepository` instance — promoted students from main SIS won't appear in promotion wizard.

---

## Part 3 — Parent Lifecycle Audit

| Capability | Status | Notes |
|------------|--------|-------|
| See attendance | ✅ | `parent_attendance_screen.dart` |
| See homework | ✅ | Read-only |
| See notices | ✅ | Not in bottom nav |
| See fees | ✅ | Pay + receipts |
| See transport | ❌ | Fee line item only |
| See exams | ✅ | |
| See marks | ✅ | Via exams |
| See report cards | ❌ | Text report; no PDF |
| Join PTM | ❌ | No booking flow |
| Receive recommendations | ⚠️ | Academic report + experience hub; stub copilot |

**Parent visibility score: 6/10 critical items fully working.**

---

## Part 4 — Student Lifecycle Audit

| Capability | Status | Notes |
|------------|--------|-------|
| View timetable | ✅ | |
| View homework | ✅ | |
| Submit work | ✅ | |
| View marks | ⚠️ | May not match teacher entry |
| View report cards | ❌ | |
| Track progress | ❌ | |
| View AI guidance | ❌ | |

**Student lifecycle score: 3/7 critical items fully working.**

---

## Part 5 — Principal Audit

| Question | Answer |
|----------|--------|
| Can principal run school daily? | ⚠️ Partial — management dashboard + approvals work; no school-wide attendance rollup |
| Monitor academics? | ✅ Education suite, syllabus, lesson logs, academic progress |
| Monitor teachers? | ✅ Teacher effectiveness, employee 360 |
| Monitor results? | ⚠️ Intelligence screens only; no certified results report |
| Intervene? | ✅ Approval queue, workflow automation |
| Compare classes? | ⚠️ Section balance UI; no operational class comparison report |
| Oversee transport/hostel? | ❌ RBAC blocks `viewTransport`, `viewHostel` |
| Access multi-school portfolio? | ❌ `viewMultiSchoolOperations` not granted |

---

## Part 6 — Owner / Trust Audit

| Question | Answer |
|----------|--------|
| Compare schools? | ⚠️ Trust intelligence + director screens; demo IDs |
| Compare principals? | ❌ |
| Compare finances? | ⚠️ Director revenue; mock |
| Compare outcomes? | ⚠️ Advisory intelligence only |
| Configure disabled modules? | ✅ `SchoolCapabilityRegistry` hides nav/KPIs |
| Trust with 5 schools? | ⚠️ UI supports; data is mock; comparison uses hardcoded selection |

---

## Part 7 — Dashboard Audit (Dead Actions)

**28 screens** contain `onPressed: () {}` — confirmed no-op handlers:

| Module | Screens with dead actions |
|--------|--------------------------|
| Control Center | dashboard, analytics, CRM, schools, settings, roles |
| Alumni | dashboard, registry, events, campaigns, mentorship, reports, settings |
| HR | dashboard, settings |
| Transport | dashboard, settings |
| Hostel | dashboard, rooms, visitors |
| Library | dashboard, catalog, resources, reports |
| SIS | registry (export) |
| Finance | reports (2 dead handlers) |
| Intelligence | intelligence_screen |

**Export pattern:** Most "Export" buttons show snackbar `"Export queued"` (`akshara_analytics_panel.dart`, finance/transport/inventory reports) — **no file is produced**.

**Stale metadata:** `kAdminModuleInfo` still labels Admissions "Not started yet" while `/admissions/dashboard` is fully built. `/admin` shows `AdminModulePlaceholderScreen` (construction icon).

**Management dashboard:** Admissions/fee snapshot cards are display-only (no tap). Timetable and intelligence routes exist but are absent from sub-nav tabs.

---

## Part 8 — Copilot Audit

| Dimension | Status | Detail |
|-----------|--------|--------|
| Context awareness | ❌ Poor | Only **12 screens** use `CopilotContextScope`; only 3 with KPIs (management, platform intelligence, student success) |
| Role awareness | ⚠️ Partial | `copilot_role_intelligence.dart` maps personas; module managers get HR persona incorrectly |
| School awareness | ⚠️ Partial | `schoolConfig.copilotMetadata()` injected; `isCopilotTopicEnabled` **defined but never called** |
| Capability awareness | ❌ | Copilot can discuss transport/hostel when modules disabled |
| Live AI | ❌ | `copilot_stub_responses.dart`, `stub_ai_provider.dart`, `mock_copilot_repository.dart` |
| Module coverage | ❌ | Admissions, finance, SIS, HR, transport, hostel, library, inventory, alumni — dock only, no screen context |
| Trust/multi-school | ❌ | No `CopilotContextScope` on trust hub or multi-school portfolio |
| Principal Command | ❌ | No copilot context despite being AI feature |
| Auth on `/ai-assistant` | ❌ | Not in `_isProtectedRoute()` — reachable without auth |
| Dock visibility | ⚠️ | Shows for all authenticated users; send requires `runAiCopilot` |

**Copilot functional completion: ~25%** (shell + persona prompts exist; operational awareness does not).

---

## Part 9 — Mobile Parity Audit

| ERP Workflow | Parent | Teacher | Student |
|--------------|--------|---------|---------|
| Attendance | View ✅ | Mark ✅ | View ✅ |
| Homework | View ✅ | Review ✅ (no create) | Submit ✅ |
| Fees | Pay/view ✅ | — | — ❌ |
| Transport | ❌ | — | — ❌ |
| Exams/marks | View ✅ | Enter ✅ | View ⚠️ (data silo) |
| Report cards | Text only ⚠️ | — | — ❌ |
| PTM | ❌ | ❌ | ❌ |
| Notices | Read ✅ | — ❌ | Read ✅ (hidden nav) |
| Messaging | Read-only ❌ | Read-only ❌ | — ❌ |
| Recommendations | Partial ⚠️ | — ❌ | — ❌ |
| Leave | Apply ✅ | Apply ✅ | — ❌ |
| Lesson plan | — ❌ | — ❌ | — ❌ |

**Navigation quirks:**
- Teacher notifications → `RouteNames.parentNotifications`
- Student notifications → same parent notifications route
- Parent bottom nav: Home · Academics · Fees only (7+ routes orphaned from nav)

**Repository default:** All three personas use mock repositories unless `ENABLE_API_MODE` + per-persona flags.

---

## Part 10 — Configuration Audit

| Scenario | Nav adaptation | KPI adaptation | Copilot adaptation | RBAC adaptation |
|----------|---------------|----------------|-------------------|-----------------|
| School without hostel | ✅ Hidden | ✅ | ❌ Topics not filtered | ❌ Principal couldn't access anyway |
| School without transport | ✅ Hidden | ✅ | ❌ | ❌ |
| School without library | ✅ Hidden | ✅ | ❌ | N/A |
| School with hostel | ✅ Shown | ✅ | ❌ | Warden only |
| Trust with 5 schools | ✅ Director/CC shown | ⚠️ Mock | ❌ Hardcoded comparison IDs | Principal blocked from multi-school |

**Configuration provider:** `school_configuration_provider.dart` → `adaptManagementDashboard` / `adaptParentDashboard` filter KPIs and notices. Demo default enables **all** modules + trust — real configs require `school_discovery_screen.dart`.

---

## Part 11 — Production Audit

| Risk class | Findings |
|------------|----------|
| Hardcoded data | Demo student roster (ADM-2026-0138, Arjun Patel); 2026 admission numbers; receipt ID map in router; education probe IDs |
| Mock repositories | Default for all modules; `branch`, `franchise`, `parentMeetings` **always mock** (no API flag) |
| Demo assumptions | `TenantContext.demo`, `AuthTokens.demo`, QA login personas, demo auth env flags |
| API write stubs | 18 methods throw `ApiNotConnectedException`: transport (5), HR (5), hostel (3), library (2), inventory (3), director (all) |
| API flag defaults | Only `AUTH_API_ENABLED` defaults true when API mode on; all others false |
| Missing persistence | In-memory write stores; client-side bridges; finance handoff StateProvider |
| Hybrid repos | No mock fallback on API failure — hard errors |
| Alumni/Control Center | Read-only — no mutation providers |

---

## Part 12 — Security & RBAC Gaps

| ID | Severity | Gap |
|----|----------|-----|
| SEC-01 | Critical | `canAccessErpRoute()` returns `true` for routes not in `adminErpRoutes` — `/school/*`, `/principal-command`, `/growth`, `/setup-wizard` bypass permission checks |
| SEC-02 | Critical | Parent shell routes `/parent/insights`, `/parent/experience`, `/parent/academic-report` lack staff permission guards |
| SEC-03 | High | `/ai-assistant` not auth-protected |
| SEC-04 | High | `ControlCenterGuard` (superAdmin-only) defined but never wired |
| SEC-05 | Medium | `manageAlumni` used in UI but missing from mutation registry |
| SEC-06 | Medium | Transport/hostel/librarian/inventory roles lack `viewAiCopilot` |
| SEC-07 | Medium | `viewOnboarding`/`manageOnboarding` unmapped to routes |

---

## Final Output

### Critical Gaps (P0 — blocks real-school go-live)

1. **No unified student identity** — SIS, teacher, student, parent, transport, hostel use divergent mock datasets.
2. **Finance → SIS handoff is client-only** — fee assignment does not persist or trigger SIS conversion completion.
3. **API write stubs** — 18 repository methods throw when API flags enabled; UI appears functional.
4. **RBAC bypass on AdminShell evolution routes** — `/school/*`, `/principal-command`, `/growth` unguarded.
5. **Parent staff-feature routes unguarded** — insights/experience accessible to any parent session.
6. **Vice Principal role does not exist** — no delegation model.
7. **Promotion uses isolated SIS instance** — academic operations won't see main registry students.
8. **Alumni graduation pipeline missing** — UI claims auto-onboard; no code path exists.
9. **Teacher marks don't reach student/parent** — separate exam mock fixtures.
10. **Transport live tracking is placeholder** — operational safety risk for schools.

### Important Gaps (P1 — severe operational friction)

11. Teacher cannot create homework or send messages from mobile.
12. Parent cannot see transport, book PTM, reply to messages, or download report card PDF.
13. Student has no report cards, progress, AI guidance, fees, or transport.
14. Class Teacher Dashboard routes to attendance — misleading dead action.
15. Principal cannot access transport/hostel modules despite school config.
16. HR has zero reports module.
17. 28+ dashboard export/create buttons are no-ops.
18. Report exports universally fake (snackbar only).
19. Copilot is stub-only with minimal context on 95% of screens.
20. `isCopilotTopicEnabled` never enforced.
21. Management timetable/intelligence not in sub-nav.
22. `/admin` hub still placeholder.
23. Enrollment transport/hostel flags don't trigger allocation.
24. SIS Transfer, Exit, Parent mapping, Document vault, Reports not built.
25. Director API repository entirely stubbed.

### Operational Risks

- Staff trained on demo data will enter real students who **won't appear** in teacher attendance or transport lists.
- Principal morning briefing shows KPIs that **filter correctly by config** but underlying data is not connected.
- Accountant completes fee handoff believing student is enrolled; SIS may not reflect fee account linkage.
- Warden admits student manually; no link to admissions enrollment queue.
- Export buttons train users to expect PDFs that never arrive.

### Pilot Risks

- Pilot sign-off on mocks will pass Patrol tests while **lifecycle handoffs remain broken**.
- QA personas mask RBAC gaps (QA login grants full matrix).
- Demo default enables all modules — pilot school with disabled hostel still shows copilot hostel advice.
- `MockAttendanceSyncStore` creates illusion of teacher→parent sync that doesn't use real student IDs.

### Production Risks

- Enabling `ENABLE_API_MODE` without full backend causes immediate mutation failures.
- Hybrid repositories fail hard — no graceful degradation.
- Hardcoded 2026 dates/amounts in reports will confuse real schools.
- Branch/franchise/parent meetings have no API path ever.
- Infrastructure ~68% per existing sign-off — client ahead of backend.

---

## Top 25 Remaining Defects

| # | Defect | Role impact | File evidence |
|---|--------|-------------|---------------|
| 1 | Student identity silos across all modules | All | `mock_sis_repository.dart`, `mock_teacher_repository.dart`, `mock_student_repository.dart` |
| 2 | Finance handoff doesn't persist to SIS | Accountant, Admissions | `finance_admissions_handoff_provider.dart` |
| 3 | API write stubs (18 methods) | HR, Transport, Hostel, Library, Inventory, Director | `api_*_repository.dart` |
| 4 | RBAC bypass on `/school/*` routes | All staff | `route_guards.dart:154-156`, `route_names.dart` |
| 5 | Parent insights/experience unguarded | Parent, Security | `app_router.dart` ParentShell |
| 6 | No Vice Principal role | VP | `erp_role.dart` |
| 7 | Isolated MockSisRepository in academic ops | Principal | `repository_providers.dart:154` |
| 8 | No alumni graduation automation | Principal, Alumni | `alumni_registry_screen.dart` (copy only) |
| 9 | Teacher marks ≠ student/parent results | Teacher, Parent, Student | `mock_teacher_repository.dart:419` |
| 10 | Transport tracking placeholder | Transport Mgr, Parent | `transport_tracking_screen.dart` |
| 11 | Class teacher dashboard → attendance | Class Teacher | `teacher_navigation.dart:34-35` |
| 12 | Teacher cannot create homework | Teacher | `teacher_homework_screen.dart` |
| 13 | Messaging read-only (parent + teacher) | Parent, Teacher | `parent_conversation_screen.dart`, `teacher_conversation_screen.dart` |
| 14 | No parent transport/PTM mobile | Parent | No routes in `app_router.dart` |
| 15 | No student report cards/progress/AI | Student | `lib/features/student/` |
| 16 | Principal blocked from transport/hostel | Principal | `role_permissions.dart` principal block |
| 17 | No HR reports | HR Manager | No `hr_reports_*` files |
| 18 | 28 dead `onPressed: () {}` | All ERP dashboards | See Part 7 |
| 19 | Fake report exports | Accountant, All | `akshara_analytics_panel.dart` |
| 20 | Copilot stub only | All | `copilot_stub_responses.dart` |
| 21 | `isCopilotTopicEnabled` unwired | All | `school_capability_registry.dart:39` |
| 22 | `/admin` placeholder hub | School Admin | `admin_module_placeholder_screen.dart` |
| 23 | `ControlCenterGuard` unused | Security | `route_guards.dart:354-371` |
| 24 | `/ai-assistant` unauthenticated | Security | `app_router.dart` |
| 25 | Hardcoded demo comparison school IDs | Trust Director | `platform_intelligence_providers.dart` |

---

## Estimated Functional Completion

| Dimension | % | Rationale |
|-----------|---|-----------|
| UI / screen coverage | **88%** | 253 screens; most modules have full nav trees |
| Workflow mutations (mock mode) | **72%** | 37 mutation providers; alumni/control_center read-only |
| Lifecycle chain integrity | **35%** | Handoffs break at finance→SIS, attendance, results, alumni |
| Mobile parity (critical parent journeys) | **60%** | 6/10 parent critical items |
| Mobile parity (teacher daily) | **55%** | Attendance+marks work; create homework/messages/reports don't |
| Mobile parity (student daily) | **43%** | 3/7 critical items |
| RBAC enforcement | **78%** | Strong on core ERP routes; bypass on evolution routes |
| Copilot operational value | **25%** | Shell + stubs; minimal context |
| Report generation (real output) | **15%** | Catalogs exist; exports fake |
| Production backend readiness | **35%** | API stubs, mock defaults, no persistence |
| **Overall real-school functional completion** | **58–62%** | Weighted toward operational truth, not UI count |

---

## If a Real School Starts Tomorrow, What Breaks First?

### Hour 1 — Admissions office
Counselor approves admission, sends to finance, accountant assigns fee plan. **Handoff appears complete but SIS conversion queue may not reflect finance status.** Two enrollment queues (admissions vs SIS seed) can show different students. Admission numbers hardcode `ADM-2026-*`.

### Hour 2 — Class teacher
Teacher opens attendance for Class 8-A. **Student names don't match SIS registry** — teacher sees "Arjun Das" while SIS has "Arjun Patel." Teacher marks attendance; parent KPI may update via `MockAttendanceSyncStore` but **not tied to real student IDs.**

### Day 1 — Parent app
Parent logs in, checks homework and fees (works on mock). Asks "where is the school bus?" — **no transport screen.** Tries to reply to teacher message — **read-only.** Taps "Report Card" quick action — **lands on exams, not a report card.**

### Day 1 — Principal
Principal needs hostel occupancy for assembly planning — **cannot open hostel module** (RBAC). Opens management dashboard — KPIs look healthy on mock data. Tries to export board report from control center — **button does nothing.**

### Week 1 — Transport manager
New admits flagged `needsTransport` — **no auto-allocation.** Manually assigns in transport module; parent still cannot see bus info. Enables API mode for transport — **all writes throw `ApiNotConnectedException`.**

### Month 1 — End of term
Teacher enters exam marks. Student and parent apps show **different results.** Principal runs promotion — **students from live SIS may not appear** (isolated academic ops repo). Class 12 graduates — **alumni registry does not auto-populate** despite UI promise.

### First trust board meeting
Director opens school comparison — sees **demo schools with hardcoded IDs**, not the trust's five live schools. Export strategic report — snackbar says "queued"; **no PDF.**

---

## Recommended Remediation Priority

1. **Unified student identity bus** — SIS as single source of truth; propagate IDs to teacher, parent, student, transport, hostel, library, finance.
2. **Wire finance → SIS handoff** — persistent completion trigger on fee assignment.
3. **Close API write stubs** or gate UI mutations when API not ready.
4. **Fix RBAC bypass** — extend `adminErpRoutes`; wire `ControlCenterGuard`; guard parent staff routes.
5. **Mobile parity sprint** — parent transport + PTM; teacher homework create + messaging; student report cards.
6. **Replace dead dashboard actions** — export/create handlers or remove buttons.
7. **Copilot context pass** — `CopilotContextScope` on top 20 screens; wire `isCopilotTopicEnabled`.
8. **Alumni graduation pipeline** — SIS exit → alumni create.
9. **Add Vice Principal role** or document principal delegation.
10. **Principal transport/hostel view permissions** when capabilities enabled.

---

*This audit reflects code state as of 16 June 2026. Findings are from navigation-chain verification, not documentation claims.*
