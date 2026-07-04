# Akshara ERP — Operational Gap Master Tracker

**Version:** 1.0  
**Date:** 2026-06-17  
**Branch:** `feature/m15-theme`  
**Source:** Operational Audit (business operations only — not code quality, theme, or M15)  
**Status:** Planning backlog — **no implementation committed**

> **Engineering gate:** Every gap in this backlog is governed by the Engineering Operating System (`/eos`) per [`engineering/ENGINEERING_GATE_POLICY.md`](engineering/ENGINEERING_GATE_POLICY.md). A gap is not "closed" until `/eos <scope>` returns PASS against the [Engineering Constitution](engineering/AKSHARA_ENGINEERING_CONSTITUTION.md). The EOS is the only engineering standard for this work — do not add bespoke checklists.

---

## How to use this document

| Column | Meaning |
|--------|---------|
| **Gap ID** | Unique tracker ID (`P0-EXAM-001`) |
| **Severity** | P0 = pilot blocking · P1 = important ops · P2 = enhancement |
| **Pilot blocker** | Yes = school cannot run pilot without this |
| **Effort** | S = 1–3d · M = 4–8d · L = 9–15d · XL = 16+d (engineering days, single agent) |
| **Type** | `NET_NEW` · `WIRE` (exists, needs connection) · `DISCONNECT` (duplicate systems to unify) |

**Totals (deduplicated):** 94 backlog items — P0: 18 · P1: 38 · P2: 38

---

## Consolidation notes (duplicates merged)

| Merged into | Former duplicates |
|-------------|-------------------|
| P0-EXAM-001 | Exam scheduling UI + exam types operational + no exam calendar (partial) |
| P0-EXAM-002 | Marks selectors + teacher subject RBAC + max marks validation |
| P0-EXAM-003 | Publish without approval + exam moderation sign-off + report card release chain |
| P0-ATT-001 | Attendance correction + parent dispute ticket + post-submit lock |
| P0-S360-001 | Orphan Student 360 + SIS→360 link + teacher at-risk→360 |
| P0-FIN-001 | Concession assign + scholarship assign + fee waiver approval |
| P0-FIN-002 | Refund initiation + refund documentation |
| P0-RPT-001 | Finance/Inventory/Transport export fake snackbars (all modules) |
| P1-PRIN-001 | Unified approval inbox + fragmented leave/discipline/fee approvals |
| P1-TCH-001 | Homework create local store + homework sync |
| DISC-001 | Education Suite ↔ ExamAdministrationStore |
| DISC-002 | School Completion subjects ↔ AcademicRepository ↔ marks |
| DISC-003 | Three student profile surfaces |

---

## Wiring-only inventory (exists in code, not connected)

| Asset | Location | Wire to |
|-------|----------|---------|
| `createExam`, `scheduleExam`, `openMarksEntry`, `processResults`, `publishExamResults` | `lib/core/exams/exam_administration_store.dart` | ERP exam admin UI + API repository |
| `EduExamType` (weekly/monthly/quarterly/half-yearly/annual) | `lib/features/education/education_models.dart` | Exam administration (not question-paper only) |
| `createSubject`, `updateSubject`, `listSubjects` | `school_completion_repository.dart` | Real subject form + `manageSubjects` guard |
| `SubjectAssignmentScreen` teacher–subject data | `lib/features/school_completion/subject_assignment_screen.dart` | Marks entry RBAC scoping |
| `viewStudent360` permission + `Student360Screen` | `lib/features/student_360/` | SIS registry, teacher at-risk, intelligence drill-down |
| `Student360Profile.communication` | `student_360` models | Student 360 UI tab |
| `approveRefund` / `rejectRefund` | `finance_mutations_provider.dart` | Refund create UI (initiation missing) |
| `createScholarship` / scholarship catalog | Finance repository | Student concession assignment UI |
| `ManagementApprovalType` + `management_tasks_screen.dart` | Management module | Academic, leave, concession approval types |
| `recordTeacherAudit` on marks | `teacher_mutations_provider.dart` | Correct audit event types + backend persistence |
| Admissions `approveAdmission` pattern | `admissions_mutations_provider.dart` | Template for exam/attendance approval chains |
| Library `issueLibraryBook` / `returnLibraryBook` | `library_mutations_provider.dart` | Fine waive/collect (return partially creates fines) |
| Hostel `admitHostelStudent` / `assignHostelRoom` | `hostel_mutations_provider.dart` | Leave approve, attendance mark, visitor register |
| `assignStudentTransport` | `transport_mutations_provider.dart` | Route picker UI (not raw ID field) |

---

## Disconnected features (require unification, not greenfield)

