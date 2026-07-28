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
| Admin | Backup & restore | `/admin/backup-restore` | staff (no permission entry → `erpRoutePermissionFor` returns `null` → **allowed for any staff**) | backup/restore ops endpoints | LIVE ⚠ no explicit permission mapped — see CERT-005 |
| Admin | Plan & entitlements | `/admin/plan` | staff (no permission entry) | `GET /plans`, `GET /subscription` | LIVE (`ENTITLEMENT_API_ENABLED`) ⚠ CERT-005 |
| Admin | Organization plan assignment | `/admin/plan/assign` | staff (no permission entry) | `GET/POST /platform/subscriptions`, `/platform/organizations` | LIVE ⚠ CERT-005 |

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

