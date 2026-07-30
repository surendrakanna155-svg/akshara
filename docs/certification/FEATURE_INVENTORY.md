# NIKSHA OS — Complete Feature Inventory (Workstream 1)

**Built FROM CODE, not from docs.** Branch `release/v1.0-playstore`.
Sources of truth used:

| Concern | File(s) read |
|---|---|
| Reachable screens | `lib/router/route_names.dart`, `lib/router/app_router.dart` |
| Module tree | `lib/features/**` |
| Backend endpoints | `supabase/functions/_shared/route_registry.ts` + `_shared/**/*_router.ts` |
| Roles & permissions | `lib/core/security/erp_role.dart`, `permissions.dart`, `role_permissions.dart`, `rbac_module_registry.dart`, `lib/router/route_guards.dart` |
| Live-vs-mock | `config/live_release.json` × `lib/core/repositories/repository_config.dart` × `lib/core/repositories/repository_providers.dart` |
| Surface hiding | `lib/core/config/surface_backend_gate.dart` |

## Status definitions & how each was decided

- **LIVE** — route is registered AND passes the release-build surface gate AND its
  repository provider resolves to an `Api*` implementation under
  `config/live_release.json` AND a matching backend prefix exists in
  `supabase/functions/_shared/route_registry.ts`.
- **MOCK** — route is registered and reachable, but in the shipping release build
  the repository resolves to a `Mock*` implementation. Decided mechanically: the
  module's `*_API_ENABLED` key is **absent from `config/live_release.json`**, so the
  `bool.fromEnvironment(..., defaultValue: false)` in `repository_config.dart` wins.
- **HIDDEN** — deliberately unreachable in a V1 release build: either no route is
  registered at all, or `surface_backend_gate.dart` removes the entry point when the
  module flag is off (backend-less surfaces are hidden rather than shown broken).
- **DEAD** — code exists with no reachable entry point from any registered route or
  widget tree.
- **UNKNOWN** — stated explicitly with what would be needed to decide.

### The release-build flag ledger (mechanical basis for MOCK)

`config/live_release.json` sets `ENABLE_API_MODE=true`, `APP_ENV=production` and
**41** module flags. Every `*ApiEnabledProvider` in `repository_config.dart` whose
key is **not** in that JSON returns `false` in the release build.

**Flags ON in the shipping release build (41):**
`AUTH`, `ADMISSIONS`, `SIS`, `STUDENT`, `TEACHER`, `PARENT`, `ACADEMIC`,
`ACADEMIC_TIMETABLE`, `EXAM`, `ATTENDANCE`, `EDUCATION`, `FINANCE`, `PAYMENT`,
`INVENTORY_FINANCE`, `HR`, `TRANSPORT`, `HOSTEL`, `LIBRARY`, `INVENTORY`,
`INVENTORY_DISTRIBUTION`, `ALUMNI`, `APPROVAL`, `MANAGEMENT`, `COMMUNICATION`,
`ONBOARDING`, `AUDIT`, `PHASE5`, `EMPLOYEE`, `SCHOOL_COMPLETION`,
`ANALYTICS_INTELLIGENCE`, `INTELLIGENCE`, `AI_COPILOT`, `ADAPTIVE_AI`, `EVOLUTION`,
`DIRECTOR`, `PREDICTIONS`, `CONTROL_CENTER`, `SCHOOL_CONFIG`, `ORGANIZATION_BUILDER`,
`ENTITLEMENT`, `SUPPORT`.

**Providers with NO key in `live_release.json` → mock/hidden in release (18):**
`ACADEMIC_OPERATIONS`, `CONTINUITY`, `WORKFLOW`, `MULTI_SCHOOL_OPERATIONS`,
`PLATFORM_INTELLIGENCE`, `PLATFORM_OPERATIONS`, `BRANCH`, `BRANCH_OPERATIONS`,
`FRANCHISE`, `FRANCHISE_OPERATIONS`, `RESOURCE_OPTIMIZATION`, `HEALTHCARE`, `SALON`,
`RESTAURANT`, `ACCOMMODATION`, `WHITE_LABEL_PLATFORM`, plus the hard-coded
`advancedAcademicOperationsEnabledProvider` (`=> false`, no dart-define at all).

---

<!-- Module sections appended below, one at a time. -->
## M1 — Authentication, Session & Legal

Routes are top-level (outside every shell). `_authRedirect` in `app_router.dart`
drives them; `AUTH_API_ENABLED=true` in the release config, so `authApiEnabledProvider`
resolves live.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Auth | Splash / session bootstrap | `/splash` → `SplashScreen` | all | (session validate) | LIVE |
| Auth | Parent/student OTP login | `/login` → `LoginScreen` | parent, student | `POST /auth/*` (`auth_handlers.ts`, `auth_login_helpers.ts`) | LIVE |
| Auth | OTP verification | `/otp?phone=&role=` → OTP screen | parent, student | `auth_handlers.ts` + `otp_rate_limit.ts` | LIVE |
| Auth | Staff login (identifier) | `/staff/login` → `StaffLoginScreen` | staff, teacher | `auth_handlers.ts` | LIVE |
| Auth | Staff OTP | `/staff/otp?id=` | staff, teacher | `auth_handlers.ts` | LIVE |
| Auth | QA/demo role login | `/qa-login` → `QaLoginScreen` | dev only | none (local) | HIDDEN — dev-only entry; `guardForRelease` + `APP_ENV=production` block the demo path in a release build |
| Legal | Mandatory policy-acceptance gate | `/legal-acceptance` → `LegalAcceptanceScreen`; forced by `legalGateRedirect` | all | `GET /legal/status`, `POST /legal/accept` | LIVE (fail-open by design if the endpoint is down) |
| Security | Biometric app lock (SEC-1) | no route — inline confirm wrapper (`lib/core/security/app_lock/`) | all | none (device-local) | LIVE |
| Security | Denied-access audit | no route (`denied_access_audit.dart`), fires from `ErpRouteGuard` | all | `POST /audit/events` | LIVE |
| Security | Server-authoritative permissions | no route (`server_permission_provider.dart`, `permission_sync_service.dart`) | all | `/identity/permission-overrides`, `/identity/roles` | LIVE |

## M2 — Shared / cross-persona surfaces

Registered top-level (outside the admin shell) so every persona can reach them.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Settings | AI assistant settings | `/settings/ai-assistant` | all | `/copilot/*` | LIVE |
| Settings | Appearance / theme | `/settings/appearance` → `AppearanceSettingsScreen` | all | none (local prefs) | LIVE |
| Sync | Offline sync centre | `/sync-center` → `SyncCenterScreen` | all | per-module write replay | LIVE |
| AI | AI assistant (Copilot chat) | `/ai-assistant` | all | `/copilot/sessions`, `/copilot/suggestions`, `/copilot/assistants` | LIVE (`AI_COPILOT_ENABLED=true`) |
| Notifications | Parent notifications inbox | `/parent/notifications` → `NotificationsScreen` | parent | `GET /parent/notifications`, `POST /parent/notifications/mark-read`, `.../mark-all-read` | LIVE |
| Notifications | Teacher notifications inbox | `/teacher/notifications` → same `NotificationsScreen` | teacher | `/communications/*` | LIVE |
| Attendance auth | Staff face capture | `/staff-attendance/face-capture` (pushed from `MlkitFaceCaptureSource`) | staff, teacher | `POST /staff-attendance/check` | LIVE |
| Attendance auth | Staff face enrolment | `/staff-attendance/face-enrollment` → `FaceEnrollmentScreen` | staff, teacher | `POST /attendance-auth/face/enroll`, `GET /attendance-auth/face/enrollment`, `POST /attendance-auth/face/revoke` | LIVE — note the 192-d model asset + threshold were tracked residue; asset presence not verifiable from source alone |

## M3 — Support (ASIP Phase 1)

`SUPPORT_API_ENABLED` was **added** to `live_release.json` during the RC phase after
the exact defect this inventory is meant to catch (release builds fell back to
`MockSupportRepository`, which returned a fabricated `SUP-xxxx` reference for a report
that was never sent). It is now present, so the release build resolves
`apiSupportRepositoryProvider`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Support | My reported issues | `/support` → `MyReportedIssuesScreen` (AuthenticatedGuard) | all authenticated | `GET /support/incidents` | LIVE |
| Support | Report an issue | `/support/new` → `ReportIssueScreen` | all authenticated | `POST /support/incidents` | LIVE |
| Support | Incident detail | `/support/:id` → `SupportIncidentDetailScreen` | all authenticated | `GET /support/incidents/:id` | LIVE |
| Support | Akshara-side triage view | mapped to `Permission.viewSupport` in `kErpRouteViewPermissions`; served under `/control-center/support` | superAdmin | `GET /control-center/support-tickets` | LIVE (Control-Center surface) |

> ⚠ Boundary: `live_release.json` itself records that the support **migration APPLY**
> on the live DB was not verifiable from the build host. If the tables are absent the
> client now fails honestly rather than fabricating a reference — but "tables exist in
> prod" is UNVERIFIED here (no Postgres lane, SSH owner-bound).

## M4 — Parent App (`ParentShell`, `lib/features/parent/`)

`PARENT_API_ENABLED=true` → `parentRepositoryProvider` resolves `ApiParentRepository`.
`PHASE5_API_ENABLED=true` → parent-experience surfaces resolve live.
`EVOLUTION_API_ENABLED=true` → parent insights resolve live.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Parent | Dashboard (child switcher, quick actions) | `/parent/dashboard` | parent | `GET /parent/dashboard` | LIVE ⚠ falls back to fabricated demo data on failure — **CERT-002** |
| Parent | Attendance view | `/parent/attendance` | parent | `GET /parent/attendance` | LIVE |
| Parent | Attendance correction request | inside `/parent/attendance` | parent | `POST /parent/attendance/corrections` | LIVE |
| Parent | Fees & dues | `/parent/fees` | parent | `GET /parent/fees` | LIVE ⚠ **CERT-001 (P0)** — fabricated fee statement on failure |
| Parent | Fee payment | `/parent/payment?installmentId=` | parent | `POST /parent/payments/initiate`, `POST /parent/payments/confirm`, `POST /payments/intents/initiate`, `POST /payments/intents/confirm`, `POST /webhooks/razorpay` | LIVE code path; **gateway is stubbed** — no live Razorpay credentials (charter boundary) → UNKNOWN end-to-end until keys are provisioned |
| Parent | Receipts list | `/parent/receipts` | parent | `GET /parent/receipts` | LIVE |
| Parent | Receipt detail + PDF export | `/parent/receipts/:receiptId` | parent | `GET /parent/receipts`, `financeRepository.getReceipt` | LIVE ⚠ entry-point id mapping broken — **CERT-003** |
| Parent | Fee certificate | (no route; served by `/parent/fee-certificate`) | parent | `GET /parent/fee-certificate` | UNKNOWN — backend endpoint exists, no registered Flutter route found; need a UI trace to decide DEAD vs embedded affordance |
| Parent | Timetable | `/parent/timetable` | parent | `GET /parent/timetable` | LIVE |
| Parent | Homework | `/parent/homework` | parent | `GET /parent/homework` | LIVE ⚠ **CERT-002** |
| Parent | Exams & results | `/parent/exams` | parent | `GET /parent/exams` | LIVE |
| Parent | Notices | `/parent/notices` | parent | `GET /parent/notices` | LIVE |
| Parent | Events | `/parent/events` | parent | `GET /parent/events` | LIVE |
| Parent | Transport allocation + ETA | `/parent/transport` | parent | `/transport/allocations`, `POST /transport/notify-delay` | LIVE (`TRANSPORT_API_ENABLED=true`) |
| Parent | Leave request | `/parent/leave` | parent | `GET/POST /parent/leave` (pilot router) | LIVE |
| Parent | Messages / threads | `/parent/messages`, `/parent/messages/:threadId` | parent | `GET /parent/messages`, `/parent/messages/threads`, `POST /parent/messages/send` | LIVE |
| Parent | Broadcast message detail + ack | `/parent/messages/comm/:messageId` | parent | `GET /parent/communication/inbox`, `POST /parent/communication/{id}/read`, `/{id}/acknowledge` | LIVE |
| Parent | Family view (all children) | `/parent/family` | parent | `GET /parent/dashboard` per child | LIVE |
| Parent | Action inbox | `/parent/action-inbox` | parent | `GET /parent/dashboard` | LIVE |
| Parent | Profile | `/parent/profile` | parent | `GET /parent/profile` | LIVE |
| Parent | Parent experience hub | `/parent/experience` | parent | `GET /parent/experience/hub`, `/summary`, `POST /parent/experience/acknowledge`, `/summary/refresh` | LIVE (`PHASE5_API_ENABLED`) |
| Parent | Academic report (structured, no AI chat) | `/parent/academic-report` | parent | `GET /parent/experience/report/printable` | LIVE |
| Parent | AI parent insights | `/parent/insights` | parent | `GET /parent-insights`, `POST /parent-insights/generate`, `/language-preference` | LIVE — entitlement-gated `feature.parent_insights` |
| Parent | Parent-teacher meetings (PTM) | `/parent/ptm` | parent | `GET /parent/meetings` | **HIDDEN** — `SchoolBuildScope.hiddenRoutePrefixes` contains `RouteNames.parentPtm`; builder returns `AccessDeniedScreen`. Gated off because it was mock-only and lost edits on restart (CORE-1/PAR-4) |
| Parent | Notifications inbox | `/parent/notifications` | parent | `/parent/notifications*` | LIVE |
| Parent | Push device registration | no route (background) | parent | `POST /parent/device-tokens/register` / `/unregister` | LIVE code path; **no live push in dev** (charter boundary) |