| ID | Systems | Resolution |
|----|---------|------------|
| DISC-001 | Education Suite question papers · `ExamAdministrationStore` marks | Single assessment domain per `docs/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` |
| DISC-002 | School Completion subjects · `AcademicRepository` · exam free-text subject | One academic master catalog |
| DISC-003 | `SisStudentProfileScreen` · `Student360Screen` · `TeacherStudentRiskScreen` | Phase C unified student dossier |
| DISC-004 | `getAcademicSummary` (parent) · published exam results | Parent academic report from live marks |
| DISC-005 | Teacher dashboard check-in · `TeacherAttendanceScreen` | Separate HR staff punch vs class attendance |
| DISC-006 | `SchoolHomeworkStore` · `TeacherRepository` homework | Single homework write path |
| DISC-007 | Management financial approvals · HR leave · Admissions approval | Principal Approval Center (Phase D) |
| DISC-008 | Transport ERP module · parent transport screen | Live tracking + attendance feed to parent app |
| DISC-009 | Marketing spec (`docs/Marketing.md`) · Admissions leads | MK-D-10 handoff + source/campaign on leads |

---

# P0 — Pilot blocking (18 items)

| Gap ID | Module | Description | Business impact | Files likely affected | Dependencies | Effort | Pilot blocker | Type |
|--------|--------|-------------|-----------------|----------------------|--------------|--------|---------------|------|
| P0-EXAM-001 | Exams | No ERP exam administration UI — cannot create/schedule exams by class, section, subject, type, date, max marks | Academic year cannot run; coordinators use spreadsheets | `exam_administration_store.dart`, new `lib/features/education/` or `lib/features/academics/exam_admin/`, `teacher_api_paths.dart`, repository interfaces | DISC-001, API backend | XL | Yes | WIRE |
| P0-EXAM-002 | Exams | Marks entry lacks class/section/subject/exam selectors; single in-memory active exam | Wrong marks entered; subject teachers cannot operate | `teacher_exams_screen.dart`, `teacher_exams_provider.dart`, `mock_teacher_repository.dart` | P0-EXAM-001, DISC-002 | L | Yes | WIRE |
| P0-EXAM-003 | Exams | Teacher publishes results without coordinator/principal approval | Compliance failure; parents lose trust | `teacher_exams_screen.dart`, `teacher_mutations_provider.dart`, new approval workflow | P0-EXAM-001, Phase D | L | Yes | NET_NEW |
| P0-EXAM-004 | Exams | Exam/marks data in `ExamAdministrationStore` (in-memory) — lost on restart | No production data integrity | `exam_administration_store.dart`, new `exam_repository.dart`, API layer | Backend API | XL | Yes | NET_NEW |
| P0-ATT-001 | Attendance | No attendance correction request, edit-after-submit, or approval workflow | Daily ops blocked; disputes unresolved | New attendance correction feature, `teacher_attendance_screen.dart`, `parent_attendance_screen.dart`, ERP admin | Phase D, RBAC | L | Yes | NET_NEW |
| P0-ATT-002 | Attendance | No attendance-specific permissions (`markAttendance`, `correctAttendance`, `approveAttendanceCorrection`) | Any persona can mark; audit fails | `permissions.dart`, `route_guards.dart`, `mutation_permission_registry.dart` | P0-ATT-001 | M | Yes | NET_NEW |
| P0-S360-001 | Student 360 | `Student360Screen` orphaned — no navigation from SIS, teacher, or intelligence | Principal cannot reach unified student view | `student_360_screen.dart`, `sis_registry_screen.dart`, `teacher_class_teacher_dashboard_screen.dart`, `phase4_navigation.dart` | Phase C | M | Yes | WIRE |
| P0-S360-002 | Student 360 | Student 360 missing behaviour, transport, documents domains | Incomplete student dossier for discipline/safety | `student_360_screen.dart`, student 360 repository/DTOs | SIS, transport, discipline modules | L | Yes | NET_NEW |
| P0-FIN-001 | Finance | Cannot assign scholarship/concession to student in UI | Fee waivers not operable; principal cannot govern discounts | `finance` fee assignment screens, `finance_mutations_provider.dart`, `finance_repository.dart` | Phase D approval | L | Yes | WIRE |
| P0-FIN-002 | Finance | Refund creation has no operator UI (approve/reject exists) | Cashier cannot initiate refunds | `finance` refunds screen, `finance_mutations_provider.dart` | — | M | Yes | WIRE |
| P0-FIN-003 | Finance | Report exports show preview snackbars only (no PDF/Excel) | Audit and compliance reporting fails | `finance_reports_screen.dart`, export services across finance/inventory/transport | Shared export service | L | Yes | NET_NEW |
| P0-INV-001 | Inventory | No item/SKU master creation (catalog CRUD) | Store cannot onboard uniforms, lab items, assets | `inventory_repository.dart`, `inventory` catalog/assets screens | — | L | Yes | NET_NEW |
| P0-INV-002 | Inventory | No stock ledger / movement history; qty does not decrement on issue | Stock truth unknown; reconciliation impossible | `inventory_repository.dart`, `inventory_distribution/`, finance reconciliation | P0-INV-001 | XL | Yes | NET_NEW |
| P0-INV-003 | Inventory | PO create and approve same `manageInventory` user — no segregation of duties | Fraud/compliance risk | `inventory_mutations_provider.dart`, `permissions.dart`, Phase D | Principal approval | M | Yes | NET_NEW |
| P0-INV-004 | Inventory | No `storekeeper` role — only `inventoryManager` | Real schools separate clerk vs approver | `permissions.dart`, RBAC role maps | P0-INV-003 | S | Yes | NET_NEW |
| P0-TRN-001 | Transport | GPS/live tracking is placeholder (`getTrackingPlaceholder`) | Parent-facing promise unmet; safety liability | `transport_repository.dart`, `parent_transport_screen.dart`, tracking integration | GPS vendor API | XL | Yes | NET_NEW |
| P0-TRN-002 | Transport | Cannot record transport attendance (pickup/drop) | Safety compliance gap | `transport_attendance_screen.dart`, `transport_mutations_provider.dart` | — | L | Yes | NET_NEW |
| P0-MKT-001 | Marketing | Marketing module MK-01–MK-10 not built (`lib/features/marketing/` absent) | Acquisition ops impossible; AR-004 lead ownership broken | New `lib/features/marketing/`, `docs/Marketing.md` | Admissions handoff | XL | Yes | NET_NEW |

