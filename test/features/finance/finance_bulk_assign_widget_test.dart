// PRC-A gap fix — widget coverage for the bulk/class-wide fee-structure
// assignment dialog. Every assignment used to be one student at a time via
// the admissions-handoff queue; this proves the "Bulk assign" entry point is
// permission-gated, opens with the class roster pre-selected ("default all"),
// and reports the assigned/skipped outcome after submit.

import 'package:akshara_erp/core/repositories/paginated_result.dart';
import 'package:akshara_erp/core/repositories/academic/academic_catalog_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/fee_assignment/finance_bulk_assign_provider.dart';
import 'package:akshara_erp/features/finance/fee_assignment/finance_fee_assignment_screen.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

const _testStudents = [
  SisStudent(
    id: 'stu-1',
    studentName: 'Aisha Rao',
    admissionNumber: 'ADM-001',
    classLabel: '8',
    section: 'A',
    academicYear: '2026-27',
    status: SisStudentStatus.active,
    gender: 'female',
    dateOfBirth: '2013-04-01',
    guardianName: 'Rao',
    phone: '9000000001',
    email: 'aisha@example.com',
    enrolledAt: '2020-06-01',
  ),
  SisStudent(
    id: 'stu-2',
    studentName: 'Vikram Singh',
    admissionNumber: 'ADM-002',
    classLabel: '8',
    section: 'A',
    academicYear: '2026-27',
    status: SisStudentStatus.active,
    gender: 'male',
    dateOfBirth: '2013-05-02',
    guardianName: 'Singh',
    phone: '9000000002',
    email: 'vikram@example.com',
    enrolledAt: '2020-06-01',
  ),
];

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

// A real (if minimal) GoRouter is required: ManagePermissionGuard (behind
// every AksharaManageAction, including the Bulk assign button) calls
// GoRouterState.of(context) when a permission check FAILS, to audit-log the
// denied route — a bare MaterialApp has no GoRouter ancestor for that call.
Future<void> _pump(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  _useDesktopViewport(tester);
  final router = GoRouter(
    initialLocation: '/finance/fee-assignment',
    routes: [
      GoRoute(
        path: '/finance/fee-assignment',
        builder: (context, state) => const FinanceFeeAssignmentScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        // Deterministic single-class roster so "default all" + submit is
        // never flaky against the shared mock SIS/academic-catalog seed data.
        financeBulkAssignStudentsFutureProvider.overrideWith(
          (ref) async => const PaginatedResult<SisStudent>(
            items: _testStudents,
            page: 1,
            pageSize: 200,
            total: 2,
            hasMore: false,
          ),
        ),
        classOptionsProvider.overrideWithValue(const ['8']),
        ...overrides,
      ]),
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // Denied-access auditing (hit whenever a role lacking manageFinance
    // renders the gated Bulk assign button) reads sharedPreferencesProvider.
    await initProviderTestPrefs();
  });

  group('PRC-A · Bulk assign fee structure dialog', () {
    testWidgets('Bulk assign button is hidden without manageFinance',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );

      expect(find.byKey(QaTestKeys.financeBulkAssignButton), findsNothing);
    });

    testWidgets(
        'Bulk assign button is shown with manageFinance and opens the '
        'dialog with the class roster pre-selected', (tester) async {
      await _pump(
        tester,
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );

      final button = find.byKey(QaTestKeys.financeBulkAssignButton);
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Bulk assign fee structure'), findsOneWidget);
      // Both seeded students are listed and pre-checked ("default all").
      expect(
        find.byKey(QaTestKeys.financeBulkAssignStudentCheckbox('stu-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.financeBulkAssignStudentCheckbox('stu-2')),
        findsOneWidget,
      );
      final checkbox1 = tester.widget<CheckboxListTile>(
        find.byKey(QaTestKeys.financeBulkAssignStudentCheckbox('stu-1')),
      );
      expect(checkbox1.value, isTrue);
    });

    testWidgets(
        'deselecting a student then submitting assigns only the selected '
        'ones and shows the report', (tester) async {
      await _pump(
        tester,
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );

      await tester.tap(find.byKey(QaTestKeys.financeBulkAssignButton));
      await tester.pumpAndSettle();

      // Deselect one student — only the remaining one should be assigned.
      await tester.tap(
        find.byKey(QaTestKeys.financeBulkAssignStudentCheckbox('stu-2')),
      );
      await tester.pump();

      await tester.tap(find.byKey(QaTestKeys.financeBulkAssignSubmitButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.financeBulkAssignSuccessSnackbar),
        findsOneWidget,
      );
      expect(find.text('Bulk assignment report'), findsOneWidget);
      expect(find.text('Assigned (1)'), findsOneWidget);

      await tester.tap(find.byKey(QaTestKeys.financeBulkAssignReportDoneButton));
      await tester.pumpAndSettle();
      expect(find.text('Bulk assignment report'), findsNothing);
    });

    testWidgets('deselecting every student disables submit (guard, no pop)',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );

      await tester.tap(find.byKey(QaTestKeys.financeBulkAssignButton));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(QaTestKeys.financeBulkAssignSelectAllCheckbox),
      );
      await tester.pump();

      await tester.tap(find.byKey(QaTestKeys.financeBulkAssignSubmitButton));
      await tester.pumpAndSettle();

      // Nothing selected → the confirm guard keeps the dialog open.
      expect(find.text('Bulk assign fee structure'), findsOneWidget);
    });
  });
}
