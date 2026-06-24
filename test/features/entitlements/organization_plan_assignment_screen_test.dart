import 'package:akshara_erp/core/entitlements/entitlement_models.dart';
import 'package:akshara_erp/core/entitlements/subscription_admin_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/entitlements/organization_plan_assignment_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _orgs = [
  const OrganizationPlanAssignment(
    organizationId: 'org-1',
    organizationName: 'Sunrise School',
    organizationSlug: 'sunrise',
    planSlug: 'trial',
    status: 'trial',
  ),
  const OrganizationPlanAssignment(
    organizationId: 'org-2',
    organizationName: 'Oakridge Group',
    organizationSlug: 'oakridge',
    planSlug: 'professional',
    status: 'active',
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required bool canAssign,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        canAssignOrganizationPlansProvider.overrideWithValue(canAssign),
        assignableOrganizationsProvider.overrideWith((ref) async => _orgs),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const OrganizationPlanAssignmentScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('OrganizationPlanAssignmentScreen', () {
    testWidgets('superAdmin sees org selector, current plan and save',
        (tester) async {
      await _pump(tester, canAssign: true);

      expect(find.byKey(QaTestKeys.planAssignmentScreen), findsOneWidget);
      expect(find.byKey(QaTestKeys.planAssignmentOrgDropdown), findsOneWidget);
      // Current plan of the first org (Trial) shown.
      expect(find.byKey(QaTestKeys.planAssignmentCurrentPlan), findsOneWidget);
      expect(find.text('Trial'), findsWidgets);
      // Save disabled until the plan is changed.
      final saveBtn = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.planAssignmentSaveButton),
      );
      expect(saveBtn.onPressed, isNull);
      // No-payment reassurance present.
      expect(find.textContaining('No payment is taken'), findsOneWidget);
    });

    testWidgets('changing the plan enables Save', (tester) async {
      await _pump(tester, canAssign: true);

      await tester.tap(find.byKey(QaTestKeys.planAssignmentPlanDropdown));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enterprise').last);
      await tester.pumpAndSettle();

      final saveBtn = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.planAssignmentSaveButton),
      );
      expect(saveBtn.onPressed, isNotNull);
    });

    testWidgets('non-superAdmin is blocked with a clear message',
        (tester) async {
      await _pump(tester, canAssign: false);

      expect(find.byKey(QaTestKeys.planAssignmentScreen), findsNothing);
      expect(find.textContaining('Super Admin'), findsOneWidget);
    });
  });
}