---

# P1 — Important operational capability (38 items)

| Gap ID | Module | Description | Business impact | Files likely affected | Dependencies | Effort | Pilot blocker | Type |
|--------|--------|-------------|-----------------|----------------------|--------------|--------|---------------|------|
| P1-EXAM-001 | Exams | Subject creation FAB hardcodes `'NEW'/'New Subject'` — no form | Junk catalog records | `subjects_screen.dart`, `school_completion_repository.dart` | — | M | No | WIRE |
| P1-EXAM-002 | Exams | `updateSubject` has repository method but no edit UI | Cannot fix catalog errors | `subjects_screen.dart` | P1-EXAM-001 | S | No | WIRE |
| P1-EXAM-003 | Exams | `manageSubjects` not enforced on create mutation | RBAC bypass | `subjects_screen.dart`, `mutation_permission_registry.dart` | — | S | No | WIRE |
| P1-EXAM-004 | Exams | No configurable grading scheme (pass marks, CBSE 9-point, term weightage) | Wrong report cards | `exam_administration_store.dart`, settings | P0-EXAM-004 | L | No | NET_NEW |
| P1-EXAM-005 | Exams | No marks validation (exceed max, absent/exempt/medical codes) | Invalid marks published | `teacher_exams_screen.dart` | P0-EXAM-002 | M | No | NET_NEW |
| P1-EXAM-006 | Exams | No exam/marks permissions (`manageExams`, `manageExamMarks`, `approveExamResults`) | Ungoverned marks access | `permissions.dart`, `route_guards.dart` | P0-EXAM-003 | M | No | NET_NEW |
| P1-EXAM-007 | Exams | Class assignment dialog omits section picker | Wrong section assignments | `subject_assignment_screen.dart` | DISC-002 | S | No | WIRE |
| P1-EXAM-008 | Exams | `processResults` phase in store not exposed in UI | Skips verification before publish | `teacher_exams_screen.dart`, store | P0-EXAM-003 | S | No | WIRE |
| P1-ATT-003 | Attendance | Teacher cannot search students on mobile | Slow class operations | Teacher mobile screens, shared search | — | M | No | NET_NEW |
| P1-ATT-004 | Attendance | No teacher attendance history / past-date roster | Cannot verify or correct history | `teacher_attendance_screen.dart`, repository | P0-ATT-001 | M | No | NET_NEW |
| P1-ATT-005 | Attendance | Post-submit attendance not locked; rows remain editable | Data integrity risk | `teacher_attendance_screen.dart`, mutations | P0-ATT-001 | S | No | NET_NEW |
| P1-ATT-006 | Attendance | Class teacher scope inconsistent (comms scoped; attendance is subject-period) | Role confusion | `teacher_class_teacher_dashboard_screen.dart`, `teacher_attendance_screen.dart` | — | M | No | DISCONNECT |
| P1-ATT-007 | Attendance | Parent dispute = WhatsApp only — no ticket | No audit trail | `parent_attendance_screen.dart` | P0-ATT-001 | M | No | NET_NEW |
| P1-ATT-008 | Attendance | No ERP central student attendance admin/correction screen | Admin cannot govern class attendance | New ERP attendance admin | P0-ATT-001 | L | No | NET_NEW |
| P1-S360-003 | Student 360 | SIS profile lacks marks, homework, behaviour, transport; mobile omits attendance detail | Operators need two UIs | `sis_student_profile_screen.dart` | Phase C | L | No | NET_NEW |
| P1-S360-004 | Student 360 | Communication exists in 360 model but not rendered | Comms history invisible to admin | `student_360_screen.dart` | P0-S360-001 | S | No | WIRE |
| P1-S360-005 | Student 360 | Identity field mismatch (`displayName` vs `identity['name']`) | Wrong names on 360 | `student_360_screen.dart`, mappers | — | S | No | WIRE |
| P1-FIN-004 | Finance | Fee structure has no approval before go-live | Unauthorized fee changes | `finance` fee structures, Phase D | — | M | No | NET_NEW |
| P1-FIN-005 | Finance | Discount rules display only — no create/edit | Cannot configure rules | `finance` discounts screen | P0-FIN-001 | M | No | NET_NEW |
| P1-FIN-006 | Finance | Collection dialog uses free-text invoice ID | Cashier errors | `finance` collections UI | — | S | No | NET_NEW |
| P1-FIN-007 | Finance | Principal has `viewFinance` only — cannot approve refunds/POs in-app | Oversight gap | `permissions.dart`, Phase D | — | M | No | NET_NEW |
| P1-FIN-008 | Finance | Receipt PDF placeholder student names in some paths | Wrong receipts | `finance_receipt_pdf_service.dart` | — | S | No | WIRE |
| P1-FIN-009 | Finance | Offline payment reconciler not separate from recorder role | Segregation of duties | `finance` offline payments | — | M | No | NET_NEW |
| P1-INV-005 | Inventory | No manual stock-in (opening balance, donation, transfer) | Cannot initialize stock | `inventory_repository.dart` | P0-INV-001 | M | No | NET_NEW |
| P1-INV-006 | Inventory | No consumable issue/consumption with department chargeback | Labs/admin stores blocked | New consumption workflow | P0-INV-002 | L | No | NET_NEW |
| P1-INV-007 | Inventory | Procurement receive auto-fills all pending lines — no partial receive | Unrealistic goods receipt | `inventory` procurement UI | — | M | No | NET_NEW |
| P1-INV-008 | Inventory | `manageProcurementWorkflow` / `manageAssetLifecycle` not enforced in mutations | RBAC gap | `inventory_mutations_provider.dart` | — | S | No | WIRE |
| P1-TRN-003 | Transport | Vehicle/driver master read-only — cannot add bus or driver | Fleet ops stuck on seed data | `transport` vehicles/drivers screens, repository | — | L | No | NET_NEW |
| P1-TRN-004 | Transport | Route create captures name only — no stops, timings, bus/driver | Routes unusable | `transport_routes_screen.dart`, repository | — | L | No | NET_NEW |
| P1-TRN-005 | Transport | Student assign uses raw route ID text field | Mis-routing risk | `transport_allocation_screen.dart` | — | S | No | WIRE |
| P1-TRN-006 | Transport | Transport settings edits are preview-only | Cannot configure ops | `transport_settings_screen.dart` | — | M | No | WIRE |
| P1-TRN-007 | Transport | No conductor/driver persona or role | Driver cannot mark attendance | `permissions.dart`, mobile shell | P0-TRN-002 | L | No | NET_NEW |
| P1-HST-001 | Hostel | Leave requests read-only — no approve/reject mutations | Warden cannot operate | `hostel_leave_screen.dart`, `hostel_repository.dart` | Phase D | M | No | NET_NEW |
| P1-HST-002 | Hostel | Hostel attendance read-only — no mark attendance | Boarding compliance gap | `hostel_attendance_screen.dart` | — | M | No | NET_NEW |
| P1-HST-003 | Hostel | Visitor registration preview-only | Security gap | `hostel_visitors_screen.dart` | — | M | No | NET_NEW |
| P1-LIB-001 | Library | Book acquisition / add catalog preview-only | Catalog cannot grow | `library_catalog_screen.dart`, repository | — | M | No | NET_NEW |
| P1-LIB-002 | Library | Fine waive/pay/collect not operational | Revenue recovery blocked | `library_fines_screen.dart`, finance link | P0-FIN-003 | M | No | NET_NEW |
| P1-HR-001 | HR | Staff attendance marking read-only | HR cannot record punch | `hr_attendance_screen.dart`, repository | DISC-005 | M | No | NET_NEW |
| P1-HR-002 | HR | Teaching assignments in School Completion, not HR | HR cannot manage assignments | `subject_assignment_screen.dart`, `hr` module | DISC-002 | M | No | DISCONNECT |
| P1-HR-003 | HR | Recruitment pipeline read-only — no hire-to-employee | Onboarding broken | `hr_recruitment_screen.dart` | — | M | No | NET_NEW |
| P1-HR-004 | HR | Payroll process only — no payslip/disbursement | Payroll incomplete | `hr_payroll_screen.dart` | Finance integration | L | No | NET_NEW |
| P1-PRIN-001 | Principal | No unified approval inbox (leave, discipline, fees, academics, PO) | Principal uses 5+ modules | `management_tasks_screen.dart`, new approval center | Phase D | XL | No | NET_NEW |
| P1-PRIN-002 | Principal | Cannot approve student leave (parent submits; no approver UI) | Leave requests stall | Parent/teacher/HR/management | Phase D | L | No | NET_NEW |
| P1-PRIN-003 | Principal | No same-day attendance exception queue | Cannot govern daily ops | Management + attendance | P0-ATT-001 | L | No | NET_NEW |
| P1-PRIN-004 | Principal | No school-wide notice authoring from exec/teacher | Comms one-directional | New notice publish workflow | — | L | No | NET_NEW |
| P1-TCH-001 | Teacher | Homework create writes to `SchoolHomeworkStore` — not repository | Assignments don't sync | `teacher_homework_create_screen.dart`, `teacher_repository.dart` | DISC-006 | M | No | DISCONNECT |
| P1-TCH-002 | Teacher | Staff check-in routes to class attendance, not HR punch | Misleading UX | `teacher_dashboard_screen.dart`, `teacher_navigation.dart` | DISC-005 | S | No | DISCONNECT |
| P1-TCH-003 | Teacher | No approve/reject student leave on teacher mobile | Class teacher blocked | Teacher leave + parent leave providers | P1-PRIN-002 | M | No | NET_NEW |
| P1-TCH-004 | Teacher | No teacher profile screen (profile nav → dashboard) | Basic UX gap | `teacher_navigation.dart` | — | S | No | NET_NEW |
| P1-PAR-001 | Parent | Parent academic summary static mock — not from published marks | Misleading academic view | `parent_academic_report_screen.dart`, `mock_parent_repository.dart` | DISC-004, P0-EXAM-004 | M | No | DISCONNECT |
| P1-PAR-002 | Parent | Leave submitted — no approval status visibility | Parent anxiety | `parent_leave_screen.dart` | P1-PRIN-002 | S | No | WIRE |
| P1-PAR-003 | Parent | Fee payment uses mock submit unless `PAYMENT_API_ENABLED` | Production payment blocked | `parent_payment_screen.dart` | Payment gateway | M | No | WIRE |
| P1-STU-001 | Student | Homework submit has no file picker/upload | Cannot submit evidence | `student_homework_screen.dart`, mutations | — | M | No | NET_NEW |
| P1-ADM-001 | Admissions | No distinct enquiry screen (AD-03) — folded into leads | Inquiry conversion weak | `admissions` leads screens | P0-MKT-001 | M | No | NET_NEW |
| P1-ADM-002 | Admissions | Marketing handoff MK-D-10 not implemented | Duplicate lead entry | Admissions + marketing | P0-MKT-001 | M | No | DISCONNECT |
| P1-RBAC-001 | RBAC | Teacher mobile routes not in `kErpRouteViewPermissions` | Persona-only security | `route_guards.dart`, mobile routers | — | M | No | NET_NEW |
| P1-RBAC-002 | RBAC | `mutation_permission_registry` missing exam, subject, attendance entries | Audit/compliance gap | `mutation_permission_registry.dart` | P1-EXAM-006, P0-ATT-002 | S | No | WIRE |
| P1-AUD-001 | Audit | Teacher audit uses `enrollmentSubmitted` for exam marks events | Compliance queries fail | `teacher_mutations_provider.dart` | — | S | No | WIRE |
| P1-AUD-002 | Audit | Subject create has no audit event | Catalog changes untracked | `subjects_screen.dart` | P1-EXAM-001 | S | No | WIRE |