## M5 — Teacher App (`TeacherShell`, `lib/features/teacher/`)

`TEACHER_API_ENABLED=true`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Teacher | Dashboard | `/teacher/dashboard` | teacher | `GET /teacher/dashboard` | LIVE ⚠ **CERT-002** |
| Teacher | Class-teacher dashboard | `/teacher/class-teacher-dashboard` | teacher (class teacher) | `GET /teacher/dashboard` | LIVE |
| Teacher | Take class attendance (draft + submit) | `/teacher/attendance` | teacher | `GET /teacher/attendance/classes`, `/students`, `POST /teacher/attendance/draft`, `/teacher/attendance/submit` | LIVE |
| Teacher | Own staff-attendance history | `/teacher/my-attendance` | teacher | `GET /staff-attendance/my-history` | LIVE |
| Teacher | Timetable | `/teacher/timetable` | teacher | `GET /teacher/timetable` | LIVE |
| Teacher | Homework list | `/teacher/homework` | teacher | `GET /teacher/homework` | LIVE |
| Teacher | Create homework (+ attachment) | `/teacher/homework/create` | teacher | `POST /teacher/homework`, `POST /teacher/homework/attachment/presign`, `GET /homework/attachment/download` | LIVE |
| Teacher | Homework history + bulk review | `/teacher/homework/history` | teacher | `GET /teacher/homework/history`, `POST /teacher/homework/bulk-review` | LIVE |
| Teacher | Exams: marks entry | `/teacher/exams` | teacher | `GET /teacher/exams/upcoming`, `GET/PUT /teacher/exams/marks`, `/teacher/exams/marks-entry` | LIVE |
| Teacher | Parent communication desk | `/teacher/parent-communication` | teacher | `GET /teacher/parent-communication`, `/concerns` | LIVE |
| Teacher | Student risk dossier | `/teacher/student-risk/:sisStudentId` | teacher | `GET /intelligence/risk/students` | LIVE (`INTELLIGENCE_API_ENABLED`) |
| Teacher | Leave request + balance | `/teacher/leave` | teacher | `GET /teacher/leave`, `/teacher/leave/balance` (pilot router `POST /teacher/leave`) | LIVE |
| Teacher | Messages / threads | `/teacher/messages`, `/teacher/messages/:threadId` | teacher | `GET /teacher/messages`, `/threads`, `POST /teacher/messages/send` | LIVE (owned by the communication router, not the teacher router — PRA-N-13) |
| Teacher | Settings | `/teacher/settings` | teacher | local | LIVE |
| Teacher | Profile | `/teacher/profile` | teacher | `GET /teacher/dashboard` | LIVE |
| Teacher | Lesson logs (daily capture) | `/teacher/lesson-logs` | teacher | `GET/POST /school/lesson-logs` | LIVE (`SCHOOL_COMPLETION_API_ENABLED`) |
| Teacher | Syllabus progress (coverage) | `/teacher/syllabus-progress` | teacher | `GET /school/academic/teacher-progress`, `POST /school/academic/complete-topic` | LIVE |
| Teacher | Notifications | `/teacher/notifications` | teacher | `/communications/*` | LIVE |

## M6 — Student App (`StudentShell`, `lib/features/student_app/`)

`STUDENT_API_ENABLED=true`. Student dashboard uses the **correct** honest fallback
(`StudentDashboardData.empty()`), which is the reference pattern CERT-001/002 should adopt.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Student | Dashboard | `/student/dashboard` | student | `GET /student/dashboard` | LIVE |
| Student | Attendance | `/student/attendance` | student | `GET /student/attendance` | LIVE |
| Student | Timetable | `/student/timetable` | student | `GET /student/timetable` | LIVE |
| Student | Homework + submission | `/student/homework` | student | `GET /student/homework`, `POST /student/homework/submit`, `/student/homework/attachment/presign` | LIVE |
| Student | Exams | `/student/exams` | student | `GET /student/exams` | LIVE |
| Student | Report card | `/student/report-card` | student | `GET /student/exams` | LIVE |
| Student | Progress | `/student/progress` | student | `GET /student/exams`, `/student/attendance` | LIVE |
| Student | Notices | `/student/notices` | student | `GET /student/notices` | LIVE |
| Student | Profile | `/student/profile` | student | `GET /student/profile` | LIVE |
| Student | Notifications inbox | **no student route** — every student screen's bell pushes `/parent/notifications` (`app_router.dart:2678`) | student | `GET /student/notifications`, `POST /student/notifications/mark-read`, `/mark-all-read` | **DEAD (client)** — the backend surface is complete and unreachable: `_canAccessRoute` bounces the student off the parent route back to `/student/dashboard`. **CERT-004** |
| Student | Push device registration | no route (background) | student | `POST /student/device-tokens/register` / `/unregister` | LIVE code path; no live push in dev (charter boundary) |

## M7 — Admin shell & hub (`lib/features/admin/`)

Everything below `AdminShell` requires `canAccessAdminErpShell` (`auth.role == UserRole.staff`)
**plus** the per-route permission in `kErpRouteViewPermissions` (longest-prefix match),
**plus** the school-capability check (`kErpRouteCapabilityModules`), **plus** the two
hide gates (`SchoolBuildScope`, `isBackendLessSurfaceHidden`).

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Admin | Admin hub (module tile grid) | `/admin` | all staff roles (`viewAdminHub`) | `GET /dashboard/overview` | LIVE |
| Admin | Global search overlay | no route — overlay in `AdminShell` | staff | `GET /search`, `/intelligence/quick-actions` | LIVE (`ADAPTIVE_AI_API_ENABLED`) |
| Admin | Copilot dock | no route — `CopilotDockHost` wraps every shell | all | `/copilot/*` | LIVE |
| Admin | Unified onboarding flow | `/admin/onboarding/unified` | superAdmin, schoolAdmin, principal, vicePrincipal, management (`viewOnboarding`) | `GET /onboarding/dashboard`, `/onboarding/imports`, `/onboarding/invites` | LIVE |
| Admin | Student bulk onboarding | `/admin/onboarding/students` | same | `POST /onboarding/imports/students/preview`, `/onboarding/students/generate` | LIVE |
| Admin | Backup & restore | `/admin/backup-restore` → `BackupRestoreScreen` | any staff role holding `viewAdminHub` (longest-prefix match resolves to `/admin`) | none for status; export actions only | **Partly informational** — the backup-status panel is a hard-coded static card (nightly / AES-256 / ~24h RPO), NOT a live read. The file states this explicitly and the UI says so in body copy, and DB restore is deliberately operator-assisted (`docs/BACKUP_RESTORE_RUNBOOK.md`). Honest by construction; the school-owned export actions are LIVE |
| Admin | Plan & entitlements (read) | `/admin/plan` → `PlanEntitlementsScreen` | staff with `viewAdminHub` | `GET /plans`, `GET /subscription` | LIVE (`ENTITLEMENT_API_ENABLED`) |
| Admin | Organization plan assignment | `/admin/plan/assign` → `OrganizationPlanAssignmentScreen` | **superAdmin only** — enforced in-screen by `canAssignOrganizationPlansProvider`, not by the route map | `GET/POST /platform/subscriptions`, `/platform/organizations` | LIVE |

## M8 — Admissions (`lib/features/admissions/`)

`ADMISSIONS_API_ENABLED=true` → `ApiAdmissionsRepository`. Route permission `viewAdmissions`.
Personas: superAdmin, schoolAdmin, principal, vicePrincipal, management, admissionsCounselor.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Admissions | Dashboard | `/admissions/dashboard` | as above | `GET /admissions/dashboard` | LIVE |
| Admissions | Leads list | `/admissions/leads` | as above | `GET /admissions/leads`, `POST /admissions/leads/bulk`, `/leads/check-duplicate` | LIVE |
| Admissions | Lead detail | `/admissions/leads/:leadId` | as above | `GET /admissions/leads` | LIVE |
| Admissions | Applications | `/admissions/applications` | as above | `GET /admissions/applications` | LIVE |
| Admissions | Enrollment | `/admissions/enrollment` | as above | `GET /admissions/enrollments`, `/enrollments/pending`, `/enrollment/prefill` | LIVE |
| Admissions | Documents (+ presigned upload) | `/admissions/documents` | as above | `GET /admissions/documents`, `POST /admissions/documents/upload`, `/upload/presign` | LIVE |
| Admissions | Approval queue | `/admissions/approval` | roles holding `approveAdmissions` | `GET /admissions/approval-queue`, `/approvals/*` | LIVE |
| Admissions | Fee handoff to Finance | `/admissions/fee-handoff` | as above | `GET /admissions/handoffs/approved`, `POST /admissions/handoffs/send`, `GET /admissions/fee-structures` | LIVE |
| Admissions | Reports | `/admissions/reports` | as above | `GET /admissions/reports` | LIVE |
| Admissions | Settings | `/admissions/settings` | as above | `GET/PUT /admissions/settings` | LIVE |
| Admissions | Admissions intelligence | embedded in dashboard | as above | `GET /admissions/intelligence`, `GET /predictions/admission-conversion` | LIVE |

## M9 — Finance (`lib/features/finance/`)

