import 'package:akshara_erp/core/repositories/interfaces/multi_school_operations_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/platform/multi_school/multi_school_models.dart';
import 'package:akshara_erp/features/platform/multi_school/multi_school_portfolio_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMultiSchoolRepository implements MultiSchoolOperationsRepository {
  bool alertDismissed = false;
  SchoolLifecycleStatus status = SchoolLifecycleStatus.trial;

  @override
  Future<SchoolPortfolioDashboard> getPortfolioDashboard({
    required RepositoryQuery query,
  }) async {
    return SchoolPortfolioDashboard(
      kpis: const [
        PortfolioKpi(id: 'k1', label: 'Total Schools', value: '3'),
      ],
      alerts: alertDismissed
          ? const []
          : [
              PortfolioAlert(
                id: 'msa_alert_1',
                title: 'Activation lag',
                message: 'Needs follow-up',
                severity: 'medium',
                schoolId: 'sch_1',
                schoolName: 'School One',
                createdAt: DateTime(2026, 6, 1),
              ),
            ],
      schools: [
        SchoolLifecycleRecord(
          schoolId: 'sch_1',
          schoolName: 'School One',
          status: status,
          planName: 'Growth',
          region: 'Bengaluru',
          healthScore: const SchoolHealthScore(
            schoolId: 'sch_1',
            score: 77,
            band: 'Healthy',
            factors: ['good usage'],
          ),
          studentsCount: 500,
          staffCount: 52,
          updatedAt: DateTime(2026, 6, 1),
        ),
      ],
      pendingActions: const [],
    );
  }

  @override
  Future<SchoolLifecycleRecord> activateSchool({
    required RepositoryQuery query,
    required String schoolId,
  }) async {
    status = SchoolLifecycleStatus.active;
    return (await listSchools(query: query)).first;
  }

  @override
  Future<PortfolioAction> completeAction({
    required RepositoryQuery query,
    required String actionId,
  }) async {
    return PortfolioAction(
      id: actionId,
      title: 'Done',
      description: '',
      schoolId: 'sch_1',
      schoolName: 'School One',
      dueAt: DateTime(2026, 6, 1),
      completed: true,
    );
  }

  @override
  Future<SchoolOnboardingDraft> createOnboardingDraft({
    required RepositoryQuery query,
    required SchoolOnboardingDraft draft,
  }) async {
    return draft;
  }

  @override
  Future<SchoolLifecycleRecord> deactivateSchool({
    required RepositoryQuery query,
    required String schoolId,
    String? reason,
  }) async {
    status = SchoolLifecycleStatus.suspended;
    return (await listSchools(query: query)).first;
  }

  @override
  Future<void> dismissAlert({
    required RepositoryQuery query,
    required String alertId,
  }) async {
    alertDismissed = true;
  }

  @override
  Future<SchoolHealthScore> getSchoolHealth({
    required RepositoryQuery query,
    required String schoolId,
  }) async {
    return const SchoolHealthScore(
      schoolId: 'sch_1',
      score: 77,
      band: 'Healthy',
      factors: ['good usage'],
    );
  }

  @override
  Future<List<PortfolioAlert>> listAlerts(
      {required RepositoryQuery query}) async {
    final dashboard = await getPortfolioDashboard(query: query);
    return dashboard.alerts;
  }

  @override
  Future<List<PortfolioAction>> listPendingActions({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<List<SchoolLifecycleRecord>> listSchools({
    required RepositoryQuery query,
    SchoolLifecycleStatus? status,
  }) async {
    final dashboard = await getPortfolioDashboard(query: query);
    final schools = dashboard.schools;
    if (status == null) return schools;
    return schools.where((school) => school.status == status).toList();
  }

  @override
  Future<SchoolLifecycleRecord> submitOnboarding({
    required RepositoryQuery query,
    required String draftId,
  }) async {
    return (await listSchools(query: query)).first;
  }
}

final _multiSchoolOperator = UserPermissions.fromClaims(
  role: ErpRole.superAdmin,
  explicitPermissions: const [
    Permission.viewMultiSchoolOperations,
    Permission.manageMultiSchoolOperations,
  ],
);

void main() {
  testWidgets('dismisses alert and shows snackbar', (tester) async {
    final fakeRepo = _FakeMultiSchoolRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          multiSchoolOperationsRepositoryProvider.overrideWithValue(fakeRepo),
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
          // SA-1 (MJ-L5): superAdmin no longer holds multi-school perms in the
          // matrix (unseeded server-side); grant them explicitly so this
          // dismiss-alert smoke test still exercises the screen.
          userPermissionsProvider.overrideWithValue(_multiSchoolOperator),
          rbacServiceProvider.overrideWithValue(
            RbacService(_multiSchoolOperator),
          ),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const MultiSchoolPortfolioScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(QaTestKeys.multiSchoolDismissAlertButton('msa_alert_1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(QaTestKeys.multiSchoolAlertDismissedSnackbar),
      findsOneWidget,
    );
  });
}
