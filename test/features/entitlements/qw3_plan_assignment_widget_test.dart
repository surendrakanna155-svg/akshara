import 'dart:async';

import 'package:akshara_erp/core/entitlements/entitlement_models.dart';
import 'package:akshara_erp/core/entitlements/subscription_admin_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/entitlements/organization_plan_assignment_screen.dart';
import 'package:akshara_erp/shared/widgets/akshara_loading_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-056 — Organization plan-assignment screen negative paths (B2).
/// `organization_plan_assignment_screen.dart` lets a superAdmin reassign an org
/// plan. Covers: the assign action failing → "Could not update plan" snackbar,
/// and the organizations list still loading → loading spinner.

const _demoOrg = OrganizationPlanAssignment(
  organizationId: 'org_1',
  organizationName: 'NIKSHA Trust',
  organizationSlug: 'akshara-trust',
  planSlug: 'trial',
  status: 'trial',
);

List<Override> _superAdmin() => [
      userPermissionsProvider.overrideWithValue(
        UserPermissions.forRole(ErpRole.superAdmin),
      ),
    ];

Future<void> _pump(WidgetTester tester,
    {required List<Override> overrides}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([..._superAdmin(), ...overrides]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const OrganizationPlanAssignmentScreen(),
      ),
    ),
  );
}

void main() {
  group('QA-F-056 · OrganizationPlanAssignmentScreen', () {
    testWidgets('failing assign surfaces the Could not update plan error',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          assignableOrganizationsProvider.overrideWith(
            (ref) async => const [_demoOrg],
          ),
          // The Save action throws — the screen must catch + surface the error.
          assignSubscriptionActionProvider.overrideWithValue(
            ({
              required String organizationId,
              required String planSlug,
              String? status,
            }) async =>
                throw Exception('assign boom'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // Form rendered with the org's current plan; Save is disabled until the
      // target plan changes.
      expect(find.byKey(QaTestKeys.planAssignmentScreen), findsOneWidget);
      var save = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.planAssignmentSaveButton),
      );
      expect(save.onPressed, isNull);

      // Change the target plan (trial → enterprise) to enable Save.
      await tester.tap(find.byKey(QaTestKeys.planAssignmentPlanDropdown));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enterprise').last);
      await tester.pumpAndSettle();

      save = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.planAssignmentSaveButton),
      );
      expect(save.onPressed, isNotNull);

      await tester.tap(find.byKey(QaTestKeys.planAssignmentSaveButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not update plan'), findsOneWidget);
    });

    testWidgets('shows the loading spinner while organizations load',
        (tester) async {
      final pending = Completer<List<OrganizationPlanAssignment>>();
      addTearDown(() {
        if (!pending.isCompleted) pending.complete(const []);
      });

      await _pump(
        tester,
        overrides: [
          assignableOrganizationsProvider.overrideWith(
            (ref) => pending.future,
          ),
        ],
      );
      await tester.pump();

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });
  });
}
