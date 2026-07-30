import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/login_screen.dart';
import 'package:akshara_erp/router/app_router.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

AuthState get _studentAuth => const AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: '9876543210',
      displayName: 'Ravi Kumar',
      role: UserRole.student,
    );

AuthState get _staffAuth => AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: '9876543210',
      displayName: 'ERP Staff',
      role: UserRole.staff,
      claims: AuthClaims.demoForRole(erpRole: ErpRole.superAdmin),
    );

AuthState get _financeStaffAuth => AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: '9876543210',
      displayName: 'Finance Staff',
      role: UserRole.staff,
      claims: AuthClaims.demoForRole(erpRole: ErpRole.financeAdmin),
    );

AuthState get _parentAuth => const AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: '9876543210',
      displayName: 'Ravi Kumar',
      role: UserRole.parent,
    );

// Multi-hat staff: Inventory Manager (primary) + Teacher — the cross-shell case.
AuthState get _multiHatAuth => AuthState(
      status: AuthStatus.authenticated,
      phoneNumber: '9000000050',
      displayName: 'Surendra',
      role: UserRole.staff,
      claims: AuthClaims.demoForRole(
        erpRoles: const [ErpRole.inventoryManager, ErpRole.teacher],
      ),
    );

void main() {
  group('homeRouteForRole', () {
    test('maps each role to its dashboard route', () {
      expect(homeRouteForRole(UserRole.parent), RouteNames.parentDashboard);
      expect(homeRouteForRole(UserRole.teacher), RouteNames.teacherDashboard);
      expect(homeRouteForRole(UserRole.student), RouteNames.studentDashboard);
      expect(homeRouteForRole(UserRole.staff), RouteNames.admin);
      expect(homeRouteForRole(null), RouteNames.login);
    });
  });

  group('createAppRouter', () {
    testWidgets('redirects unauthenticated users away from parent routes', (
      tester,
    ) async {
      final router = createAppRouter(
        readAuth: () => const AuthState(status: AuthStatus.unauthenticated),
      );

      await pumpAksharaRouter(tester, router: router);
      router.go(RouteNames.parentDashboard);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.login,
      );
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets(
        'audit R3: staff Face ID capture/enrolment routes are guarded — a '
        'parent deep-linking by URL is bounced to their dashboard, an '
        'unauthenticated user to login', (tester) async {
      // Parent: authenticated but not staff — same wall as the HR attendance
      // screen these routes are pushed from (canAccessAdminErpShell).
      final parentRouter = createAppRouter(readAuth: () => _parentAuth);
      await pumpAksharaRouter(
        tester,
        router: parentRouter,
        authOverride: _parentAuth,
      );
      for (final route in [
        RouteNames.staffFaceEnrollment,
        RouteNames.staffFaceCapture,
      ]) {
        parentRouter.go(route);
        await tester.pumpAndSettle();
        expect(
          parentRouter.routeInformationProvider.value.uri.path,
          RouteNames.parentDashboard,
          reason: '$route must not render staff-only capture UI for a parent',
        );
      }
    });

    testWidgets(
        'audit R3: unauthenticated users cannot reach the staff Face ID routes',
        (tester) async {
      final router = createAppRouter(
        readAuth: () => const AuthState(status: AuthStatus.unauthenticated),
      );
      await pumpAksharaRouter(tester, router: router);
      router.go(RouteNames.staffFaceEnrollment);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.login,
      );
    });

    testWidgets('allows authenticated teacher to reach teacher module routes', (
      tester,
    ) async {
      const teacherAuth = AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: '9876543210',
        displayName: 'Priya Sharma',
        role: UserRole.teacher,
      );
      final router = createAppRouter(readAuth: () => teacherAuth);

      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: teacherAuth,
      );

      const routes = <(String, String)>[
        (RouteNames.teacherDashboard, 'Dashboard'),
        (RouteNames.teacherAttendance, 'Mark Attendance'),
        (RouteNames.teacherMyAttendance, 'My Attendance'),
        (RouteNames.teacherTimetable, 'Timetable'),
        (RouteNames.teacherHomework, 'Homework Review'),
        (RouteNames.teacherExams, 'Exams'),
        (RouteNames.teacherMessages, 'Messages'),
        (RouteNames.teacherLeave, 'Leave'),
      ];

      for (final (route, title) in routes) {
        router.go(route);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, route);
        expect(find.text(title), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('allows authenticated parent to reach parent module routes', (
      tester,
    ) async {
      final router = createAppRouter(readAuth: () => _parentAuth);
      await pumpAksharaRouter(tester, router: router, authOverride: _parentAuth);

      const routes = <(String, String)>[
        (RouteNames.parentTimetable, 'Timetable'),
        (RouteNames.parentHomework, 'Homework'),
        (RouteNames.parentExams, 'Exams'),
        (RouteNames.parentNotices, 'School Notices'),
        (RouteNames.parentEvents, 'School Events'),
        (RouteNames.parentProfile, 'Profile'),
        (RouteNames.parentPayment, 'Pay Fee'),
        (RouteNames.parentReceipts, 'Receipts'),
        (RouteNames.parentLeave, 'Leave Requests'),
        (RouteNames.parentActionInbox, 'Action Needed'),
        (RouteNames.parentFamily, 'My Children'),
      ];

      for (final (route, title) in routes) {
        router.go(route);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, route);
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('allows authenticated student to reach student module routes', (
      tester,
    ) async {
      final router = createAppRouter(readAuth: () => _studentAuth);
      await pumpAksharaRouter(tester, router: router, authOverride: _studentAuth);

      const routes = <(String, String)>[
        (RouteNames.studentDashboard, 'Home'),
        (RouteNames.studentAttendance, 'Attendance'),
        (RouteNames.studentTimetable, 'Timetable'),
        (RouteNames.studentHomework, 'Homework'),
        (RouteNames.studentExams, 'Exams'),
        (RouteNames.studentNotices, 'Notices'),
        (RouteNames.studentProfile, 'Profile'),
      ];

      for (final (route, title) in routes) {
        router.go(route);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, route);
        expect(find.text(title), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('allows authenticated staff to reach admin ERP routes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createAppRouter(readAuth: () => _staffAuth);
      await pumpAksharaRouter(tester, router: router, authOverride: _staffAuth);

      final routes = <(String, String)>[
        (RouteNames.admin, 'Admin Hub'),
        (RouteNames.admissionsDashboard, 'Total Leads (MTD)'),
        (RouteNames.admissionsLeads, 'LD-1042'),
        (RouteNames.admissionsApplications, 'APP-2208'),
        (RouteNames.admissionsLeadDetail('LD-1042'), 'Ananya Reddy'),
        (RouteNames.admissionsEnrollment, 'Student profile'),
        (RouteNames.admissionsDocuments, 'Pending'),
        (RouteNames.admissionsApproval, 'Ananya Reddy'),
        (RouteNames.admissionsFeeHandoff, 'Send to Finance'),
        (RouteNames.admissionsReports, 'Conversion funnel'),
        (RouteNames.admissionsSettings, 'Lead stages'),
        (RouteNames.financeDashboard, 'Fee Collected (MTD)'),
        (RouteNames.financeFeeStructures, 'Fee structure catalog'),
        (RouteNames.financeStudentAccounts, 'Arjun Patel'),
        (RouteNames.financeFeeAssignment, 'Admissions handoff queue'),
        (RouteNames.financeCollections, 'Collected today'),
        (RouteNames.financeCollectionDetail('col_1'), 'RCP-2026-8841'),
        (RouteNames.financeDefaulters, 'Total overdue'),
        (RouteNames.financeRefunds, 'Kavya Iyer'),
        (RouteNames.financeDiscounts, 'Scholarship catalog'),
        (RouteNames.financeReports, 'Report catalog'),
        (RouteNames.financeReconciliation, 'Open AP commitments'),
        (RouteNames.financeSettings, 'Finance settings'),
        (RouteNames.sisDashboard, 'Total Students'),
        (RouteNames.sisStudents, 'Arjun Patel'),
        (RouteNames.sisStudentDetail('SIS-STU-10421'), 'Arjun Patel'),
        (RouteNames.sisAcademicAssignment, 'Academic assignment'),
        (RouteNames.sisAdmissionsConversion, 'Admissions conversion'),
        (RouteNames.sisTransfers, 'Rahul Verma'),
        (RouteNames.hrDashboard, 'Total Employees'),
        (RouteNames.hrEmployees, 'Employee directory'),
        (RouteNames.hrEmployeeDetail('HR-EMP-101'), 'Priya Sharma'),
        (RouteNames.hrAttendance, 'Staff attendance'),
        (RouteNames.hrLeave, 'Leave requests'),
        (RouteNames.hrPayroll, 'Payroll runs'),
        (RouteNames.hrRecruitment, 'Recruitment pipeline'),
        (RouteNames.hrPerformance, 'Performance reviews'),
        (RouteNames.hrSettings, 'HR settings'),
        (RouteNames.managementDashboard, 'Revenue (FY 2026-27)'),
        (RouteNames.managementAnalytics, 'Class summary'),
        (RouteNames.managementAdmissions, 'Funnel stages'),
        (RouteNames.managementFinance, 'Finance module drill-down'),
        (RouteNames.managementAcademics, 'Subject performance'),
        (RouteNames.managementPerformance, 'Class performance'),
        (RouteNames.managementTasks, 'Approval queue'),
        (RouteNames.managementApprovals, 'Approval queue'),
        (RouteNames.managementSettings, 'Management settings'),
        (RouteNames.transportDashboard, 'Active Buses'),
        (RouteNames.transportRoutes, 'Route catalog'),
        (RouteNames.transportVehicles, 'Vehicle registry'),
        (RouteNames.transportDrivers, 'Driver roster'),
        (RouteNames.transportAllocation, 'Student transport allocation'),
        (RouteNames.transportAttendance, 'AM pickup attendance'),
        (RouteNames.transportTracking, 'Vehicle telemetry'),
        (RouteNames.transportReports, 'Report catalog'),
        (RouteNames.transportSettings, 'Transport settings'),
        (RouteNames.hostelDashboard, 'Occupancy'),
        (RouteNames.hostelStudents, 'Hostel residents'),
        (RouteNames.hostelRooms, 'Room catalog'),
        (RouteNames.hostelAttendance, 'Hostel attendance roster'),
        // hostelLeave + hostelVisitors are CODE-7 residence-lite deferrals
        // (SchoolBuildScope-hidden) — reachable-smoke set omits them.
        (RouteNames.hostelMess, 'Weekly menu'),
        (RouteNames.hostelReports, 'Report catalog'),
        (RouteNames.libraryDashboard, 'Total Books'),
        (RouteNames.libraryCatalog, 'Book catalog'),
        (RouteNames.libraryIssues, 'Issue books'),
        (RouteNames.libraryReturns, 'Return books'),
        (RouteNames.libraryMembers, 'Library members'),
        (RouteNames.libraryFines, 'Overdue fines'),
        (RouteNames.libraryResources, 'Digital resources'),
        (RouteNames.libraryReports, 'Report catalog'),
        (RouteNames.inventoryDashboard, 'Total Assets'),
        (RouteNames.inventoryAssets, 'Asset registry'),
        (RouteNames.inventoryCategories, 'Category catalog'),
        (RouteNames.inventoryAllocation, 'Asset allocation'),
        (RouteNames.inventoryMaintenance, 'Maintenance schedule'),
        (RouteNames.inventoryProcurement, 'Purchase orders'),
        (RouteNames.inventoryVendors, 'Vendor directory'),
        (RouteNames.inventoryReports, 'Report catalog'),
        // Alumni is a CODE-8 pilot deferral (whole /alumni/* surface
        // SchoolBuildScope-hidden) — omitted from the reachable-smoke set.
        (RouteNames.controlCenterDashboard, 'Total Schools'),
        (RouteNames.controlCenterSchools, 'Schools registry'),
        (RouteNames.controlCenterSubscriptions, 'Subscription plans'),
        (RouteNames.controlCenterBilling, 'Platform revenue'),
        (RouteNames.controlCenterCrm, 'Sales pipeline'),
        (RouteNames.controlCenterSupport, 'Support tickets'),
        (RouteNames.controlCenterSuccess, 'Customer success'),
        (RouteNames.controlCenterWhiteLabel, 'White label configurations'),
        (RouteNames.controlCenterAnalytics, 'Platform analytics'),
        (RouteNames.controlCenterMonitoring, 'Platform monitoring'),
        (RouteNames.controlCenterRoles, 'Platform roles'),
        (RouteNames.controlCenterSettings, 'Platform settings'),
      ];

      for (final (route, title) in routes) {
        router.go(route);
        await settleRiverpodFutures(tester);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, route);
        expect(find.text(title), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('staff reaches inventory intelligence routes', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createAppRouter(readAuth: () => _staffAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _staffAuth,
        settleSplash: true,
      );

      const desktopRoutes = [
        (RouteNames.inventoryCopilot, 'Stock forecast (units)'),
        (RouteNames.inventoryLifecycle, 'Assets tracked'),
      ];

      for (final (route, title) in desktopRoutes) {
        router.go(route);
        await settleRiverpodFutures(tester);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, route);
        expect(find.text(title), findsAtLeastNWidgets(1));
      }
    });

    testWidgets(
        'V1-SCOPE-1: even permitted staff cannot reach the Education Suite '
        '(Question Paper / QIE deferred to V2)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // _staffAuth HOLDS viewEducation, so this proves the build-scope gate —
      // not RBAC — is what closes the route. Deep-linking straight to
      // /education must not render the Question Papers / Question Bank UI.
      final router = createAppRouter(readAuth: () => _staffAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _staffAuth,
        settleSplash: true,
      );

      router.go(RouteNames.education);
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(find.text('Education Suite'), findsNothing);
      expect(find.text('Question Papers'), findsNothing);
      expect(find.text('Question Bank'), findsNothing);
    });

    testWidgets('blocks parent from admin ERP routes', (tester) async {
      final router = createAppRouter(readAuth: () => _parentAuth);
      await pumpAksharaRouter(tester, router: router, authOverride: _parentAuth);
      router.go(RouteNames.admin);
      await tester.pump();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.parentDashboard,
      );
    });

    testWidgets('finance staff sees access denied on control center', (
      tester,
    ) async {
      final router = createAppRouter(readAuth: () => _financeStaffAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _financeStaffAuth,
      );

      router.go(RouteNames.controlCenterDashboard);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.controlCenterDashboard,
      );
      expect(find.text('Access Denied'), findsOneWidget);
    });

    testWidgets('multi-hat startup lands where the switcher is reachable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createAppRouter(readAuth: () => _multiHatAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _multiHatAuth,
        settleSplash: true,
      );
      await tester.pumpAndSettle();

      // Wherever a multi-hat user lands at startup, the switcher is present.
      expect(find.byKey(QaTestKeys.workspaceSwitcherButton), findsOneWidget);
    });

    testWidgets('multi-hat user switches admin → teacher workspace from chrome', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createAppRouter(readAuth: () => _multiHatAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _multiHatAuth,
        settleSplash: true,
      );
      router.go(RouteNames.admin);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(QaTestKeys.workspaceSwitcherButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(QaTestKeys.workspaceSwitcherSheetItem('Teaching')),
      );
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.teacherDashboard,
      );
    });

    testWidgets('multi-hat user switches BACK teacher → inventory from chrome', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createAppRouter(readAuth: () => _multiHatAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _multiHatAuth,
        settleSplash: true,
      );
      router.go(RouteNames.teacherDashboard);
      await tester.pumpAndSettle();

      // The switcher is reachable from the TEACHER shell too (the gap we fixed).
      expect(find.byKey(QaTestKeys.workspaceSwitcherButton), findsOneWidget);

      await tester.tap(find.byKey(QaTestKeys.workspaceSwitcherButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(QaTestKeys.workspaceSwitcherSheetItem('Inventory')),
      );
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.inventoryDashboard,
      );
    });

    testWidgets('blocks non-teaching staff from teacher routes (cross-shell)', (
      tester,
    ) async {
      final router = createAppRouter(readAuth: () => _financeStaffAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _financeStaffAuth,
      );
      router.go(RouteNames.teacherDashboard);
      await tester.pumpAndSettle();

      // A finance staffer (no teaching role) is bounced away from /teacher.
      expect(
        router.routeInformationProvider.value.uri.path,
        isNot(RouteNames.teacherDashboard),
      );
    });

    testWidgets('allows multi-hat staff (holds teacher role) into /teacher', (
      tester,
    ) async {
      final router = createAppRouter(readAuth: () => _multiHatAuth);
      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _multiHatAuth,
      );
      router.go(RouteNames.teacherDashboard);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.teacherDashboard,
      );
    });

    testWidgets('blocks student from teacher routes', (tester) async {
      final router = createAppRouter(readAuth: () => _studentAuth);

      await pumpAksharaRouter(tester, router: router, authOverride: _studentAuth);
      router.go(RouteNames.teacherDashboard);
      await tester.pump();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.studentDashboard,
      );
    });

    testWidgets('redirects otpPending users to OTP verification', (
      tester,
    ) async {
      const otpPending = AuthState(
        status: AuthStatus.otpPending,
        phoneNumber: '9876543210',
        role: UserRole.parent,
      );
      final router = createAppRouter(readAuth: () => otpPending);

      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: otpPending,
        settleSplash: false,
      );

      router.go(RouteNames.login);
      await tester.pump();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.otpVerification,
      );
    });

    testWidgets('redirects unauthenticated users from AI assistant route', (
      tester,
    ) async {
      final router = createAppRouter(
        readAuth: () => const AuthState(status: AuthStatus.unauthenticated),
      );

      await pumpAksharaRouter(tester, router: router);
      router.go(RouteNames.aiAssistant);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.login,
      );
    });

    testWidgets('allows authenticated student to reach AI assistant', (
      tester,
    ) async {
      final router = createAppRouter(readAuth: () => _studentAuth);

      await pumpAksharaRouter(
        tester,
        router: router,
        authOverride: _studentAuth,
      );
      router.go(RouteNames.aiAssistant);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        RouteNames.aiAssistant,
      );
    });
  });
}
