import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/platform/franchise/franchise_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// SA-1 (MJ-L5): superAdmin no longer holds franchise perms in the matrix
// (unseeded server-side); grant them explicitly so this screen smoke test
// still exercises the screen.
final _franchiseOperator = UserPermissions.fromClaims(
  role: ErpRole.superAdmin,
  explicitPermissions: const [
    Permission.viewFranchiseOperations,
    Permission.manageFranchiseOperations,
  ],
);

void main() {
  testWidgets('franchise screen improves KPI score', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
          userPermissionsProvider.overrideWithValue(_franchiseOperator),
          rbacServiceProvider.overrideWithValue(
            RbacService(_franchiseOperator),
          ),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const FranchiseScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QaTestKeys.franchiseImproveButton('FR-01')));
    await tester.pumpAndSettle();
    expect(find.byKey(QaTestKeys.franchiseUpdatedSnackbar), findsOneWidget);
  });
}
