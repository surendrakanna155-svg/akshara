import 'package:akshara_erp/core/config/leave_approval_config.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/refunds/finance_refunds_screen.dart';
import 'package:akshara_erp/features/hr/leave/hr_leave_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../finance/finance_phase2_screens_test.dart' show pumpFinanceScreen;
import '../../hr/hr_screens_test.dart' show pumpHrScreen;

void main() {
  group('P1-PRIN-001 unified approval inbox redirects', () {
    testWidgets('finance refunds defer pending approval to Approval Center',
        (tester) async {
      await pumpFinanceScreen(tester, const FinanceRefundsScreen());

      await tester.tap(find.text('Kavya Iyer').first);
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.openApprovalCenterButton), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
    });

    testWidgets('HR leave defers pending approval when governance enabled',
        (tester) async {
      await pumpHrScreen(tester, const HrLeaveScreen());

      expect(find.byKey(QaTestKeys.openApprovalCenterButton), findsWidgets);
      expect(find.text('Approve'), findsNothing);
    });

    testWidgets('HR leave keeps inline approve when governance disabled',
        (tester) async {
      await pumpHrScreen(
        tester,
        const HrLeaveScreen(),
        overrides: [
          leaveApprovalRequiredProvider.overrideWith((ref) => false),
        ],
      );

      expect(find.text('Approve'), findsWidgets);
      expect(find.text('Open Approval Center'), findsNothing);
    });
  });
}