`FINANCE_API_ENABLED`, `PAYMENT_API_ENABLED`, `INVENTORY_FINANCE_API_ENABLED` all `true`.
`HybridFinanceRepository` (api + offline queue). Route permission `viewFinance`
(superAdmin, schoolAdmin, principal, vicePrincipal, management, financeAdmin).

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Finance | Dashboard | `/finance/dashboard` | viewFinance holders | `GET /finance/dashboard` | LIVE |
| Finance | Fee structures | `/finance/fee-structures` | viewFinance | `GET/POST /finance/fee-structures` | LIVE |
| Finance | Student accounts | `/finance/student-accounts` | viewFinance | `GET /finance/student-accounts`, `/finance/invoices` | LIVE |
| Finance | Fee assignment (single + bulk) | `/finance/fee-assignment` | manageFinance | `POST /finance/fee-assignment/assign`, `GET /finance/fee-assignments`, `POST /finance/fee-assignments/bulk` | LIVE |
| Finance | Collections | `/finance/collections` | viewFinance | `GET /finance/collections`, `/collections/daily-summary`, `/collections/cancelled` | LIVE |
| Finance | Collection detail | `/finance/collections/:collectionId` | viewFinance | `GET /finance/collections` | LIVE |
| Finance | QR payment | `/finance/payments/qr` | viewFinance | `POST /finance/payments/qr` | LIVE |
| Finance | Offline / cash payments | `/finance/payments/offline` | viewFinance | `POST /finance/payments/offline` | LIVE |
| Finance | Defaulters | `/finance/defaulters` | viewFinance | `GET /finance/defaulters`, `/analytics/head-wise-dues` | LIVE |
| Finance | Refunds (maker–checker) | `/finance/refunds` | approveRefunds | `GET/POST /finance/refunds`, `/approvals/*` | LIVE |
| Finance | Discounts / concessions | `/finance/discounts` | manageFinance + FIN-D4 maker–checker | `GET /finance/discounts`, `/finance/fee-reductions`, `/discount-applications`, `/scholarship-awards`, `/finance/scholarships` | LIVE |
| Finance | Reports (+ Tally export) | `/finance/reports` | viewFinance | `GET /finance/reports`, `/reports/tally-export`, `/finance/tally-ledger-map` | LIVE |
| Finance | Reconciliation & day close | `/finance/reconciliation` | viewFinance | `POST /finance/day-close`, `GET /finance/inventory-reconciliation/*` | LIVE |
| Finance | Settings | `/finance/settings` | manageFinance | `GET/PUT /finance/settings` | LIVE |
| Finance | Finance intelligence (copilot) | `/finance/intelligence` | `viewFinanceIntelligence` (superAdmin, schoolAdmin, financeAdmin) | `GET /finance/intelligence/copilot` | LIVE |
| Finance | Executive dashboard | `/finance/executive` | `viewFinanceExecutiveDashboard` (superAdmin, schoolAdmin, principal, vicePrincipal, financeAdmin) | `GET /finance/intelligence/executive` | LIVE |
| Finance | Late-fee accrual | no route — policy provider | manageFinance | `POST /finance/late-fees/accrue` | LIVE |
| Finance | Fee recovery / call queue | embedded in defaulters | viewFinance | `GET /finance/recovery/dashboard`, `/call-queue`, `/contacts`, `/promises`, `/targets` | LIVE |
| Finance | Razorpay gateway | no route — payment path | parent, financeAdmin | `POST /payments/intents/initiate`, `/confirm`, `POST /webhooks/razorpay` | UNKNOWN end-to-end — code path is live but no gateway credentials are provisioned (charter boundary); cannot be certified without a live key |

## M10 — SIS (`lib/features/sis/`, `lib/features/continuity/`)

`SIS_API_ENABLED=true` → `HybridSisRepository`. Route permission `viewSis`
(superAdmin, schoolAdmin, principal, vicePrincipal, management, admissionsCounselor).
Three SIS sub-routes are **hidden in the release build** by `surface_backend_gate.dart`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| SIS | Dashboard | `/sis/dashboard` | viewSis | `GET /sis/dashboard` | LIVE |
| SIS | Student list | `/sis/students` | viewSis | `GET /sis/students` | LIVE |
| SIS | Student profile (+ clearance/no-dues dialogs) | `/sis/students/:studentId` | viewSis | `GET /sis/students`, `GET/POST /sis/clearance/waivers` | LIVE |
| SIS | Academic assignment | `/sis/academic-assignment` | manageSis | `POST /sis/academic-assignment` | LIVE |
| SIS | Admissions → SIS conversion | `/sis/admissions-conversion` | manageSis | `POST /sis/admissions-conversion`, `GET /sis/enrollments` | LIVE |
| SIS | Year transition / promotion wizard | `/sis/promotion` | manageSis | `POST /sis/promotion`, `GET /academic/transitions/preview`, `/mapping-suggestions` | **HIDDEN** — `ACADEMIC_OPERATIONS_API_ENABLED` absent from `live_release.json`, so `surface_backend_gate.dart` hides the route and drops the nav entry in a live build. Backend exists |
| SIS | Section reshuffle | `/sis/reshuffle` | manageSis | `POST /sis/reshuffle` (backend exists) | **HIDDEN** — `advancedAcademicOperationsEnabledProvider` is hard-coded `=> false`; no dart-define can turn it on |
| SIS | Section balance | `/sis/section-balance` | manageSis | `GET /sis/section-balance` (backend exists) | **HIDDEN** — same hard-coded flag |
| SIS | Continuity (student continuity) | `/sis/continuity` | manageSis | continuity endpoints | **HIDDEN** — `CONTINUITY_API_ENABLED` absent from `live_release.json` |
| SIS | Transfers / exit log (TC) | `/sis/transfers` | manageSis | `GET/POST /sis/transfers` | LIVE |
| SIS | Onboarding hub | `/sis/onboarding` | viewOnboarding | `GET /onboarding/dashboard` | LIVE |
| SIS | Student 360 dossier | `/student-360/:studentId` | `viewStudent360` (superAdmin, schoolAdmin, principal, vicePrincipal, management, teacher) | `GET /sis/students`, `/intelligence/risk/students` | LIVE |

## M11 — HR & Payroll (`lib/features/hr/`, `lib/features/employee/`, `lib/features/staff_attendance/`)

`HR_API_ENABLED=true` → `HybridHrRepository`. Route permission `viewHr`
(superAdmin, schoolAdmin, principal, vicePrincipal, management). Entitlement-gated
server-side on `module.hr_payroll`; capability-gated client-side on `AdminModule.hr`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| HR | Dashboard | `/hr/dashboard` | viewHr | `GET /hr/dashboard` | LIVE |
| HR | Employees list | `/hr/employees` | viewHr | `GET /hr/employees`, `GET /hr/employees/export` | LIVE |
| HR | Employee detail | `/hr/employees/:employeeId` | viewHr | `GET /hr/employees` | LIVE |
| HR | Staff attendance (muster) | `/hr/attendance` | viewHr | `GET /hr/attendance`, `/hr/attendance/muster`, `/staff-attendance/*` | LIVE |
| HR | Manual-attendance request (staff) | `/hr/attendance/manual-request` | staff (`markStaffAttendance`) | `POST /staff-attendance/manual-request` | LIVE |
| HR | Manual-request approver queue | `/hr/attendance/requests` | manageHr | `GET /staff-attendance/manual-requests`, `POST /staff-attendance/manual-request/decide` | LIVE |
| HR | Geofence + anti-mock check-in | no route (device layer) | all staff | `POST /staff-attendance/check`, `GET /staff-attendance/geofence` | LIVE |
| HR | Leave requests + batch decide | `/hr/leave` | viewHr / manageHr | `GET /hr/leave`, `/hr/leave/balances`, `POST /hr/leave/batch-decide` | LIVE |
| HR | **Leave accrual engine** | **no route, no UI, no Dart caller** | — | `POST /hr/leave/accrual/run`, `GET /hr/leave/accrual/balances` (`hr/leave_accrual.ts`, `leave_accrual_handlers.ts`, tested) | **DEAD (client)** — verified: no `accrual` reference anywhere in `lib/` HR code, and `hr_api_paths.dart:38` binds only the plain `/hr/leave/balances`, never `/hr/leave/accrual/balances`. Backend shipped + tested but orphaned from the app |
| HR | Payroll runs + payslips | `/hr/payroll` | manageHr | `GET /hr/payroll`, `/payroll/register`, `/payroll/payslips`, `POST /hr/payroll/run`, `/run/generate`, `GET /hr/payroll/structures` | LIVE |
| HR | Statutory payroll (PT/PF/ESI) | inside `/hr/payroll` | manageHr | `GET/PUT /hr/payroll/statutory`, `/statutory/config`, `/statutory/pt-slabs` | LIVE |
| HR | Recruitment | `/hr/recruitment` | manageHr | `GET/POST /hr/recruitment` | LIVE |
| HR | Performance | `/hr/performance` | manageHr | `GET /hr/performance` | LIVE |
| HR | Reports | `/hr/reports` | viewHr | `GET /hr/dashboard`, `/hr/reports/headcount` | LIVE ⚠ the report **catalog** is always `HrReportsData.mock().catalog` and the headline falls back to a mock string — see CERT-006 |
| HR | Settings | `/hr/settings` | manageHr | `GET/PUT /hr/settings` | LIVE |
| HR | Document expiry / probation alerts | embedded | viewHr | `GET /hr/documents/expiring`, `/hr/probation/ending` | LIVE |
| HR | Staff duties (invigilation, substitution) | embedded | manageHr | `/hr/staff-duties`, `/invigilations`, `/non-teaching`, `/rollup`, `/substitutions` | LIVE |
| HR | Staff 360 dossier | `/staff-360/:employeeId` | `viewHr` | `GET /hr/employees`, `/hr/leave` | LIVE |
| Employee | Employee platform | `/employees` | `viewEmployees` (superAdmin, schoolAdmin, principal, vicePrincipal, management, teacher) | `GET /employees`, `/employees/dashboard` | LIVE (`EMPLOYEE_API_ENABLED`) |
| Employee | Employee 360 intelligence | `/employees/360/:employeeId` | `viewEmployeeIntelligence` | `GET /employees/intelligence/dashboard` | LIVE (`PHASE5_API_ENABLED`) |

## M12 — Management (`lib/features/management/`, `lib/features/workflow/`)

`MANAGEMENT_API_ENABLED=true`, `APPROVAL_API_ENABLED=true`, `ATTENDANCE_API_ENABLED=true`.
Route permission `viewManagement`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Management | Dashboard | `/management/dashboard` | viewManagement | `GET /management/dashboard` | LIVE |
| Management | Analytics | `/management/analytics` | viewManagement | `GET /management/analytics`, `/analytics/dashboard`, `/trends` | LIVE |
| Management | Admissions view | `/management/admissions` | viewManagement | `GET /management/admissions-funnel` | LIVE |
| Management | Finance view | `/management/finance` | viewManagement | `GET /management/financial-health` | LIVE |
| Management | Academics view | `/management/academics` | viewManagement | `GET /management/academic-health` | LIVE |
| Management | Timetable view | `/management/timetable` | `viewAcademicTimetable` (explicit override in `erpRoutePermissionFor`) | `GET /academic/timetables/summary` | LIVE (`ACADEMIC_TIMETABLE_API_ENABLED`) |
| Management | Intelligence | `/management/intelligence` | `viewAnalytics` (explicit override) | `GET /analytics/recommendations`, `/risks`, `/principal-summary`, `/weekly-briefing` | LIVE (`ANALYTICS_INTELLIGENCE_API_ENABLED`) |
| Management | School performance | `/management/performance` | viewManagement | `GET /management/school-performance` | LIVE |
| Management | Tasks | `/management/tasks` | viewManagement | `GET/POST /management/tasks` | LIVE |
| Management | Approval centre | `/management/approvals` | viewManagement + approve perms | `GET /approvals/pending`, `/approvals/entity`, `POST /approvals/batch-decide`, `GET /approvals/audit` | LIVE |
| Management | Attendance corrections | `/management/attendance-corrections` | viewManagement | `GET /attendance/corrections`, `/attendance/pending` | LIVE |
| Management | Office attendance | `/management/office-attendance` | viewManagement | `GET /attendance/register`, `/register/monthly`, `/attendance/sessions` | LIVE |
| Management | **Workflow automation** | `/management/workflow-automation` | viewManagement | none live | **HIDDEN** — `WORKFLOW_API_ENABLED` absent from `live_release.json`; `surface_backend_gate.dart` hides the route and drops the nav tile. `workflowRepositoryProvider` would resolve `MockWorkflowRepository` |
| Management | Settings | `/management/settings` | manageManagement | `GET/PUT /management/settings` | LIVE |
| Management | School calendar (holidays/events) | `/management/school-calendar` | `viewSchoolCalendar` | `GET/POST /school-calendar` | LIVE |
| Management | Attendance alerts | embedded | viewManagement | `GET /attendance/alerts/consecutive-absence`, `/alerts/short-attendance` | LIVE |

## M13 — Transport (`lib/features/transport/`)