---

# P2 — Enhancement (38 items)

| Gap ID | Module | Description | Business impact | Files likely affected | Dependencies | Effort | Pilot blocker | Type |
|--------|--------|-------------|-----------------|----------------------|--------------|--------|---------------|------|
| P2-EXAM-001 | Exams | No exam calendar, invigilator, hall allocation | Manual scheduling outside ERP | New exam calendar feature | P0-EXAM-001 | L | No | NET_NEW |
| P2-EXAM-002 | Exams | No co-scholastic / internal assessment separate from written | Incomplete report cards | Assessment domain | P1-EXAM-004 | L | No | NET_NEW |
| P2-EXAM-003 | Exams | No term-weighted aggregation across multiple tests per subject | Report card math wrong | Results processing | P1-EXAM-004 | L | No | NET_NEW |
| P2-EXAM-004 | Exams | No official report card PDF with letterhead, rank, attendance | Cannot distribute formally | PDF service | Phase I | L | No | NET_NEW |
| P2-EXAM-005 | Exams | No unpublish / post-publish correction workflow | Locked errors | Exam store + approval | P0-EXAM-003 | M | No | NET_NEW |
| P2-EXAM-006 | Exams | No parent notification on result publish | Parents miss results | Notifications | P0-EXAM-003 | M | No | NET_NEW |
| P2-EXAM-007 | Exams | No rank/percentile in marks chain | Limited analytics | Exam results models | — | M | No | NET_NEW |
| P2-EXAM-008 | Exams | Subject–syllabus linkage from catalog missing | Curriculum drift | School completion + education | DISC-002 | M | No | NET_NEW |
| P2-ATT-001 | Attendance | No period-wise / subject-wise attendance (whole-class only) | Secondary schools need periods | Teacher attendance | — | L | No | NET_NEW |
| P2-ATT-002 | Attendance | Student attendance row has no tap-through to profile | Slow teacher workflow | `teacher_attendance_screen.dart` | P0-S360-001 | S | No | WIRE |
| P2-S360-001 | Student 360 | Activities/achievements in model not rendered | Incomplete dossier | `student_360_screen.dart` | — | S | No | WIRE |
| P2-S360-002 | Student 360 | Printable student dossier PDF | Inspection readiness | Export service | Phase I | M | No | NET_NEW |
| P2-FIN-001 | Finance | Fee structure version history / effective dating | Audit gap | Finance settings | — | M | No | NET_NEW |
| P2-FIN-002 | Finance | Bulk class-wise fee assignment beyond admissions queue | Start-of-year slow | Fee assignment screen | — | M | No | NET_NEW |
| P2-FIN-003 | Finance | Transport fee billing integration | Manual fee linking | Finance + transport | P1-TRN-004 | L | No | NET_NEW |
| P2-FIN-004 | Finance | Library fine collection via finance (currently placeholder) | Fine revenue lost | Library + finance | P1-LIB-002 | M | No | WIRE |
| P2-FIN-005 | Finance | Multi-level refund approval (clerk → principal) | Large refund risk | Finance + Phase D | P0-FIN-002 | M | No | NET_NEW |
| P2-INV-001 | Inventory | No physical stock count / variance audit module | Annual audit manual | New inventory audit | P0-INV-002 | L | No | NET_NEW |
| P2-INV-002 | Inventory | No barcode scan at departmental issue (library has scan) | Slow store ops | Inventory UI | — | M | No | NET_NEW |
| P2-INV-003 | Inventory | Asset return-to-store with condition check (general) | Asset loss | Inventory allocations | — | M | No | NET_NEW |
| P2-TRN-001 | Transport | Driver license / fitness expiry alert workflow | Compliance risk | Transport dashboard | P1-TRN-003 | S | No | NET_NEW |
| P2-TRN-002 | Transport | Parent push on pickup/drop | Parent safety expectation | Notifications + P0-TRN-002 | P0-TRN-002 | M | No | NET_NEW |
| P2-HST-001 | Hostel | Room creation preview-only | Cannot expand hostel | `hostel_rooms_screen.dart` | — | M | No | NET_NEW |
| P2-HST-002 | Hostel | Mess menu / outpass (parent app gap for boarders) | Boarding families underserved | Hostel + parent | — | L | No | NET_NEW |
| P2-LIB-001 | Library | Acquisition approval queue | Procurement governance | Library workflow | P1-LIB-001 | M | No | NET_NEW |
| P2-HR-001 | HR | Onboarding checklist wizard beyond single employee create | HR process incomplete | HR employees | — | M | No | NET_NEW |
| P2-HR-002 | HR | Teacher appraisal / observation workflow | Performance mgmt missing | HR performance | — | L | No | NET_NEW |
| P2-MKT-001 | Marketing | MK-05 Social Media | Channel ops | Marketing module | P0-MKT-001 | L | No | NET_NEW |
| P2-MKT-002 | Marketing | MK-07 Content Planner | Planning ops | Marketing module | P0-MKT-001 | M | No | NET_NEW |
| P2-MKT-003 | Marketing | MK-09 Marketing Reports | Operator reporting | Marketing module | P0-MKT-001 | M | No | NET_NEW |
| P2-MKT-004 | Marketing | MK-10 Referrals | Referral program | Marketing module | P0-MKT-001 | M | No | NET_NEW |
| P2-PAR-001 | Parent | PTM slot booking / RSVP (view-only today) | Parent engagement | `parent_ptm_screen.dart` | — | L | No | NET_NEW |
| P2-PAR-002 | Parent | Profile edit (emergency contacts, pickup authorization) | Safety | `parent_profile_screen.dart` | — | M | No | NET_NEW |
| P2-PAR-003 | Parent | Gate pass / early pickup management | Security | New parent feature | — | L | No | NET_NEW |
| P2-PAR-004 | Parent | Consent forms (trips, photos, medical) | Compliance | New parent feature | — | L | No | NET_NEW |
| P2-PAR-005 | Parent | Document upload for leave (medical certificate) | Leave verification | Parent leave | P0-ATT-001 | M | No | NET_NEW |
| P2-TCH-001 | Teacher | Lesson plan / class diary | Academic quality | New teacher feature | — | L | No | NET_NEW |
| P2-TCH-002 | Teacher | Report card remarks / co-scholastic entry | Report completeness | Teacher + exams | P2-EXAM-002 | L | No | NET_NEW |
| P2-TCH-003 | Teacher | Class broadcast notice to all parents | Comms efficiency | Teacher comms | P1-PRIN-004 | M | No | NET_NEW |
| P2-TCH-004 | Teacher | Discipline incident log (templates only today) | Behaviour tracking | New teacher feature | P0-S360-002 | L | No | NET_NEW |
| P2-TCH-005 | Teacher | PTM slot scheduling | Parent meetings | Teacher + parent PTM | P2-PAR-001 | L | No | NET_NEW |
| P2-STU-001 | Student | Library (search, issue, renew, fines) | Student self-service | Student module + library | — | L | No | NET_NEW |
| P2-STU-002 | Student | Exam hall ticket download | Exam ops | Student exams | — | M | No | NET_NEW |
| P2-STU-003 | Student | Online quiz/assessment beyond copilot | Learning | Student + education | — | L | No | NET_NEW |
| P2-STU-004 | Student | Leave self-service option (parent-only today) | Older students | Student module | — | S | No | NET_NEW |
| P2-PRIN-001 | Principal | Timetable change / substitute approval | Daily ops | Timetable + Phase D | — | L | No | NET_NEW |
| P2-PRIN-002 | Principal | Parent grievance / complaint ticketing | Trust | New workflow | — | L | No | NET_NEW |
| P2-PRIN-003 | Principal | Event/calendar management from exec console | School life | Management | — | M | No | NET_NEW |
| P2-PRIN-004 | Principal | Regulatory inspection checklist | Compliance | Management | — | M | No | NET_NEW |
| P2-DIR-001 | Director | Cross-school operational interventions beyond compliance ack | Owner control | Director portal | — | L | No | NET_NEW |
| P2-DIR-002 | Director | New school onboarding from Director UI | Portfolio growth | Director portal | — | L | No | NET_NEW |
| P2-RPT-001 | Reports | Exam-wise marks register export | Academic records | Phase I | P0-EXAM-004 | M | No | NET_NEW |
| P2-RPT-002 | Reports | Attendance register export (class/monthly) | Compliance | Phase I | P0-ATT-001 | M | No | NET_NEW |
| P2-RPT-003 | Reports | Concession/waiver register | Audit | Phase I | P0-FIN-001 | M | No | NET_NEW |
| P2-RPT-004 | Reports | Cross-module compliance audit pack | Auditor | Phase I | P0-FIN-003 | L | No | NET_NEW |

