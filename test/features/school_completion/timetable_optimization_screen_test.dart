import 'package:akshara_erp/core/repositories/academic/academic_catalog_provider.dart';
import 'package:akshara_erp/core/repositories/academic/academic_models.dart';
import 'package:akshara_erp/core/repositories/mock/mock_school_completion_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/school_completion/timetable_optimization_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = AcademicCatalogData(
    years: [
      AcademicYear(
        yearId: 'year_1',
        yearLabel: '2026-27',
        startDate: '2026-04-01',
        endDate: '2027-03-31',
        isCurrent: true,
        status: 'active',
      ),
    ],
    classes: [],
    sections: [],
    teacherAssignments: [],
  );

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        schoolCompletionRepositoryProvider.overrideWithValue(
          MockSchoolCompletionRepository(),
        ),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        academicCatalogFutureProvider.overrideWith((_) async => catalog),
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(ErpRole.superAdmin),
        ),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const TimetableOptimizationScreen(),
      ),
    );
  }

  testWidgets('applies recommendation and shows success snackbar',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final applyButton = find.byKey(
      QaTestKeys.timetableOptimizationApplyButton('rec_balance_load'),
    );
    expect(applyButton, findsOneWidget);

    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(QaTestKeys.timetableOptimizationApplySuccessSnackbar),
      findsOneWidget,
    );
  });
}