`TRANSPORT_API_ENABLED=true` → `HybridTransportRepository`. Permission `viewTransport`
(superAdmin, schoolAdmin, principal, vicePrincipal, management, transportManager).
Entitlement `module.transport`; capability `AdminModule.transport`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Transport | Dashboard | `/transport/dashboard` | viewTransport | `GET /transport` | LIVE |
| Transport | Routes | `/transport/routes` | manageTransport | `GET/POST /transport/routes` | LIVE |
| Transport | Vehicles | `/transport/vehicles` | manageTransport | `GET/POST /transport/vehicles` | LIVE |
| Transport | Drivers | `/transport/drivers` | manageTransport | `GET/POST /transport/drivers` | LIVE |
| Transport | Student allocation (+ bulk) | `/transport/allocation` | manageTransport | `GET/POST /transport/allocations`, `/allocations/bulk` | LIVE |
| Transport | Transport attendance | `/transport/attendance` | manageTransport | `GET/POST /transport/attendance`, `/attendance/generate` | LIVE |
| Transport | Live tracking | `/transport/tracking` | viewTransport | `POST /transport/notify-delay` | LIVE (no GPS device layer — TRN GPS was scoped to Phase 2) |
| Transport | Reports | `/transport/reports` | viewTransport | `GET /transport/expenses` | LIVE |
| Transport | Settings | `/transport/settings` | manageTransport | `GET /transport` | LIVE |
| Transport | Fee demand → Finance (TRN-9) | inside allocation | manageTransport | `GET/POST /transport/demands`, `/demands/bulk` | LIVE |
| Transport | Document-expiry reminders | background | manageTransport | `POST /transport/reminders/document-expiry` | LIVE |

## M14 — Hostel (`lib/features/hostel/`)

`HOSTEL_API_ENABLED=true`. Permission `viewHostel`. Ships as **"residence-lite"** —
owner decision CODE-7 removed leave and visitors from V1.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Hostel | Dashboard | `/hostel/dashboard` | viewHostel | `GET /hostel/dashboard`, `/hostel/occupancy-metrics` | LIVE |
| Hostel | Residents | `/hostel/students` | viewHostel | `GET /hostel/students` | LIVE |
| Hostel | Rooms | `/hostel/rooms` | manageHostel | `GET/POST /hostel/rooms` | LIVE |
| Hostel | Hostel attendance | `/hostel/attendance` | manageHostel | `GET/POST /hostel/attendance` | LIVE |
| Hostel | Mess | `/hostel/mess` | manageHostel | `GET /hostel/mess` | LIVE |
| Hostel | Reports | `/hostel/reports` | viewHostel | `GET /hostel/reports` | LIVE |
| Hostel | Hostel leave | `/hostel/leave` | manageHostel | `GET /hostel/leave` (backend exists) | **HIDDEN** — `RouteNames.hostelLeave` is in `SchoolBuildScope.hiddenRoutePrefixes` (owner CODE-7, deferred) |
| Hostel | Visitors / gate register | `/hostel/visitors` | manageHostel | `GET /hostel/visitors` (backend exists) | **HIDDEN** — same owner decision |

## M15 — Library (`lib/features/library/`)

`LIBRARY_API_ENABLED=true`. Permission `viewLibrary`. Entitlement `module.library`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Library | Dashboard | `/library/dashboard` | viewLibrary | `GET /library/dashboard` | LIVE |
| Library | Catalog (+ import) | `/library/catalog` | manageLibrary | `GET/POST /library/catalog`, `POST /library/catalog/import`, `/library/accessions` | LIVE |
| Library | Issue a book | `/library/issues` | manageLibrary | `GET/POST /library/issues` | LIVE |
| Library | Returns | `/library/returns` | manageLibrary | `POST /library/returns` | LIVE |
| Library | Members | `/library/members` | manageLibrary | `GET /library/members` | LIVE |
| Library | Fines | `/library/fines` | manageLibrary | `GET/POST /library/fines` | LIVE |
| Library | Digital resources | `/library/resources` | viewLibrary | `GET /library/digital-resources` | LIVE |
| Library | Reports | `/library/reports` | viewLibrary | `GET /library/reports` | LIVE |
| Library | Overdue loans (LIB-1) | `/library/overdue` | viewLibrary | `GET /library/overdue`, `POST /library/reminders/overdue` | LIVE |
| Library | Settings | `/library/settings` | manageLibrary | `GET/PUT /library/settings` | LIVE |

## M16 — Inventory & Procurement (`lib/features/inventory/`)

`INVENTORY_API_ENABLED`, `INVENTORY_FINANCE_API_ENABLED`, `INVENTORY_DISTRIBUTION_API_ENABLED`
all `true`. Permission `viewInventory`. Entitlement `module.inventory`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Inventory | Dashboard | `/inventory/dashboard` | viewInventory | `GET /inventory` | LIVE |
| Inventory | Assets | `/inventory/assets` | manageInventory | `GET/POST /inventory/assets` | LIVE |
| Inventory | Categories | `/inventory/categories` | manageInventory | `GET/POST /inventory/categories` | LIVE |
| Inventory | Allocation | `/inventory/allocation` | manageInventory | `GET/POST /inventory/allocations` | LIVE |
| Inventory | Maintenance | `/inventory/maintenance` | manageInventory | `GET/POST /inventory/maintenance` | LIVE |
| Inventory | Procurement (orders + GRN) | `/inventory/procurement` | manageInventory | `GET/POST /inventory/procurement/orders`, `/procurement/grns` | LIVE |
| Inventory | Vendors | `/inventory/vendors` | manageInventory | `GET /inventory/vendors/catalog` | LIVE |
| Inventory | Stock register & valuation | `/inventory/stock` | viewInventory | `GET /inventory/stock/items`, `/register`, `/valuation`, `/low-stock`, `POST /inventory/stock/issue`, `/count` | LIVE |
| Inventory | Stock adjustments (maker–checker) | `/inventory/stock-approvals` | viewInventory + approver | `POST /inventory/stock/adjust`, `GET /inventory/stock/adjustments`, `/stock/approvals` | LIVE |
| Inventory | Reports | `/inventory/reports` | viewInventory | `GET /inventory` | LIVE |
| Inventory | Inventory copilot | `/inventory/copilot` | `viewInventoryIntelligence` | `GET /inventory/intelligence/copilot` | LIVE |
| Inventory | Asset lifecycle | `/inventory/lifecycle` | `viewInventoryIntelligence` | `GET /inventory/intelligence/lifecycle`, `/lifecycle/events` | LIVE |
| Inventory | Distribution (uniform/books issue) | `/inventory/distribution` | `viewInventoryDistribution` | `GET /inventory/distribution`, `/catalog`, `/dashboard`, `/items`, `/reports` | LIVE |
| Inventory | Replacements | `/inventory/replacements` | `viewInventoryDistribution` | `GET/POST /inventory/distribution/replacements` | LIVE |
| Inventory | Finance reconciliation | inside `/finance/reconciliation` | viewFinance | `GET /finance/inventory-reconciliation/dashboard`, `/goods-receipts`, `/postings`, `/timeline` | LIVE |

## M17 — Academics: exams, timetable, syllabus, subjects (`lib/features/academics/`, `lib/features/school_completion/`)

`EXAM_API_ENABLED`, `ACADEMIC_API_ENABLED`, `ACADEMIC_TIMETABLE_API_ENABLED`,
`SCHOOL_COMPLETION_API_ENABLED` all `true`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Exams | Exam administration hub | `/school/exam-administration` | `viewExams` (superAdmin, schoolAdmin, principal, vicePrincipal, teacher) | `GET /academics/exams` | LIVE |
| Exams | Marks entry | `/school/exam-administration/:examId/marks` | viewExams | `GET/PUT /teacher/exams/marks`, `/teacher/exams/marks-entry` | LIVE |
| Exams | Exam reports (tabulation, merit, distribution, datesheet) | `/school/exam-administration/reports` | viewExams | `GET /academics/exams/progress`, `/intelligence/exam/analytics` | LIVE |
| Exams | Grade scale (FA/SA, State-Board SSC) | inside exam admin | manageExams | `GET/PUT /academics/exams/grade-scale` | LIVE |
| Exams | Seating plan | inside exam admin | manageExams | `POST /academics/exams/:id/seating/generate`, `GET .../seating` | LIVE |
| Exams | Marks-entry reminder | inside exam admin | manageExams | `POST /academics/exams/marks/remind` | LIVE |
| Exams | Exam timetable generation | inside exam admin | manageExams | `POST /school/exam-timetable/generate` | LIVE |
| Academics | Subjects management | `/school/subjects` | `viewSubjects` | `GET/POST /school/subjects`, `/academic/subjects` | LIVE |
| Academics | Subject assignments | `/school/subject-assignments` | `viewSubjectAssignments` | `GET/POST /school/teacher-subject-assignments`, `/school/class-subject-assignments`, `/school/subject-workload` | LIVE |
| Academics | School completion hub | `/school/completion` | `viewSubjects` | `GET /school/*` | LIVE |
| Academics | Lesson logs | `/school/lesson-logs` | `viewLessonLogs` | `GET/POST /school/lesson-logs` | LIVE |
| Academics | Lesson analytics | `/school/lesson-analytics` | `viewLessonAnalytics` | `GET /school/lesson-analytics/principal`, `/teacher` | LIVE |
| Academics | Academic progress (syllabus coverage) | `/school/academic/progress` | `viewAcademicProgress` | `GET /school/academic/principal-progress`, `/teacher-progress`, `POST /complete-topic` | LIVE |
| Academics | Syllabus automation | `/school/syllabus/automation` | `manageSyllabus` | `GET/POST /school/syllabus/templates`, `/chapters`, `/topics`, `/clone`, `/generate` | LIVE |
| Timetable | Timetable automation | `/school/timetables/automate` | `manageTimetableAutomation` | `POST /school/timetables/automate`, `POST /academic/timetables/generate`, `/validate`, `GET /conflicts` | LIVE |
| Timetable | Timetable optimization | `/school/timetables/optimize` | `viewTimetableOptimization` | `GET /school/timetables/optimize`, `POST /optimize/apply` | LIVE |
| Timetable | Substitute manager | `/school/timetables/substitute` | `manageAcademicTimetable` | `GET /school/timetables/substitute/coverage`, `POST /substitute/assign`, `GET /academic/timetables/substitutions/candidates` | LIVE |
| Timetable | Teacher reassignment | `/school/timetables/reassign` | `manageAcademicTimetable` | `GET /school/timetables/reassign/options`, `POST /reassign`, `POST /academic/timetables/periods/reassign-teacher` | LIVE |
| Timetable | Class-teacher assignments | `/school/timetables/class-teachers` | `manageAcademicTimetable` | `GET/POST /academic/teacher-assignments` | LIVE |
| Timetable | Timetable intelligence | `/school/timetables/intelligence` | `manageAcademicRooms` | `GET /school/timetables/intelligence`, `/academic/timetables/workload`, `/workload/rollup` | LIVE |
| Timetable | Room allocation | `/school/rooms-allocation` | `manageAcademicRooms` | `GET /school/rooms`, `POST /school/rooms/allocate` | LIVE |
| Academics | Academic years / classes / sections | inside school-completion + SIS | manageSis | `GET/POST /academic/years`, `/academic/classes`, `/academic/sections`, `/academic/class-subjects` | LIVE |

## M18 — Communication (`lib/features/communication/`)

`COMMUNICATION_API_ENABLED=true` → `HybridCommunicationRepository`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Communication | Delivery console | `/school/communications/delivery` | `viewCommunicationDelivery` | `GET /communications/delivery/metrics`, `/school/communications/delivery-analytics` | LIVE |
| Communication | Broadcast admin | `/school/communications/broadcast-admin` | `manageCommunication` | `GET/POST /communications/broadcasts`, `/broadcasts/history`, `/broadcasts/{id}/report`, `/{id}/resend`, `/broadcasts/run-scheduled`, `GET/POST /communications/audience-segments`, `/communications/templates` | LIVE |
| Communication | Communication analytics | `/school/communications/analytics` | `viewCommunicationAnalytics` | `GET /communications/analytics/summary`, `/parent-adoption`, `/school/communications/analytics/*` | LIVE |
| Communication | WhatsApp provider config | `/school/whatsapp-provider` | `viewWhatsAppProvider` | `GET/PUT /school/whatsapp-provider`, `POST /school/whatsapp-provider/test` | LIVE (provider credentials owner-gated) |
| Communication | Channel policy | inside broadcast admin | manageCommunication | `GET/PUT /communications/channel-policy` | LIVE |
| Communication | Notification queue processing | background | system | `POST /communications/notifications/process-queue`, `/notifications/{id}/acknowledge` | LIVE |
| Communication | Delivery-status webhook | none (public route) | provider | `POST /communications/delivery/webhook` (HMAC-authed, in `PUBLIC_MODULE_ROUTE_PREFIXES`) | LIVE |
| Communication | SMS provider (DLT-compliant) | none | system | `sms_provider.ts` | LIVE code path; **no live SMS in dev** (charter boundary) |
| Communication | Templated send | inside broadcast admin | manageCommunication | `POST /school/communications/send-template` | LIVE |