---

# Workflow design errors (tracked as WF items)

| Gap ID | Module | Error | Corrective gap(s) |
|--------|--------|-------|-------------------|
| WF-001 | Exams | Two parallel exam systems (Education Suite vs ExamAdministrationStore) | DISC-001, P0-EXAM-001 |
| WF-002 | Exams | Teacher publishes own marks | P0-EXAM-003 |
| WF-003 | Academics | Subject FAB creates junk records | P1-EXAM-001 |
| WF-004 | Attendance | Class teacher dashboard scope ≠ attendance scope | P1-ATT-006 |
| WF-005 | Attendance | Parent dispute → WhatsApp only | P0-ATT-001, P1-ATT-007 |
| WF-006 | Teacher | Check-in card → student attendance | P1-TCH-002, DISC-005 |
| WF-007 | Teacher | Homework create → local memory | P1-TCH-001, DISC-006 |
| WF-008 | Student | Homework submit without attachment | P1-STU-001 |
| WF-009 | Transport | Route assign via raw ID text | P1-TRN-005 |
| WF-010 | Inventory | PO receive auto-fills all lines | P1-INV-007 |
| WF-011 | SIS | Promotion “principal approval” messaging only | P1-PRIN-001, Phase D |
| WF-012 | Audit | Teacher marks audit event type wrong | P1-AUD-001 |
| WF-013 | Principal | `viewStudent360` but no navigation | P0-S360-001 |
| WF-014 | Management | Finance exec view read-only — ops elsewhere | P1-PRIN-001 |
| WF-015 | Parent | Academic summary disconnected from marks | P1-PAR-001, DISC-004 |

