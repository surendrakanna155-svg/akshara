import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/admissions/dashboard/widgets/admissions_counselor_leaderboard.dart';
import 'package:akshara_erp/features/admissions/dashboard/widgets/admissions_pipeline_preview.dart';
import 'package:akshara_erp/features/finance/dashboard/widgets/finance_recent_payments_table.dart';
import 'package:akshara_erp/features/hr/dashboard/hr_dashboard_screen.dart';
import 'package:akshara_erp/features/hr/hr_models.dart';
import 'package:akshara_erp/features/hr/hr_providers.dart';
import 'package:akshara_erp/features/hr/staff_360/staff_360_screen.dart';
import 'package:akshara_erp/features/sis/dashboard/widgets/sis_recent_enrollments_table.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_provider.dart';
import 'package:akshara_erp/features/teacher/attendance/teacher_attendance_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';
import '../../helpers/provider_test_overrides.dart';

/// Day-one UX contract: on a freshly created school EVERY module is empty, and
/// an empty module must say what is empty and why — never a blank hole under a
/// header, never a "0" standing in for an unknown, never a wrong explanation.
///
/// These are the states a buyer sees on their first login, so they are held to
/// the same bar as the populated states.

void _useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Pumps a bare widget under the Akshara theme (the section widgets read
/// `context.colors` / `context.aksharaText`).
Future<void> _pumpWidget(
  WidgetTester tester,
  Widget child, {
  Size viewport = const Size(1440, 900),
}) async {
  _useViewport(tester, viewport);
  await tester.pumpWidget(
    MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

// ─────────────────────────────────────────────────────────────────────────────

const _emptyClassRoster = TeacherAttendanceData(
  classes: [
    TeacherAttendanceClass(
      id: 'class-9c-p2',
      label: 'Class 9-C',
      subject: 'Science',
      periodLabel: 'Period 2',
      studentCount: 0,
      isPending: true,
    ),
  ],
  students: [],
  selectedClassId: 'class-9c-p2',
  unreadNotifications: 0,
);

const _populatedRoster = TeacherAttendanceData(
  classes: [
    TeacherAttendanceClass(
      id: 'class-9c-p2',
      label: 'Class 9-C',
      subject: 'Science',
      periodLabel: 'Period 2',
      studentCount: 1,
      isPending: true,
    ),
  ],
  students: [
    TeacherAttendanceStudent(
      id: 's1',
      name: 'Arjun Das',
      rollNo: '05',
      mark: StudentAttendanceMark.unmarked,
    ),
  ],
  selectedClassId: 'class-9c-p2',
  unreadNotifications: 0,
);

Future<void> _pumpAttendance(
  WidgetTester tester,
  TeacherAttendanceData roster,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: providerTestOverrides([
        teacherAttendanceProvider.overrideWithValue(roster),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const TeacherAttendanceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ─────────────────────────────────────────────────────────────────────────────

HrEmployeeDetail _staffDetail({
  required List<HrEmployeeLeaveBalance> leaveBalances,
}) {
  return HrEmployeeDetail(
    employee: const HrEmployee(
      id: 'EMP-NEW',
      name: 'Nikita Sharma',
      employeeCode: 'EMP-NEW',
      department: HrDepartment.academics,
      role: HrEmployeeRole.teacher,
      designation: 'Science Teacher',
      email: 'nikita@example.com',
      phone: '98490 00000',
      joinDate: '2026-07-01',
      status: HrEmployeeStatus.active,
    ),
    reportingManager: '',
    address: '',
    emergencyContact: '',
    leaveBalances: leaveBalances,
    documents: const [],
    recentAttendance: const [],
    integrationNotes: const [],
  );
}

Future<void> _pumpStaff360(
  WidgetTester tester, {
  required List<HrEmployeeLeaveBalance> leaveBalances,
}) async {
  _useViewport(tester, const Size(420, 2400));
  await initProviderTestPrefs();
  await tester.pumpWidget(
    ProviderScope(
      overrides: providerTestOverrides([
        hrEmployeeDetailFutureProvider('EMP-NEW').overrideWith(
          (ref) async => _staffDetail(leaveBalances: leaveBalances),
        ),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Staff360Screen(employeeId: 'EMP-NEW'),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

// ─────────────────────────────────────────────────────────────────────────────

HrDashboardData _hrDashboard({
  required List<HrPendingLeaveItem> pendingLeave,
  required List<HrCandidate> recruitmentSnapshot,
}) {
  return HrDashboardData(
    kpis: const [
      HrKpi(
        id: 'headcount',
        value: '0',
        label: 'Total Employees',
        icon: Icons.groups_outlined,
        accentName: 'primary',
      ),
    ],
    headcountTrend: const [
      HrTrendPoint(label: 'Jul', amountLakhs: 0, targetLakhs: 0),
    ],
    attendanceTrend: const [
      HrTrendPoint(label: 'Jul', amountLakhs: 0, targetLakhs: 0),
    ],
    pendingLeave: pendingLeave,
    recruitmentSnapshot: recruitmentSnapshot,
    aiInsight: 'Nothing to review yet.',
    managementKpiNote: 'Figures update as staff records are added.',
  );
}

Future<void> _pumpHrDashboard(WidgetTester tester) async {
  _useViewport(tester, const Size(1440, 2400));
  await initProviderTestPrefs();
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        hrDashboardFutureProvider.overrideWith(
          (ref) async => _hrDashboard(
            pendingLeave: const [],
            recruitmentSnapshot: const [],
          ),
        ),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const HrDashboardScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  group('Teacher attendance — an empty roster is not a failed search', () {
    testWidgets('a class with nobody enrolled says so', (tester) async {
      await _pumpAttendance(tester, _emptyClassRoster);

      expect(
        find.textContaining('No students are enrolled in this class yet'),
        findsOneWidget,
      );
      // The day-one defect: the teacher typed nothing, so blaming their search
      // is a lie.
      expect(find.text('No students match your search.'), findsNothing);
    });

    testWidgets('a search that matches nothing still blames the search',
        (tester) async {
      await _pumpAttendance(tester, _populatedRoster);

      await tester.enterText(
        find.byKey(QaTestKeys.teacherAttendanceSearchField),
        'Zzz No Match',
      );
      await tester.pumpAndSettle();

      expect(find.text('No students match your search.'), findsOneWidget);
      expect(
        find.textContaining('No students are enrolled in this class yet'),
        findsNothing,
      );
    });
  });

  group('Staff 360 — an unknown leave balance is never rendered as 0', () {
    testWidgets('no leave policy configured hides the metric entirely',
        (tester) async {
      await _pumpStaff360(tester, leaveBalances: const []);

      // Honest state: "0 Leave days left" would be a measured-looking value for
      // something the school has not configured — and would contradict the
      // "No leave balances recorded." line on the same screen.
      expect(find.text('Leave days left'), findsNothing);
      expect(find.text('No leave balances recorded.'), findsOneWidget);
    });

    testWidgets('a configured balance still shows the metric', (tester) async {
      await _pumpStaff360(
        tester,
        leaveBalances: const [
          HrEmployeeLeaveBalance(
            leaveType: HrLeaveType.casual,
            available: 8,
            used: 4,
          ),
        ],
      );

      expect(find.text('Leave days left'), findsOneWidget);
      expect(find.text('8'), findsWidgets);
      expect(find.text('No leave balances recorded.'), findsNothing);
    });
  });

  group('Admin dashboards — no headed section renders a blank hole', () {
    testWidgets('HR pending leave and recruitment explain themselves',
        (tester) async {
      await _pumpHrDashboard(tester);

      expect(find.text('Pending leave queue'), findsOneWidget);
      expect(
        find.text('No leave requests are waiting for approval.'),
        findsOneWidget,
      );

      expect(find.text('Recruitment snapshot'), findsOneWidget);
      expect(
        find.textContaining('No open vacancies'),
        findsOneWidget,
      );
    });

    testWidgets('SIS recent enrollments — the day-one module', (tester) async {
      await _pumpWidget(
        tester,
        const SisRecentEnrollmentsTable(enrollments: []),
      );

      expect(
        find.textContaining('No students enrolled yet.'),
        findsOneWidget,
      );
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets('Finance recent payments', (tester) async {
      await _pumpWidget(
        tester,
        const FinanceRecentPaymentsTable(payments: []),
      );

      expect(
        find.textContaining('No payments collected yet.'),
        findsOneWidget,
      );
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets('Admissions pipeline preview does not reserve 220px of blank',
        (tester) async {
      await _pumpWidget(tester, const AdmissionsPipelinePreview(pipeline: []));

      expect(find.textContaining('No enquiries yet.'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 220,
        ),
        findsNothing,
        reason: 'an empty kanban must not hold open a fixed-height box',
      );
    });

    testWidgets('Admissions counselor leaderboard does not reserve 120px',
        (tester) async {
      await _pumpWidget(
        tester,
        const AdmissionsCounselorLeaderboard(entries: []),
      );

      expect(
        find.textContaining('No counselor activity yet.'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 120,
        ),
        findsNothing,
      );
    });
  });

  group('Admissions sections still render when populated', () {
    testWidgets('a non-empty leaderboard is unchanged', (tester) async {
      await _pumpWidget(
        tester,
        const AdmissionsCounselorLeaderboard(
          entries: [
            CounselorLeaderboardEntry(
              counselor: 'Meera Nair',
              leadsHandled: 12,
              conversions: 5,
              conversionRate: 41.7,
            ),
          ],
        ),
      );

      expect(find.text('Meera Nair'), findsOneWidget);
      expect(find.textContaining('No counselor activity yet.'), findsNothing);
    });
  });
}