## M19 — Intelligence & AI (`lib/features/intelligence/`, `lib/features/copilot/`, `lib/features/adaptive_ai/`, `lib/features/predictions/`)

`INTELLIGENCE_API_ENABLED`, `AI_COPILOT_ENABLED`, `ADAPTIVE_AI_API_ENABLED`,
`PREDICTIONS_API_ENABLED`, `ANALYTICS_INTELLIGENCE_API_ENABLED` all `true`.
Every AI surface is **read-only** — no AI on a write path.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Intelligence | Student-risk hub | `/intelligence` | `viewStudentRisk` | `GET /intelligence/risk/students`, `/risk/classes`, `POST /risk/students/compute` | LIVE |
| Intelligence | AI predictions | `/intelligence/predictions` | `viewStudentRisk` (prefix `/intelligence`) | `GET /predictions/student-risk`, `/fee-default`, `/admission-conversion` | LIVE — entitlement `feature.ai_predictions` |
| Intelligence | Student-success intelligence | `/intelligence/student-success` | `viewStudentSuccessIntelligence` | `GET /intelligence/student-success/dashboard`, `/predictions`, `/interventions`, `/improvements`, `POST /compute` | LIVE |
| Intelligence | Exam intelligence | `/intelligence/exam` | `viewExamIntelligence` | `GET /intelligence/exam/analytics`, `/forecast`, `/rank-movement`, `/result-intelligence`, `/subject-performance`, `/weak-chapters` | LIVE |
| Intelligence | Teacher effectiveness | `/intelligence/teacher-effectiveness` | `viewTeacherEffectiveness` | `GET /intelligence/teacher-effectiveness/performance`, `/lesson-scores`, `/topic-mastery`, `/planning-center`, `/parent-meeting-summary` | LIVE |
| Intelligence | Homework intelligence | `/homework-intelligence` | `viewHomeworkIntelligence` | `GET /intelligence/homework-intelligence/plan`, `POST /generate` | LIVE ⚠ deep-link only (no nav entry) |
| Intelligence | AI content generation | `/ai-content` | `runAiCopilot` | `POST /intelligence/communication/generate`, `/parent-guidance/generate` | LIVE ⚠ deep-link only (no nav entry) |
| Copilot | Copilot hub | `/copilot` | `viewAiCopilot` | `GET /copilot/assistants`, `/sessions`, `/suggestions`, `/economics` | LIVE |
| Copilot | Copilot dock (all shells) | no route — `CopilotDockHost` | all | `/copilot/*` | LIVE |
| Adaptive AI | Priority feed / recommendations | embedded in 5 dashboards (parent, teacher, student, director, management) | all | `GET /intelligence/priorities`, `/recommendations`, `POST /recommendations/feedback` | LIVE |
| Adaptive AI | Quick actions | embedded | staff | `GET /intelligence/quick-actions` | LIVE |
| Adaptive AI | Universal search | global search overlay | staff | `GET /search` | LIVE (fail-soft to empty) |
| Intelligence | Principal command centre | `/principal-command` | `viewPrincipalCommand` | `GET /principal-command/center`, `POST /principal-command/query`, `GET /intelligence/principal/center`, `POST /intelligence/principal/query` | **HIDDEN** — `RouteNames.principalCommand` is in `SchoolBuildScope.hiddenRoutePrefixes` |
| Intelligence | Teacher assistant | `/teacher-assistant` | `viewTeacherAssistant` | `GET /teacher-assistant/insights`, `/interventions` | **HIDDEN** — in `SchoolBuildScope.hiddenRoutePrefixes` |
| Intelligence | Daily brief (backend) | no route | staff | `GET /intelligence/briefs/daily`, `POST /briefs/prewarm` | LIVE (backend); the Flutter **composer** for it is DEAD — see M28 |
| Intelligence | AI wallet / economics | no dedicated route | `viewAiWallet` | `GET /ai-wallet`, `POST /ai-wallet/grant`, `GET /intelligence/ai-economics` | LIVE |
| Intelligence | Trust intelligence | `/organization/intelligence` | `viewOrganizationIntelligence` | `GET /intelligence/trust` | **HIDDEN** — `PLATFORM_INTELLIGENCE_API_ENABLED` absent; `surface_backend_gate.dart` hides it (CFC-1 fix: it rendered `MockPlatformIntelligenceRepository`'s fabricated cross-school dashboard) |

## M20 — Education Suite / QIE (`lib/features/education/`)

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Education | Question Papers (QIE generation) | `/education` (tab) | `viewEducation` | `GET/POST /education/question-papers`, `/question-papers/generate` | **HIDDEN** — owner decision V1-SCOPE-1 (2026-07-28). `RouteNames.education` is in `SchoolBuildScope.hiddenRoutePrefixes`; `educationRouteBuilder` returns `AccessDeniedScreen`. Restored in V2 by deleting one line |
| Education | Question Bank (+ import/export) | `/education` (tab) | `viewEducation` | `GET/POST /education/question-bank`, `/import`, `/export` | **HIDDEN** — same gate; the certified bank is empty (Program D blocker) |
| Education | Homework (education tab) | `/education` (tab) | `viewEducation` | `GET/POST /education/homework`, `/homework/generate` | **HIDDEN** at this route — but the same capability is LIVE at `/teacher/homework`, `/parent/homework`, `/student/homework`, so nothing is lost |
| Education | Report remarks | `/education` (tab) | `viewEducation` | `GET/POST /education/report-remarks`, `/generate` | **HIDDEN** at this route — reachable through the exam/report-card flow |
| Education | Learning evidence | no route | teacher | `POST /education/evidence/responses` | UNKNOWN — backend exists; no Flutter caller found for this path. Needs a Dart API-path grep to confirm DEAD vs. used under another constant |

## M21 — PRC-A staff desks (`lib/features/certificate_desk/`, `gate_pass/`, `complaints/`, `student_health/`)

Reachable from the Admin Hub tile grid. **Critical RBAC note:** the four gating
permissions (`requestStudentCertificate`, `requestGatePass`, `raiseComplaint`,
`viewStudentHealthRecord`) are held by **no `ErpRole` in the client-side
`RolePermissionMatrix`** — they are seeded server-side only. Resolution therefore
depends on the server snapshot / JWT claims (`rbac_service.dart:49-90`); in the
local-matrix fallback path nobody reaches these desks.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Certificate desk | Certificate requests (raise + track) | `/certificate-requests` | server-granted `requestStudentCertificate` | `GET/POST /certificate-requests` | LIVE ⚠ client-matrix fallback grants it to nobody |
| Certificate desk | Approve a certificate request | Approval Centre (`/management/approvals`) | `approveCertificateRequest` (server-seeded) | `/approvals/*` | LIVE |
| Gate pass | Gate passes (student release) | `/gate-passes` | server-granted `requestGatePass` | `GET/POST /gate-passes` | LIVE ⚠ same |
| Complaints | Complaints desk | `/complaints` | server-granted `raiseComplaint` | `GET/POST /complaints` | LIVE ⚠ same |
| Student health | Infirmary console | `/student-health` | server-granted `viewStudentHealthRecord` (healthStaff, principal, vicePrincipal per migration `20260887000000`) | `GET/POST /student-health/incidents`, `/care-alerts`, `/authorizations`, `/access-log` | LIVE ⚠ same |
| Student health | Care alert for teachers | embedded widget | `viewStudentCareAlert` | `GET /student-health/care-alerts` | ⚠ `lib/features/student_health/care_alert/care_alert_widget.dart` is **orphaned** — not imported anywhere in `lib/`. DEAD unless wired |
| Clearance | No-dues / TC clearance report | dialog from `/sis/students/:id` | `viewSis` | `GET/POST /sis/clearance/waivers` | LIVE |

## M22 — Alumni (`lib/features/alumni/`)

`ALUMNI_API_ENABLED=true` (real backend), but the **entire module is hidden in V1** by
owner decision CODE-8: `AdminModule.alumni` is in `hiddenAdminModules` and
`RouteNames.alumni` is in `hiddenRoutePrefixes`, so the tile is dropped and every
`/alumni/*` route is blocked. Un-hiding restores a live surface, not a mock.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Alumni | Dashboard | `/alumni/dashboard` | `viewAlumni` | `GET /alumni/dashboard` | HIDDEN |
| Alumni | Registry | `/alumni/registry` | viewAlumni | `GET /alumni/registry` | HIDDEN |
| Alumni | Alumnus profile | `/alumni/profile/:alumniId` | viewAlumni | `GET /alumni/registry` | HIDDEN |
| Alumni | Events | `/alumni/events` | manageAlumni | `GET/POST /alumni/events` | HIDDEN |
| Alumni | Donations | `/alumni/donations` | manageAlumni | `GET/POST /alumni/donations` | HIDDEN |
| Alumni | Campaigns | `/alumni/campaigns` | manageAlumni | `GET/POST /alumni/campaigns` | HIDDEN |
| Alumni | Mentorship | `/alumni/mentorship` | manageAlumni | `GET /alumni/mentorship` | HIDDEN |
| Alumni | Reports | `/alumni/reports` | viewAlumni | `GET /alumni/reports` | HIDDEN |
| Alumni | Settings | `/alumni/settings` | manageAlumni | `GET/PUT /alumni/settings` | HIDDEN |

## M23 — Control Center (`lib/features/platform/control_center/`)

`CONTROL_CENTER_API_ENABLED=true`. Route permission `viewControlCenter` — held by
**superAdmin only**, and `RbacModuleRegistry.canAccessControlCenter` additionally
requires `role == ErpRole.superAdmin`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Control Center | Dashboard | `/control-center/dashboard` | superAdmin | `GET /control-center/dashboard` | LIVE |
| Control Center | Schools | `/control-center/schools` | superAdmin | `GET /control-center/schools` | LIVE |
| Control Center | Subscriptions | `/control-center/subscriptions` | superAdmin | `GET /control-center/subscriptions` | LIVE |
| Control Center | Billing | `/control-center/billing` | superAdmin | `GET /control-center/billing` | LIVE |
| Control Center | CRM pipeline | `/control-center/crm` | superAdmin | `GET /control-center/crm-pipeline` | LIVE |
| Control Center | Support tickets (ASIP triage) | `/control-center/support` | superAdmin | `GET /control-center/support-tickets` | LIVE |
| Control Center | Customer success | `/control-center/success` | superAdmin | `GET /control-center/customer-success` | LIVE |
| Control Center | Analytics | `/control-center/analytics` | superAdmin | `GET /control-center/analytics`, `/usage` | LIVE |
| Control Center | Monitoring | `/control-center/monitoring` | superAdmin | `GET /control-center/monitoring` | LIVE |
| Control Center | Roles | `/control-center/roles` | superAdmin | `GET /control-center/roles`, `/identity/roles` | LIVE |
| Control Center | Settings | `/control-center/settings` | superAdmin | `GET/PUT /control-center/settings` | LIVE |
| Control Center | Providers + secret vault | `/control-center/providers` | superAdmin | `GET /control-center/providers`, `/vault/health`, `POST /vault/rotate`, `/vault/reencrypt` | LIVE |
| Control Center | Feature flags | `/control-center/features` | superAdmin | `GET/PUT /control-center/features` | LIVE |
| Control Center | Platform intelligence | `/control-center/intelligence` | superAdmin | — | **HIDDEN** — `PLATFORM_INTELLIGENCE_API_ENABLED` absent; hidden rather than served from `MockPlatformIntelligenceRepository` |
| Control Center | White-label admin | `/control-center/white-label` | superAdmin | `GET /control-center/white-label` | **HIDDEN** — `WHITE_LABEL_PLATFORM_API_ENABLED` absent |

## M24 — Director portal (`lib/features/director/`)

`DIRECTOR_API_ENABLED=true` → `HybridDirectorRepository`. Permission `viewDirectorPortal`
(superAdmin, schoolAdmin, principal, vicePrincipal, management). Entitlement `module.multi_branch`.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Director | Dashboard | `/director/dashboard` | viewDirectorPortal | `GET /director/dashboard`, `/director/summary` | LIVE |
| Director | Schools list | `/director/schools` | viewDirectorPortal | `GET /director/schools` | LIVE |
| Director | Per-school snapshot (DIR-D1) | `/director/schools/:id` | viewDirectorPortal | `GET /director/schools` | LIVE |
| Director | Portfolio | `/director/portfolio` | viewDirectorPortal | `GET /director/portfolio` | LIVE |
| Director | Revenue | `/director/revenue` | viewDirectorPortal | `GET /director/revenue`, `/director/collections` | LIVE |
| Director | Growth | `/director/growth` | viewDirectorPortal | `GET /director/growth` | LIVE |
| Director | Marketing | `/director/marketing` | viewDirectorPortal | `GET /director/marketing` | LIVE |
| Director | Admissions | `/director/admissions` | viewDirectorPortal | `GET /director/admissions` | LIVE |
| Director | Compliance | `/director/compliance` | viewDirectorPortal | `GET /director/compliance` | LIVE |
| Director | Reports | `/director/reports` | viewDirectorPortal | `GET /director/reports` | LIVE |
| Director | Manual metric inputs | inside dashboard | manageDirectorPortal | `GET/POST /director/metric-inputs` | LIVE |

## M25 — Multi-school, chains, organization builder, entitlements, school config

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Organization builder | Hub | `/organization-builder` | `viewOrganizationBuilder` (superAdmin, schoolAdmin, management) | `GET /platform/org-builder`, `/packs` | LIVE — additionally chain-gated (`ChainScope`) + Enterprise-entitlement-gated, so a single-school pilot never sees it |
| Organization builder | AI interview | `/organization-builder/interview` | viewOrganizationBuilder | `GET/POST /platform/org-builder/interview/drafts` | LIVE |
| Organization builder | Preview | `/organization-builder/preview` | viewOrganizationBuilder | `POST /platform/org-builder/preview` | LIVE |
| Organization builder | Provisioning | `/organization-builder/provisioning` | viewOrganizationBuilder | `POST /platform/org-builder/provision`, `GET /platform/provisioning-jobs` | LIVE |
| School config | Smart school discovery wizard | `/school-config/discovery` | `viewSchoolSetup` | `GET/PUT /school-config` | LIVE (`SCHOOL_CONFIG_API_ENABLED`) |
| Entitlements | Plan catalog + resolved subscription | `/admin/plan` | staff (`viewAdminHub`) | `GET /plans`, `GET /subscription` | LIVE |
| Entitlements | Org plan assignment | `/admin/plan/assign` | superAdmin (in-screen guard) | `GET/POST /platform/subscriptions`, `/platform/organizations` | LIVE |
| Multi-school | Portfolio | `/multi-school/portfolio` | `viewMultiSchoolOperations` (schoolAdmin, management) | — | **HIDDEN** — `MULTI_SCHOOL_OPERATIONS_API_ENABLED` absent from `live_release.json`; `surface_backend_gate.dart` blocks the whole `/multi-school` prefix. Repo would resolve `MockMultiSchoolOperationsRepository` |
| Multi-school | Onboarding | `/multi-school/onboarding` | viewMultiSchoolOperations | — | **HIDDEN** — same gate |
| Branch ops | Branch dashboard | `/branches` | `viewBranchOperations` (schoolAdmin, principal, vicePrincipal, management) | — | **HIDDEN** — `branchRepositoryProvider` is an **unconditional `MockBranchRepository`** (no API branch at all); hidden by *both* `BRANCH_API_ENABLED` and `BRANCH_OPERATIONS_API_ENABLED` gates plus `ChainScope`. RT-5-3 fix: it rendered a fabricated multi-branch revenue dashboard |
| Franchise ops | Franchise dashboard | `/franchise` | `viewFranchiseOperations` | — | **HIDDEN** — unconditional `MockFranchiseRepository`; same double gate |
| Platform ops | Platform operations hub + 4 tabs | `/platform-operations`, `/alerts`, `/security`, `/tenant-isolation`, `/readiness` | `viewPlatformOperations` — **held by no `ErpRole`** | — | **HIDDEN** — `PLATFORM_OPERATIONS_API_ENABLED` absent (`MockPlatformOperationsRepository`) *and* `RouteNames.platformOperations` is in `SchoolBuildScope.hiddenRoutePrefixes`. The 4 sub-routes are also deep-link-only (the hub renders them as in-page tabs) |

## M26 — Non-school verticals & white label (`lib/features/verticals/`, `lib/features/industry/`, `lib/features/platform/white_label/`)

All hidden twice over: `SchoolBuildScope.hiddenRoutePrefixes` **and**
`surface_backend_gate.dart` (their `*_API_ENABLED` flags are absent from
`live_release.json`, so their repositories are `Mock*`). Permissions are `superAdmin`-only.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Industry | Industry framework hub | `/industry`, `/industry/framework` | `viewIndustryFramework` (superAdmin) | none | HIDDEN (`SchoolBuildScope` only — note there is **no** surface-gate flag for `/industry`) |
| Healthcare | Dashboard / patients / appointments / practitioners / intelligence | `/healthcare*` (5 routes) | `viewHealthcare` (superAdmin) | none | HIDDEN (both gates) |
| Salon | Dashboard / customers / appointments / services / intelligence | `/salon*` (5 routes) | `viewSalonBusiness` (superAdmin) | none | HIDDEN (both gates) |
| Restaurant | Dashboard / tables / orders / kitchen / intelligence | `/restaurant*` (5 routes) | `viewRestaurantHospitality` (superAdmin) | none | HIDDEN (both gates) |
| Accommodation | Dashboard / residents / occupancy / allocations / intelligence | `/accommodation*` (5 routes) | `viewAccommodation` (superAdmin) | none | HIDDEN (both gates) |
| White label | Hub / branding / theme / logo / deployment | `/white-label*` (5 routes) | `viewWhiteLabelPlatform` — **held by no `ErpRole`** | none | HIDDEN (both gates) |

## M27 — Evolution, Phase 4/5 platform extras, growth

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| Growth | Marketing / growth platform | `/growth` | `viewGrowthPlatform` (superAdmin, schoolAdmin, principal, vicePrincipal) | `GET /growth/dashboard`, `/campaigns`, `/campaigns/history`, `/funnel`, `/inquiries` | LIVE — entitlement `module.marketing`; reachable from the Marketing tile |
| Operations | Operations hub | `/operations/hub` | `viewOperationsHub` | `GET /operations/hub`, `/operations/actions` | LIVE (`PHASE5_API_ENABLED`) |
| Achievement | Achievement promotion / posters | `/promotions` | `viewAchievementPromotion` | `GET /promotions`, `/promotions/brand-profile`, `POST /promotions/poster/preview` | LIVE (`PHASE5_API_ENABLED`) |
| Branding | School branding | `/school/branding` | `viewSchoolBranding` | `GET/PUT /school/branding` | LIVE |
| Pilot | Pilot dashboard | `/school/pilot` | `viewPilotDashboard` | `GET /school/pilot/dashboard` | LIVE |
| Pilot | Parent activation dashboard | `/school/parent-activation` | `viewPilotDashboard` | `GET /school/parent-activation/dashboard`, `/parent/experience/activation` | LIVE |
| Onboarding | Startup onboarding (+ AI prefill, go-live) | `/sis/onboarding`, `/admin/onboarding/*` | `viewOnboarding` | `GET /onboarding/startup`, `POST /onboarding/startup/ai-prefill`, `/startup/go-live` | LIVE — AI prefill entitlement-gated on `feature.ai_school_builder` |
| Social | Social account connect | no route | superAdmin | `GET /social/connections`, `POST /social/connect/start`, `/complete` | UNKNOWN — backend exists; no registered route. Likely embedded in `/promotions`; needs a widget trace |
| Memories | School memories | `/memories` | `viewSchoolMemories` | `GET /memories`, `/memories/events`, `/memories/analytics` | **HIDDEN** — in `SchoolBuildScope.hiddenRoutePrefixes` |
| Setup | Setup wizard (demo) | `/setup-wizard` | `viewSchoolSetup` | `GET/POST /setup-wizard`, `/setup-wizard/sessions` | **HIDDEN** — in `hiddenRoutePrefixes` ("demo wizard; real onboarding is separate") |
| Resource | Resource optimization | `/resource-optimization` | `viewOperationsHub` or `manageManagement` | — | **HIDDEN** twice — `hiddenRoutePrefixes` **and** `RESOURCE_OPTIMIZATION_API_ENABLED` absent (mock-only) |
| Dynamic widgets | Registry / layout / runtime | `/dynamic-widgets`, `/dynamic-widgets/layout`, `/dynamic-widgets/runtime` | `viewDynamicWidgets` | `GET /widgets/registry`, `/widgets/data`, `/data-sources`, `/dashboard/layout`, `/layouts/versions`, `POST /widgets/data/refresh` | **HIDDEN** — `AdminModule.dynamicWidgets` + all three route prefixes in `SchoolBuildScope`. Backend is complete |
| Dynamic dashboard | Dynamic dashboard | `/dashboard/dynamic` | `viewDynamicWidgets` | `GET /dashboard/overview` | **HIDDEN** — in `hiddenRoutePrefixes` |
| Parent meetings | PTM scheduling (staff) | `/parent-meetings` | `viewAcademicProgress` | `GET /parent/meetings` | **HIDDEN** — in `hiddenRoutePrefixes`; UI built, no backend write path (CORE-1/PAR-4) |

## M28 — DEAD code (shipped, no reachable entry point)

Each verified by tracing callers, not by reading a doc.

| Module | Feature | Screen/route | Persona(s) | Backend endpoint(s) | Status |
|---|---|---|---|---|---|
| DAI | Morning Brief composer | none — `lib/core/dai/dai_brief.dart` | — | `GET /intelligence/briefs/daily` (backend live, called by nothing) | **DEAD** — `DaiBriefComposer` (`dai_brief.dart:136`) has zero production call sites; imported only by `test/core/dai/dai_brief_test.dart`. The file's own header says `STATUS: NOT WIRED` and lists 4 blocking gaps. Its siblings `dai_resolver.dart` / `dai_intent.dart` are NOT dead (used by the global search overlay). Shipped replacement = `AdaptivePriorityFeedSection` |
| HR | Leave accrual engine | none | — | `POST /hr/leave/accrual/run`, `GET /hr/leave/accrual/balances` | **DEAD (client)** — backend built + tested (`hr/leave_accrual.ts`, `leave_accrual_handlers.ts`, `leave_accrual_test.ts`); zero Dart callers, and `hr_api_paths.dart:38` binds only the plain `/hr/leave/balances`. The only "accrual" in `lib/` is the unrelated finance late-fee accrual |
| Router | 9 superseded module route builders | none | — | — | **DEAD** — `admissionsRouteBuilder`, `alumniRouteBuilder`, `controlCenterRouteBuilder`, `financeRouteBuilder`, `hostelRouteBuilder`, `hrRouteBuilder`, `inventoryRouteBuilder`, `libraryRouteBuilder`, `transportRouteBuilder` in `lib/router/admin_navigation.dart`, plus `_controlCenterScreen` in `control_center_navigation.dart`. Superseded by the per-module nav files; referenced from neither `lib/` nor `test/` |
| Security | Mutation permission registry | none | — | — | **DEAD** — `lib/core/security/mutation_permission_registry.dart` not imported anywhere in `lib/` |
| Security | Server RBAC route inventory | none | — | — | **DEAD** — `lib/core/security/server_rbac_route_inventory.dart` not imported in `lib/` |
| Security | Phase-5 staging route manifest | none | — | — | **DEAD** — `lib/core/security/phase5_staging_route_manifest.dart` not imported in `lib/` |
| Security | Permission refresh service | none | — | — | **DEAD** — `lib/core/security/permission_refresh_service.dart` not imported in `lib/` (note: `permission_sync_service.dart` IS used) |
| Core | Pagination wiring layer | none | — | — | **DEAD** — `lib/core/providers/pagination_wiring.dart`, `paginated_list_providers.dart`, `provider_select_extensions.dart`, `lib/core/repositories/pagination_endpoint_registry.dart`: the whole layer is orphaned |
| Core | OpenAPI contract registry + response validator | none | — | — | **DEAD** — `lib/core/network/openapi/openapi_contract_registry.dart`, `openapi_response_validator.dart` |
| Core | Observability bootstrap / health / metrics registry | none | — | — | **DEAD** — `lib/core/observability/observability_bootstrap.dart`, `observability_health.dart`, `operational_metrics_registry.dart` (note `incident_route_observer.dart` IS used by the support flow) |
| Core | Performance cache + rebuild registry | none | — | — | **DEAD** — `lib/core/performance/repository_cache.dart`, `provider_rebuild_registry.dart` |
| Core | Repository error handler, client monitor, tenant propagation registry | none | — | — | **DEAD** — `lib/core/errors/repository_error_handler.dart`, `lib/core/monitoring/client_monitor.dart`, `lib/core/tenant/tenant_api_propagation_registry.dart` |
| Verticals | 4 vertical mutation providers | none | — | — | **DEAD** — `lib/features/verticals/{restaurant,salon,healthcare,accommodation}/*_mutations_provider.dart`, all orphaned (their surfaces are hidden anyway) |
| SIS | Admissions-conversion provider | none | — | — | **DEAD** — `lib/features/sis/admissions_conversion/sis_admissions_conversion_provider.dart` orphaned (the routed screen does not import it) |
| Student health | Care-alert widget | none | — | `GET /student-health/care-alerts` | **DEAD** — `lib/features/student_health/care_alert/care_alert_widget.dart` not imported anywhere; the teacher-facing care alert has no rendering site |
| UI | 6 orphaned widgets | none | — | — | **DEAD** — `admin/screens/admin_module_placeholder_screen.dart`, `teacher/attendance/widgets/student_attendance_row.dart`, `student_app/dashboard/widgets/hero_greeting_card.dart`, `teacher/dashboard/widgets/greeting_header.dart`, `parent/dashboard/widgets/hero_card.dart`, `parent/profile/parent_language_provider.dart` |
| Theme | Legacy design system | none | — | — | **DEAD** — `lib/theme/m15_design_system.dart` (superseded by Akshara Design System V2) |
| DTOs | 3 orphaned request/response DTOs | none | — | — | **DEAD** — `api/sis/dto/academic_assignment_request_dto.dart`, `api/workflow/dto/workflow_response_dto.dart`, `api/finance/dto/create_student_account_request_dto.dart` |
| Student | Notifications inbox | none (bell points at `/parent/notifications`) | student | `/student/notifications*` | **DEAD (client)** — see **CERT-004** |

---

# 1. Roles the system defines, and which modules each reaches

The client enumerates **15** `ErpRole` values (`lib/core/security/erp_role.dart`), on top
of **4** `UserRole` shell personas (`parent`, `teacher`, `student`, `staff`). A **16th**
role, `healthStaff`, exists **server-side only** (migration
`supabase/migrations/20260887000000_student_health.sql:43`) and has **no entry in the
Dart `ErpRole` enum** — a `healthStaff` user's `claims.erpRoles` will therefore be empty
client-side. Permissions still resolve (the production path prefers the server permission
snapshot, `rbac_service.dart:73-80`), but anything keyed on the *role* rather than the
permission — `RoleGuard`, `RbacModuleRegistry.canAccessControlCenter`,
`homeRouteForStaffErp` — cannot see it.

Module reach below = the `view*` permissions each role holds in
`RolePermissionMatrix._permissionsForRole`, mapped through `kErpRouteViewPermissions`.
Hidden modules are excluded from "reaches" where the hide gate blocks them regardless.

| Role | Perms | Modules reached (V1, after the hide gates) |
|---|---|---|
| **superAdmin** | 138 | Everything not hidden: Admin hub, Admissions, Finance (+intelligence, +executive), SIS, Student 360, Management (+calendar), Transport, HR, Staff 360, Hostel, Library, Inventory (+distribution, +intelligence), **Control Center** (sole holder), Director, Copilot, Intelligence (all 5 sub-surfaces), Employees, Employee 360, Operations hub, Achievement promotion, Growth, School completion, Subjects, Exams, Lesson logs/analytics, Timetable (all 6 surfaces), Communications (all 3), Pilot, Room allocation, Syllabus, Organization builder, School discovery, AI wallet, Storage quota, Parent experience/insights. Also holds the vertical + industry permissions, but every vertical is hidden |
| **schoolAdmin** | 124 | As superAdmin **minus** Control Center, Healthcare/Salon/Restaurant/Accommodation/Industry; **plus** Multi-school ops and Branch/Franchise ops (all four of those are hidden in V1) |
| **principal** | 105 | Admin hub, Admissions, Finance (+executive), SIS, Student 360, Management, Transport, HR, Staff 360, Hostel, Library, Inventory (+distribution, +intelligence), Alumni (hidden), Director, Copilot, all Intelligence surfaces, Employees, Employee 360, Operations hub, Growth, School completion, Subjects, Exams, Lesson logs/analytics, all Timetable surfaces, all Communications, Pilot, School branding, WhatsApp provider, School calendar, School setup, Parent insights. No Control Center, no Organization builder |
| **vicePrincipal** | 105 | Identical permission set to principal |
| **management** | 58 | Admin hub, Admissions, Finance, SIS, Student 360, Management, Transport, HR, Hostel, Library, Inventory (+distribution), Alumni (hidden), Director, Copilot, Employees, Operations hub, Organization builder, Achievement promotion, School memories (hidden), Exam/Homework/Student-risk intelligence, Multi-school (hidden), Branch/Franchise (hidden), AI wallet, Storage quota. **No** exams, timetable, communications, lesson logs, subjects, school setup |
| **financeAdmin** | 12 | Admin hub, Finance (+intelligence, +executive), Copilot. Nothing else |
| **admissionsCounselor** | 6 | Admin hub, Admissions, SIS, Copilot |
| **transportManager** | 3 | Admin hub, Transport |
| **hostelManager** | 3 | Admin hub, Hostel |
| **librarian** | 3 | Admin hub, Library |
| **inventoryManager** | 10 | Admin hub, Inventory, Inventory distribution, Inventory intelligence |
| **storekeeper** | 3 | Admin hub, Inventory |
| **teacher** | 31 | **No `viewAdminHub`** → cannot enter the admin ERP shell at all. Reaches the Teacher shell (18 routes) plus, by permission, Student 360, Exams, Subjects, Subject assignments, Lesson logs, Lesson analytics, Academic progress, Education (hidden), Teacher assistant (hidden), Achievement promotion, Employees, and the 4 intelligence read surfaces — but only where a teacher-owned route exists (`/teacher/lesson-logs`, `/teacher/syllabus-progress` were added precisely because the admin-shell equivalents bounce a teacher) |
| **parent** | 6 | Parent shell only (24 routes). Permissions: `viewAttendance`, `viewParentAcademicSummary`, `viewParentExperience`, `viewParentInsights`, `markStaffAttendance` is *not* granted (parent is in `_nonStaffRoles`) |
| **student** | 0 default | **No entry in `_permissionsForRole` at all** — the student's permission set is empty in the local matrix; access is purely shell-persona ownership (`isPersonaOwnedRoute`) over the 9 `/student/*` routes |
| *healthStaff* (server-only) | server-seeded | `/student-health` console, `manageStudentHealth`, `administerStudentMedication`. **Not representable client-side** — no `ErpRole` value |

**Permissions held by no client role** (server-seeded only, so the local-matrix fallback
grants them to nobody): `requestStudentCertificate`, `approveCertificateRequest`,
`requestGatePass`, `raiseComplaint`, `viewStudentHealthRecord`, `manageStudentHealth`,
`administerStudentMedication`, `viewStudentCareAlert`, `viewSupport`,
`viewPlatformOperations`, `viewWhiteLabelPlatform`.

# 2. Directories in `lib/features/` with NO route pointing at them

`lib/features/` has **53** top-level directories (not 54 — `student_360` and `student_app`
are distinct). Method: every `features/<dir>/` import across all 43 files in `lib/router/`
was mapped, then each `*RouteBuilder` symbol was checked for an actual reference from
`app_router.dart`.

**Exactly 4 directories have zero router references. None of them is dead** — all four are
shared widget/provider/model layers with no screen files at all, embedded inside routed screens.

| Directory | Representative file | Reached how |
|---|---|---|
| `adaptive_ai` | `widgets/adaptive_priority_feed.dart` (`AdaptivePriorityFeedSection`) | Embedded in 5 routed dashboards — `student_app/dashboard/student_dashboard_screen.dart:148`, `director/director_dashboard_screen.dart:97`, `management/widgets/management_principal_overview_panel.dart:81`, `parent/dashboard/parent_dashboard_screen.dart:117`, `teacher/dashboard/teacher_dashboard_screen.dart:168`. `adaptive_search_results.dart` is used by `admin/global_search/global_search_overlay.dart:175` |
| `clearance` | `widgets/clearance_report_dialog.dart` | Opened as a dialog from the routed SIS profile — `sis/profile/sis_profile_screen.dart:147` (`ClearanceReportDialog.show`) and `:161` (`ClearanceWaiverQueueDialog.show`) |
| `phase4` | `phase4_providers.dart` (providers only, no widgets) | Consumed by 5 routed screens: `student_360/student_360_screen.dart:10`, `intelligence/homework/homework_intelligence_screen.dart:9`, `inventory/distribution/inventory_distribution_screen.dart:12`, `employee/employee_platform_screen.dart:8` |
| `phase5` | `phase5_providers.dart`, `phase5_models.dart` | Consumed by `management/approval/approval_center_provider.dart` and the repository layer (`core/repositories/api/phase5/*`, `interfaces/phase5_repositories.dart`). Its *screens* live in `achievement_promotion` / `memories` / `operations` / `resource_optimization`, routed via `lib/router/phase5_navigation.dart` |

The other 49 directories all have at least one registered route. Non-obvious indirections
verified: `verticals` (4 nav files), `platform` (7 nav files), `continuity` (via
`sis_navigation.dart`), `workflow` (via `management_navigation.dart`), `communication`
(via `school_completion_navigation.dart`), and `employee` / `student_360` / `memories` /
`operations` / `resource_optimization` / `achievement_promotion` (via `phase4_navigation.dart`
and `phase5_navigation.dart`).

> Note: "has a route" ≠ "reachable in the V1 release". `verticals`, `industry`,
> `dynamic_widgets`, `memories`, `resource_optimization`, `alumni`, `parent_meetings`,
> `education` and the `platform` sub-trees all have routes that the two hide gates block
> in the shipping build (see M20, M22, M25, M26, M27).

# 3. Routes with no UI entry point (deep-link only)

A route counts as having an entry point if some widget calls `go`/`push` to it, or it
appears in a rendered nav/tile registry (`kAllAdminNavDestinations` in
`lib/features/admin/admin_navigation_provider.dart:17-270`, the side rail, the bottom nav,
or a module sub-nav).

### 3a. Hard orphans — nothing in `lib/` navigates to them

| Route | Evidence |
|---|---|
| **`/support`** | Referenced only at `app_router.dart:301` (registration) and `route_guards.dart:66` (permission map). No "Report an issue" / "Help & Support" affordance anywhere. **The RC-phase finding is still open** — see **CERT-005** |
| **`/support/new`** | Pushed only from `support/my_reported_issues_screen.dart:50,77` — i.e. from `/support`, itself unreachable. Second-order orphan |
| **`/support/:id`** | Pushed only from `my_reported_issues_screen.dart:155` and `report_issue_screen.dart:192`, both inside the unreachable cluster |
| `/admin/backup-restore` | Zero references outside `app_router.dart:602`. Not in the hub tiles, not in Management → Settings |
| `/ai-content` | Only `app_router.dart:699` + `route_guards.dart:84` |
| `/homework-intelligence` | Only `app_router.dart:652` + `route_guards.dart:74` |
| `/platform-operations/alerts` | Only `app_router.dart:931` + guard `:140`. The hub renders Alerts as an in-page `TabBar` tab (`platform_operations_hub_screen.dart:76`), never as a route |
| `/platform-operations/security` | Same pattern — `app_router.dart:936`, guard `:141`, tab at `:77` |
| `/platform-operations/tenant-isolation` | Same — `app_router.dart:941`, guard `:142`, tab at `:78` |
| `/platform-operations/readiness` | Same — `app_router.dart:946`, guard `:144`, tab at `:80` |
| `/management/attendance-corrections` | Zero references in `lib/`. Absent from the `ManagementScreen` sub-nav map (`management/management_navigation.dart:20-28`). The screen only links *out* to approvals / office-attendance |
| `/education` | Only its registration + self-redirect (`education_navigation.dart:34`) — consistent with being hidden |
| `/branches`, `/franchise`, `/multi-school/portfolio` | Appear only in `ChainScope.chainOnlyRoutePrefixes` (`core/config/chain_scope.dart:26-28`), which is a *hide* list, not a nav registry. `/multi-school/onboarding` is a second-order orphan off the portfolio screen |
| `/memories`, `/resource-optimization`, `/dashboard/dynamic`, `/teacher-assistant`, `/parent-meetings` | Appear only in `SchoolBuildScope.hiddenRoutePrefixes` (`school_build_scope.dart:72-82`) |

Of these, only **`/support`** (+ its two children) and **`/admin/backup-restore`**,
**`/ai-content`**, **`/homework-intelligence`**, **`/management/attendance-corrections`**
and the four **platform-operations tabs** are *live/reachable-if-you-know-the-URL*
surfaces. The rest are orphaned *because* they are deliberately hidden, which is coherent.

### 3b. Redirect-only aliases (expected, not defects)

`/`, `/splash`, `/parent`, `/teacher`, `/student`, and the module roots `/admissions`,
`/finance`, `/hr`, `/sis`, `/hostel`, `/library`, `/inventory`, `/management`,
`/transport`, `/control-center`, `/alumni` — each exists only to redirect to its
module dashboard.

### 3c. Weak / data-dependent entry points (reachable, but nothing static points at them)

| Route | Only path in |
|---|---|
| `/staff-360/:employeeId` | `openStaff360` (`router/staff360_navigation.dart:16`) has **zero callers**; reachable only by searching a staff member in the global search overlay (`adaptive_ai/adaptive_ai_providers.dart:112` → `admin/global_search/global_search_overlay.dart:65`), gated on `viewHr` |
| `/management/timetable` | Only via the AI deep-link mapper (`management/management_adaptive_action_routing.dart:19`) — requires a server recommendation whose `deepLink` starts `/timetable` |
| `/principal-command` | Only via `copilot/copilot_quick_action_routing.dart:39` → `copilot_ai_quick_actions.dart:120` (and it is hidden anyway) |
| `/inventory/distribution` → `/inventory/replacements` | Distribution is not in the Inventory sub-nav enum; reachable only from the Operations Hub tile (`operations/operations_hub_navigation.dart:10`); replacements only from distribution |
| `/qa-login` | Build-flag gated (`qaLoginEnabled`) — `auth/splash_screen.dart:65`, `auth_logout.dart:43` |

### 3d. Confirmed to HAVE entry points (checked, not assumed)

`/sync-center` (SyncBanner, `app/app.dart:136`) · `/settings/appearance` and
`/settings/ai-assistant` (parent/teacher/student profile + management settings) ·
`/ai-assistant` (copilot dock + persona dispatchers) · `/staff-attendance/face-enrollment`
(`hr/attendance/hr_attendance_screen.dart:72`) and `/staff-attendance/face-capture`
(`staff_attendance/face_enrollment_screen.dart:74`) · `/legal-acceptance` (parent/teacher
profile) · `/admin/plan` (`entitlement_module_gate.dart:120`, `plan_badge.dart:46`) ·
`/admin/plan/assign` (`plan_entitlements_screen.dart:77`) · `/admin/onboarding/unified`
(`management_settings_screen.dart:156`) · `/admin/onboarding/students`
(`unified_onboarding_flow_screen.dart:366`) · `/employees/360/:employeeId`
(`employee_platform_screen.dart:52`) · `/student-360/:studentId` (SIS registry/profile,
teacher dashboards, student-success) · `/intelligence/teacher-effectiveness`
(`management_insight_navigation.dart:18`) · `/library/overdue`
(`library_dashboard_screen.dart:89`) · `/hr/attendance/manual-request` and
`/hr/attendance/requests` (`staff_attendance/widgets/staff_check_in_card.dart:89,98`) ·
`/school/exam-administration/reports` (`academics/exam_admin/exam_admin_navigation.dart:25`) ·
`/teacher/my-attendance`, `/teacher/class-teacher-dashboard`, `/teacher/homework/history`,
`/teacher/notifications`, `/parent/notifications`.

### 3e. Admin Hub tile grid (the staff entry surface)

`kAllAdminNavDestinations` (`admin/admin_navigation_provider.dart:17-270`), filtered by
`workspaceScopedNavDestinationsProvider`, rendered by `admin_hub_screen.dart:90-95`.
Tile-reachable == side-rail-reachable == bottom-nav-reachable:

`/admissions/dashboard`, `/growth`, `/finance/dashboard`, `/sis/dashboard`,
`/school/exam-administration`, `/certificate-requests`, `/gate-passes`, `/complaints`,
`/student-health`, `/school/completion`, `/hr/dashboard`, `/employees`,
`/management/dashboard`, `/transport/dashboard`, `/hostel/dashboard`,
`/library/dashboard`, `/inventory/dashboard`, `/alumni/dashboard`,
`/control-center/dashboard`, `/director/dashboard`, `/organization-builder`,
`/platform-operations`, `/industry`, `/healthcare`, `/salon`, `/restaurant`,
`/accommodation`, `/white-label`, `/dynamic-widgets`.

Of those, `SchoolBuildScope` suppresses **9** at runtime in a school build
(`/alumni/dashboard`, `/white-label`, `/platform-operations`, `/industry`, `/healthcare`,
`/salon`, `/restaurant`, `/accommodation`, `/dynamic-widgets`), leaving **20** tiles.

---

# Counts

Counted mechanically from the tables above (one row = one feature). Rows that appear in
both their functional module and the DEAD roster (M28) are counted once.

| | Count |
|---|---|
| **Modules** | **28** (M1–M28) |
| **Features (table rows, de-duplicated)** | **350** |

| Status | Count | Share |
|---|---|---|
| **LIVE** | **283** | 80.9 % |
| **HIDDEN** | **44** | 12.6 % |
| **DEAD** | **19** | 5.4 % |
| **UNKNOWN** | **4** | 1.1 % |
| **MOCK** | **0** | 0 % |

Per-module row counts: M1 10 · M2 8 · M3 4 · M4 26 · M5 18 · M6 11 · M7 8 · M8 11 ·
M9 19 · M10 12 · M11 20 · M12 16 · M13 11 · M14 8 · M15 10 · M16 15 · M17 22 · M18 9 ·
M19 17 · M20 5 · M21 7 · M22 9 · M23 15 · M24 11 · M25 12 · M26 6 · M27 14 · M28 19.

## What the MOCK = 0 result actually means — read this before trusting it

**No reachable surface in the shipping release build is served wholesale by a mock
repository.** That is a real and deliberate architectural result, not luck: the project
chose to **hide** backend-less surfaces rather than serve them from a mock
(`lib/router/surface_backend_gate.dart`, owner decision 2026-07-04 "hide all for pilot",
plus the CFC-1 Trust-Hub and RT-5-3 Branch/Franchise fixes). Every module whose
`*_API_ENABLED` flag is absent from `config/live_release.json` — 18 of them — is
therefore HIDDEN, not MOCK. The one module that *was* silently mocked in a release build
(Support) was found and fixed in the RC phase by adding `SUPPORT_API_ENABLED`.

**But "MOCK = 0" is not the same as "no fabricated data reaches users."** This inventory
found a second, more dangerous variant the module-flag ledger cannot see: **per-screen
mock fallbacks inside otherwise-LIVE surfaces.** Five screens substitute a hard-coded
demo dataset whenever the live call fails or returns nothing, and their "error state"
branches are wired to `StateProvider<bool>` flags that **only the test suite ever sets** —
so the green error-state tests assert a premise the production path cannot reach:

| Screen | Fallback shown as real | Defect |
|---|---|---|
| `/parent/fees` | ₹23,000 annual fee, ₹4,200 pending, 4 fake "Paid" payments | **CERT-001 (P0)** |
| `/parent/dashboard` | `ParentDashboardData.mock()` | CERT-002 (P1) |
| `/parent/homework` | `ParentHomeworkData.mock()` | CERT-002 (P1) |
| `/teacher/dashboard` | `TeacherDashboardData.mock()` | CERT-002 (P1) |
| `/hr/reports` | `'142 active staff · 96.2% attendance MTD'` | CERT-006 (P1) |

`studentDashboardProvider` (`student_dashboard_provider.dart:274-285`) already uses the
correct honest fallback (`StudentDashboardData.empty()`), so the fix pattern exists
in-tree.

## The 4 UNKNOWNs and exactly what would settle each

| Feature | Why UNKNOWN | What is needed to decide |
|---|---|---|
| Parent fee payment / Razorpay gateway (M4, M9) | The client and server code paths are complete and wired (`/payments/intents/initiate`, `/confirm`, `POST /webhooks/razorpay`) but **no gateway credentials are provisioned** — the charter records Razorpay as stubbed | A live Razorpay key + one sandbox transaction end-to-end (owner/infra gate) |
| Parent fee certificate (M4) | `GET /parent/fee-certificate` exists in `parent_router.ts` but no registered Flutter route was found | A widget trace for an in-screen "download fee certificate" affordance inside `/parent/fees` or `/parent/receipts`; if none, reclassify DEAD |
| Learning evidence (M20) | `POST /education/evidence/responses` exists (`education/learning_evidence_router.ts`) with no Flutter caller found | A grep of the Dart API-path constants for this endpoint under a different name; if absent, reclassify DEAD |
| Social account connect (M27) | `/social/connections`, `/social/connect/start`, `/connect/complete` exist with no registered route | Trace whether the Achievement-Promotion screen embeds a social-connect affordance; if not, reclassify DEAD |

## Verification boundaries carried into this inventory

- **Static analysis only.** Everything above is traced from source. No release binary was
  run (`guardForRelease` requires production + a live API), no live DB was introspected
  (SSH is owner-bound), no live Postgres lane exists in this harness.
- Consequently **"LIVE" here means "reachable in a production build and bound to a real
  API implementation and a registered backend prefix"** — not "verified working against
  the pilot database". Migration-apply state on the live DB is unverified throughout
  (explicitly so for Support, per the note in `config/live_release.json`).
- Server-seeded permissions could not be read from the live DB, so every row whose
  persona depends on a server-only permission (M21, `/support` triage) is marked with
  that dependency rather than asserted.

## Defects raised by this workstream

`CERT-001` (P0) · `CERT-002` (P1) · `CERT-003` (P1) · `CERT-004` (P1) · `CERT-005` (P1) ·
`CERT-006` (P1) — all recorded in `docs/certification/DEFECT_REGISTER.md`. Nothing was fixed.