---

# Missing approval chains (tracked as APR items)

| Gap ID | Workflow | Status | Primary remediation |
|--------|----------|--------|---------------------|
| APR-001 | Exam scheduling | Missing | P0-EXAM-001 |
| APR-002 | Marks publication | Teacher only | P0-EXAM-003, Phase D |
| APR-003 | Attendance correction | Missing | P0-ATT-001 |
| APR-004 | Student leave | No approver UI | P1-PRIN-002, Phase D |
| APR-005 | Staff leave | HR only, not unified | P1-PRIN-001, Phase D |
| APR-006 | Fee concession | Missing | P0-FIN-001, Phase D |
| APR-007 | Refund | Weak initiation | P0-FIN-002, P2-FIN-005 |
| APR-008 | Inventory PO | Same user create+approve | P0-INV-003, Phase D |
| APR-009 | Library acquisition | Missing | P2-LIB-001 |
| APR-010 | Hostel leave | Read-only | P1-HST-001 |
| APR-011 | Admissions | **Exists** | Reference pattern for Phase D |
| APR-012 | Fee structure go-live | Missing | P1-FIN-004 |
| APR-013 | Report card release | Missing | P0-EXAM-003, P2-EXAM-004 |
| APR-014 | Marketing campaign spend | Missing | P0-MKT-001, Phase D |

