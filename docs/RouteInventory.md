# Akshara ERP — Route Inventory

**Generated:** v0.5.1 stabilization  
**Source:** `lib/router/route_names.dart`, `lib/router/app_router.dart`  
**Verification:** `test/router_smoke_test.dart` (staff ERP paths), per-module widget tests

---

## Auth Routes

| Path | Screen | Module | Auth Role | Shell |
|------|--------|--------|-----------|-------|
| `/` | Redirect → splash | Auth | Any | None |
| `/splash` | SplashScreen | Auth | Any | None |
| `/login` | LoginScreen | Auth | Any | None |
| `/otp` | OtpVerificationScreen | Auth | Any | None |

---

## Parent Mobile (`ParentShell`)

| Path | Screen | Auth Role | Shell |
|------|--------|-----------|-------|
| `/parent` | Redirect → dashboard | Parent | ParentShell |
| `/parent/dashboard` | ParentDashboardScreen | Parent | ParentShell |
| `/parent/attendance` | ParentAttendanceScreen | Parent | ParentShell |
| `/parent/timetable` | ParentTimetableScreen | Parent | ParentShell |
| `/parent/homework` | ParentHomeworkScreen | Parent | ParentShell |
| `/parent/exams` | ParentExamsScreen | Parent | ParentShell |
| `/parent/notices` | ParentNoticesScreen | Parent | ParentShell |
| `/parent/events` | ParentEventsScreen | Parent | ParentShell |
| `/parent/profile` | ParentProfileScreen | Parent | ParentShell |
| `/parent/fees` | ParentFeesScreen | Parent | ParentShell |
| `/parent/payment` | ParentPaymentScreen | Parent | ParentShell |
| `/parent/receipts` | ParentReceiptsScreen | Parent | ParentShell |
| `/parent/receipts/:receiptId` | ParentReceiptDetailScreen | Parent | ParentShell |
| `/parent/leave` | ParentLeaveScreen | Parent | ParentShell |
| `/parent/notifications` | NotificationsScreen | Parent | None (full screen) |

---

## Teacher Mobile (`TeacherShell`)

| Path | Screen | Auth Role | Shell |
|------|--------|-----------|-------|
| `/teacher` | Redirect → dashboard | Teacher / Staff | TeacherShell |
| `/teacher/dashboard` | TeacherDashboardScreen | Teacher / Staff | TeacherShell |
| `/teacher/attendance` | TeacherAttendanceScreen | Teacher / Staff | TeacherShell |
| `/teacher/timetable` | TeacherTimetableScreen | Teacher / Staff | TeacherShell |
| `/teacher/homework` | TeacherHomeworkScreen | Teacher / Staff | TeacherShell |
| `/teacher/exams` | TeacherExamsScreen | Teacher / Staff | TeacherShell |
| `/teacher/messages` | TeacherMessagesScreen | Teacher / Staff | TeacherShell |
| `/teacher/messages/:threadId` | TeacherConversationScreen | Teacher / Staff | TeacherShell |
| `/teacher/leave` | TeacherLeaveScreen | Teacher / Staff | TeacherShell |

---

## Student Mobile (`StudentShell`)

| Path | Screen | Auth Role | Shell |
|------|--------|-----------|-------|
| `/student` | Redirect → dashboard | Student | StudentShell |
| `/student/dashboard` | StudentDashboardScreen | Student | StudentShell |
| `/student/attendance` | StudentAttendanceScreen | Student | StudentShell |
| `/student/timetable` | StudentTimetableScreen | Student | StudentShell |
| `/student/homework` | StudentHomeworkScreen | Student | StudentShell |
| `/student/exams` | StudentExamsScreen | Student | StudentShell |
| `/student/notices` | StudentNoticesScreen | Student | StudentShell |
| `/student/profile` | StudentProfileScreen | Student | StudentShell |

---

## Admin ERP (`AdminShell`)

### Hub & Placeholders

