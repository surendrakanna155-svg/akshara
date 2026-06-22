import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/platform/branch/branch_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('branch screen assigns school', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
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
