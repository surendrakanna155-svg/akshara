import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/platform/branch/branch_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// SA-1 (MJ-L5): superAdmin no longer holds branch perms in the matrix
// (unseeded server-side); grant them explicitly so this screen smoke test
// still exercises the screen. The write succeeds here because the test runs in
// a non-API (offline) build where the mock fallback is intended.
final _branchOperator = UserPermissions.fromClaims(
  role: ErpRole.superAdmin,
  explicitPermissions: const [
    Permission.viewBranchOperations,
    Permission.manageBranchOperations,
  ],
);

void main() {
  testWidgets('branch screen assigns school', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
          userPermissionsProvider.overrideWithValue(_branchOperator),
          rbacServiceProvider.overrideWithValue(
            RbacService(_branchOperator),
          ),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const BranchScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QaTestKeys.branchAssignSchoolButton));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.branchAssignmentSnackbar), findsOneWidget);
  });
}