---

# Missing reports (tracked as RPT items)

| Gap ID | Report | Severity | Phase |
|--------|--------|----------|-------|
| RPT-001 | Official report card PDF | P1 | I |
| RPT-002 | Exam-wise marks register | P2 | I |
| RPT-003 | Attendance register export | P2 | I |
| RPT-004 | Attendance correction audit log | P1 | B, I |
| RPT-005 | Fee collection daily close export | P1 | E, I |
| RPT-006 | Defaulters follow-up | P2 | E (exists UI) |
| RPT-007 | Concession/waiver register | P2 | I |
| RPT-008 | Refund register with trail | P1 | E |
| RPT-009 | Stock ledger / movement | P0 | F |
| RPT-010 | Physical stock audit variance | P2 | F |
| RPT-011 | Transport on-time / occupancy export | P1 | G, I |
| RPT-012 | Library overdue / fine collection | P1 | E (lib) |
| RPT-013 | Payroll register / payslips | P1 | E (HR) |
| RPT-014 | Marketing CPL / campaign ROI (operator) | P0 | H |
| RPT-015 | Admissions funnel by source/campaign | P1 | H |
| RPT-016 | Student 360 dossier PDF | P2 | I |
| RPT-017 | Cross-module compliance pack | P2 | I |
| RPT-018 | Real PDF/Excel export infrastructure | P0 | E, I (P0-FIN-003) |

