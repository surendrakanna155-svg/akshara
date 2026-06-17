import 'package:akshara_erp/core/approvals/approval_category.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/management/approval/approval_center_provider.dart';
import 'package:akshara_erp/features/management/approval/principal_approval_center_screen.dart';
import 'package:akshara_erp/features/management/tasks/management_tasks_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_test_overrides.dart';
import '../../../helpers/provider_test_overrides.dart';
import '../../../test_helpers.dart';

Future<void> pumpApprovalCenter(
  WidgetTester tester, {
  Size viewport = const Size(1440, 900),
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        authStateOverride(erpWidgetTestStaffAuth()),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const PrincipalApprovalCenterScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('Principal Approval Center screen', () {
    testWidgets('renders approval queue with demo data', (tester) async {
      await pumpApprovalCenter(tester);

      expect(find.byKey(QaTestKeys.approvalCenterScreen), findsOneWidget);
      expect(find.text('Approval queue'), findsOneWidget);
      expect(find.text('Science lab upgrade — Q3 budget'), findsOneWidget);
    });

    testWidgets('academic filter shows exam results only', (tester) async {
      await pumpApprovalCenter(tester);

      await tester.tap(find.byKey(QaTestKeys.approvalTypeFilterAcademic));
      await tester.pumpAndSettle();

      expect(find.text('Publish Class 8-A Mathematics results'), findsOneWidget);
      expect(find.text('Science lab upgrade — Q3 budget'), findsNothing);
    });

    testWidgets('approve button enabled for pending item', (tester) async {
      await pumpApprovalCenter(tester);

      expect(
        find.byKey(QaTestKeys.approvalApproveButton('appr_000001')),
        findsWidgets,
      );
    });

    testWidgets('ManagementTasksScreen delegates to approval center',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            authStateOverride(erpWidgetTestStaffAuth()),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const ManagementTasksScreen(),
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.approvalCenterScreen), findsOneWidget);
    });

    testWidgets('renders on mobile viewport', (tester) async {
      await pumpApprovalCenter(
        tester,
        viewport: const Size(390, 844),
      );

      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Science lab upgrade — Q3 budget'), findsOneWidget);
    });
  });
}
