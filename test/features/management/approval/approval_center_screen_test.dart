import 'package:akshara_erp/features/admin/admin_filter_bar.dart';
import 'package:akshara_erp/core/approvals/approval_category.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/management/tasks/management_tasks_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_test_overrides.dart';
import 'package:go_router/go_router.dart';

import '../../../test_helpers.dart';
import 'approval_center_test_helpers.dart';

void main() {
  group('Principal Approval Center — widget certification', () {
    testWidgets('approval queue loads with demo items', (tester) async {
      await pumpApprovalCenter(tester);

      expect(find.byKey(QaTestKeys.approvalCenterScreen), findsOneWidget);
      expect(find.text('Approval queue'), findsOneWidget);
      expect(find.text('Science lab upgrade — Q3 budget'), findsOneWidget);
    });

    testWidgets('desktop layout renders DataTable', (tester) async {
      await pumpApprovalCenter(tester, viewport: const Size(1440, 900));

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Select a request to review details.'), findsOneWidget);
    });

    testWidgets('mobile layout renders cards without DataTable', (tester) async {
      await pumpApprovalCenter(tester, viewport: const Size(390, 844));

      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(Card), findsWidgets);
      expect(find.text('Science lab upgrade — Q3 budget'), findsOneWidget);
    });

    testWidgets('status filter Pending hides approved items', (tester) async {
      await pumpApprovalCenter(tester);

      expect(find.text('Digital ads — Q3 enrollment'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AdminFilterBar),
          matching: find.text('Pending'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Digital ads — Q3 enrollment'), findsNothing);
      expect(find.text('Science lab upgrade — Q3 budget'), findsOneWidget);
    });

    testWidgets('category filter Finance hides academic items', (tester) async {
      await pumpApprovalCenter(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Finance'));
      await tester.pumpAndSettle();

      expect(find.text('Science lab upgrade — Q3 budget'), findsOneWidget);
      expect(
        find.text('Publish Class 8-A Mathematics results'),
        findsNothing,
      );
    });

    testWidgets('academic filter shows exam results only', (tester) async {
      await pumpApprovalCenter(tester);

      await tester.tap(find.byKey(QaTestKeys.approvalTypeFilterAcademic));
      await tester.pumpAndSettle();

      expect(find.text('Publish Class 8-A Mathematics results'), findsOneWidget);
      expect(find.text('Science lab upgrade — Q3 budget'), findsNothing);
    });

    testWidgets('detail panel shows request and audit history', (tester) async {
      await pumpApprovalCenter(tester);

      await tester.tap(find.byKey(QaTestKeys.approvalTypeFilterAcademic));
      await tester.pumpAndSettle();
      // PRI-1..5 added banner/digest/exception cards above the queue, so the
      // row can sit below the fold — scroll it into view before tapping.
      final title = find.text('Publish Class 8-A Mathematics results');
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();

      expect(find.text('Approval history'), findsOneWidget);
      expect(find.textContaining('Submitted'), findsWidgets);
      // P2-UX-2 §2.3 — the summary is now an on-card decision fact too, so it
      // appears both on the queue row and in the opened detail panel.
      expect(find.textContaining('Half-yearly exam'), findsWidgets);
    });

    testWidgets('RBAC hides approve actions for teacher role', (tester) async {
      await pumpApprovalCenter(
        tester,
        extraOverrides: [
          authStateOverride(teacherAuthWithoutManagementApprove()),
        ],
      );

      await tester.tap(find.byKey(QaTestKeys.approvalTypeFilterAcademic));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('ManagementTasksScreen delegates to approval center',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            environmentProvider.overrideWith(
              (ref) => Environment.development.copyWith(enableQaLogin: true),
            ),
            authStateOverride(erpWidgetTestStaffAuth()),
          ]),
          child: MaterialApp.router(
            theme: AksharaAppTheme.light(),
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const ManagementTasksScreen(),
                ),
              ],
            ),
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.approvalCenterScreen), findsOneWidget);
    });
  });

  group('ApprovalCategory unit', () {
    test('matchesType covers all filter buckets', () {
      expect(
        ApprovalCategory.academic.matchesType(ApprovalRequestType.examResults),
        isTrue,
      );
      expect(
        ApprovalCategory.inventory.matchesType(ApprovalRequestType.budget),
        isFalse,
      );
    });
  });
}