---

# Missing permissions (tracked as RBAC items)

| Gap ID | Permission / control | Severity | Gap |
|--------|---------------------|----------|-----|
| RBAC-001 | `manageExams`, `viewExams` | P1 | P1-EXAM-006 |
| RBAC-002 | `manageExamMarks`, `approveExamResults`, `publishExamResults` | P1 | P1-EXAM-006 |
| RBAC-003 | `markAttendance`, `viewAttendance` | P0 | P0-ATT-002 |
| RBAC-004 | `correctAttendance`, `approveAttendanceCorrection` | P0 | P0-ATT-002 |
| RBAC-005 | `manageSubjects` on create mutation | P1 | P1-EXAM-003 |
| RBAC-006 | `approveInventory`, `approvePurchaseOrder` | P0 | P0-INV-003 |
| RBAC-007 | `storekeeper` role | P0 | P0-INV-004 |
| RBAC-008 | `conductor` / `driver` transport roles | P1 | P1-TRN-007 |
| RBAC-009 | `approveFeeConcession`, `assignScholarship` | P0 | P0-FIN-001 |
| RBAC-010 | `publishNotice`, `manageSchoolCalendar` | P2 | P1-PRIN-004 |
| RBAC-011 | Teacher mobile route guards | P1 | P1-RBAC-001 |
| RBAC-012 | Mutation registry entries (exam, subject, attendance) | P1 | P1-RBAC-002 |
| RBAC-013 | Enforce `manageProcurementWorkflow` / `manageAssetLifecycle` | P1 | P1-INV-008 |

---

# Marketing module gap matrix (vs `docs/Marketing.md`)

| Spec | Gap ID | Status | Priority |
|------|--------|--------|----------|
| MK-01 Dashboard | P0-MKT-001 | Missing | P0 |
| MK-02 Lead Management | P0-MKT-001 | Missing | P0 |
| MK-03 Campaigns | P0-MKT-001 | Missing | P0 |
| MK-04 WhatsApp Automation | P0-MKT-001 | Missing | P0 |
| MK-05 Social Media | P2-MKT-001 | Missing | P2 |
| MK-06 AI Poster Studio | P0-MKT-001 | Missing | P0 |
| MK-07 Content Planner | P2-MKT-002 | Missing | P2 |
| MK-08 Conversion Analytics | P0-MKT-001 (partial: Director ROI only) | Partial | P0 |
| MK-09 Reports | P2-MKT-003 | Missing | P2 |
| MK-10 Referrals | P2-MKT-004 | Missing | P2 |
| MK-D-01–MK-D-10 dialogs | P0-MKT-001 | Missing | P0 |
| MK-D-10 Admissions handoff | P1-ADM-002 | Missing | P1 |
| AR-004 lead ownership split | P0-MKT-001, P1-ADM-002 | Not operational | P0 |

---

# Module readiness (post-audit baseline)

| Module | Ready % | Missing % | Pilot without fix? |
|--------|---------|-----------|-------------------|
| Admissions | 75% | 25% | Yes (with marketing descoped) |
| Finance | 70% | 30% | Partial (concessions/refunds/exports block) |
| HR | 55% | 45% | Partial |
| Library | 50% | 50% | Partial (issue/return only) |
| Parent App | 60% | 40% | Partial |
| Teacher App | 55% | 45% | No (exams/attendance governance) |
| Management / Principal | 50% | 50% | No (approval center) |
| Hostel | 40% | 60% | No (if boarding school) |
| Attendance | 40% | 60% | No |
| Student App | 45% | 55% | Partial |
| Transport | 35% | 65% | No (if transport promised) |
| Academics & Exams | 25% | 75% | No |
| Student 360 | 35% | 65% | No |
| Inventory | 20% | 80% | No (or descope) |
| Marketing | 10% | 90% | No (or descope) |
| Director | 45% | 55% | Yes (analytics only) |
| SIS | 60% | 40% | Partial |
| **Overall operational** | **42%** | **58%** | **No** |

---

# Change log

| Version | Date | Author | Notes |
|---------|------|--------|-------|
| 1.0 | 2026-06-17 | Operational audit program | Initial tracker from full school operations audit |