| Path | Screen | Module | Auth Role | Shell |
|------|--------|--------|-----------|-------|
| `/admin` | AdminModulePlaceholderScreen | Admin Hub | Staff | AdminShell |
| `/hr` | AdminModulePlaceholderScreen | HR | Staff | AdminShell |
| `/management` | AdminModulePlaceholderScreen | Management | Staff | AdminShell |
| `/transport` | AdminModulePlaceholderScreen | Transport | Staff | AdminShell |
| `/hostel` | AdminModulePlaceholderScreen | Hostel | Staff | AdminShell |

### Admissions (`/admissions`)

| Path | Screen | ID | Auth Role | Shell |
|------|--------|----|-----------|-------|
| `/admissions` | Redirect → dashboard | — | Staff | AdminShell |
| `/admissions/dashboard` | AdmissionsDashboardScreen | AD-01 | Staff | AdminShell |
| `/admissions/leads` | AdmissionsLeadsScreen | AD-02 | Staff | AdminShell |
| `/admissions/leads/:leadId` | AdmissionsLeadDetailScreen | AD-04 | Staff | AdminShell |
| `/admissions/applications` | AdmissionsApplicationsScreen | AD-03 | Staff | AdminShell |
| `/admissions/enrollment` | AdmissionsEnrollmentScreen | AD-05 | Staff | AdminShell |
| `/admissions/documents` | AdmissionsDocumentsScreen | AD-06 | Staff | AdminShell |
| `/admissions/approval` | AdmissionsApprovalScreen | AD-07 | Staff | AdminShell |
| `/admissions/fee-handoff` | AdmissionsFeeHandoffScreen | AD-08 | Staff | AdminShell |
| `/admissions/reports` | AdmissionsReportsScreen | AD-09 | Staff | AdminShell |
| `/admissions/settings` | AdmissionsSettingsScreen | AD-10 | Staff | AdminShell |

### Finance (`/finance`)

| Path | Screen | ID | Auth Role | Shell |
|------|--------|----|-----------|-------|
| `/finance` | Redirect → dashboard | — | Staff | AdminShell |
| `/finance/dashboard` | FinanceDashboardScreen | FN-01 | Staff | AdminShell |
| `/finance/fee-structures` | FinanceFeeStructuresScreen | FN-02 | Staff | AdminShell |
| `/finance/student-accounts` | FinanceStudentAccountsScreen | FN-03 | Staff | AdminShell |
| `/finance/fee-assignment` | FinanceFeeAssignmentScreen | FN-04 | Staff | AdminShell |
| `/finance/collections` | FinanceCollectionsScreen | FN-05 | Staff | AdminShell |

### Student SIS (`/sis`)

| Path | Screen | ID | Auth Role | Shell |
|------|--------|----|-----------|-------|
| `/sis` | Redirect → dashboard | — | Staff | AdminShell |
| `/sis/dashboard` | SisDashboardScreen | SIS-01 | Staff | AdminShell |
| `/sis/students` | SisRegistryScreen | SIS-02 | Staff | AdminShell |
| `/sis/students/:studentId` | SisStudentProfileScreen | SIS-03 | Staff | AdminShell |
| `/sis/academic-assignment` | SisAcademicAssignmentScreen | SIS-04 | Staff | AdminShell |
| `/sis/admissions-conversion` | SisAdmissionsConversionScreen | SIS-05 | Staff | AdminShell |

---

## Reachability Verification

| Check | Method | Result |
|-------|--------|--------|
| Staff ERP smoke | `router_smoke_test.dart` | ✅ 30+ paths |
| Parent / Teacher / Student | Role-gated smoke tests | ✅ |
| Dynamic params | `leadId`, `studentId`, `receiptId`, `threadId` | ✅ smoke |
| Redirects | `/admissions`, `/finance`, `/sis`, `/parent`, `/teacher`, `/student` | ✅ |
| Unauthorized access | Parent blocked from `/admin` | ✅ smoke |

---

## Route Count Summary

| Category | Count |
|----------|-------|
| Auth | 4 |
| Parent | 14 |
| Teacher | 9 |
| Student | 8 |
| Admin ERP (implemented) | 31 |
| Admin ERP (placeholders) | 5 |
| **Total** | **~71** |
