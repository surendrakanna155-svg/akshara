import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/repositories/interfaces/director_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/entitlements/entitlement_provider.dart';
import 'package:akshara_erp/core/entitlements/entitlement_resolver.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/features/director/director_compliance_screen.dart';
import 'package:akshara_erp/features/director/director_models.dart';
import 'package:akshara_erp/features/director/director_reports_screen.dart';
import 'package:akshara_erp/features/entitlements/entitlement_module_gate.dart';
import 'package:akshara_erp/router/director_navigation.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Director repository whose action endpoints fail, so the screens must surface
/// an error snackbar (DIREC-2 summary, DIREC-3 acknowledge). Read endpoints
/// return just enough data to render the action surface.
class _FailingActionDirectorRepository implements DirectorRepository {
  @override
  Future<DirectorComplianceItem> acknowledgeCompliance({
    required RepositoryQuery query,
    required String complianceId,
  }) async {
    throw Exception('acknowledge boom');
  }

  @override
  Future<String> generateExecutiveSummary({
    required RepositoryQuery query,
    required String focusArea,
  }) async {
    throw Exception('summary boom');
  }

  @override
  Future<List<DirectorComplianceItem>> getComplianceMonitoring({
    required RepositoryQuery query,
  }) async {
    return [
      DirectorComplianceItem(
        id: 'c1',
        schoolName: 'NIKSHA North',
        category: 'Safety',
        requirement: 'Fire NOC renewal',
        status: DirectorComplianceStatus.dueSoon,
        dueDate: DateTime(2026, 7, 1),
        owner: 'Principal',
        evidenceUploaded: false,
        acknowledged: false,
      ),
    ];
  }

  @override
  Future<List<DirectorReportItem>> getStrategicReports({
    required RepositoryQuery query,
  }) async {
    return [
      DirectorReportItem(
        id: 'r1',
        title: 'Board Pack',
        description: 'Quarterly board pack',
        lastGeneratedAt: DateTime(2026, 6, 1),
        fileType: 'pdf',
      ),
    ];
  }

  // Unused endpoints for these tests.
  @override
  Future<DirectorBoardPack> exportReport({
    required RepositoryQuery query,
    required String reportId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<DirectorMetricInput>> getMetricInputs({
    required RepositoryQuery query,
  }) async =>
      const [];

  @override
  Future<DirectorMetricInput> saveMetricInput({
    required RepositoryQuery query,
    required DirectorMetricInputDraft draft,
  }) async =>
      throw UnimplementedError();

  @override
  Future<DirectorAdmissionsSnapshot> getAdmissionsPerformance({
    required RepositoryQuery query,
  }) async =>
      throw UnimplementedError();

  @override
  Future<DirectorDashboardData> getExecutiveDashboard({
    required RepositoryQuery query,
  }) async =>
      throw UnimplementedError();

  @override
  Future<DirectorGrowthSnapshot> getGrowthAnalytics({
    required RepositoryQuery query,
  }) async =>
      throw UnimplementedError();

  @override
  Future<DirectorMarketingSnapshot> getMarketingPerformance({
    required RepositoryQuery query,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<DirectorSchoolRow>> getMultiSchoolOverview({
    required RepositoryQuery query,
  }) async =>
      throw UnimplementedError();

  @override
  Future<DirectorCollectionReport> getCollectionReport({
    required RepositoryQuery query,
  }) async =>
      throw UnimplementedError();

  @override
  Future<DirectorSchoolSnapshot> getSchoolSnapshot({
    required RepositoryQuery query,
    required String schoolId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<DirectorGrowthSnapshot> getPortfolioAnalytics({
    required RepositoryQuery query,
  }) async =>
      throw UnimplementedError();

  @override
  Future<DirectorRevenueSnapshot> getRevenueOverview({
    required RepositoryQuery query,
  }) async =>
      throw UnimplementedError();
}

// Ceiling that does NOT include multi_branch — Director is plan-locked.
final _trialCeiling = EntitlementResolver.planCeiling(const {});
// Ceiling that includes multi_branch — Director is unlocked.
final _enterpriseCeiling =
    EntitlementResolver.planCeiling({'module.multi_branch'});

Future<ProviderScope> _scope({
  required Widget home,
  required SharedPreferences prefs,
  required SchoolCapabilities ceiling,
}) async {
  return ProviderScope(
    overrides: [
      directorRepositoryProvider
          .overrideWithValue(_FailingActionDirectorRepository()),
      repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Grant manage so the action buttons are enabled and the mutation runs
      // (then fails inside the repository).
      userPermissionsProvider.overrideWithValue(
        UserPermissions(
          role: ErpRole.superAdmin,
          permissionSet: PermissionSet.all(),
        ),
      ),
      planCapabilityCeilingProvider.overrideWithValue(ceiling),
    ],
    child: MaterialApp(
      theme: AksharaAppTheme.light(),
      home: home,
    ),
  );
}

void main() {
  // DIREC-1: entitlement-gated Director sub-route shows the locked upgrade view.
  testWidgets(
      'DIREC-1 · gated Director sub-route renders PlanLockedModuleView when not entitled',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Drive the real route builder through a minimal GoRouter so we prove the
    // builder itself wraps the screen in the entitlement gate.
    final router = GoRouter(
      initialLocation: '/director/compliance',
      routes: [
        GoRoute(
          path: '/director/compliance',
          builder: directorComplianceRouteBuilder,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planCapabilityCeilingProvider.overrideWithValue(_trialCeiling),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(
          theme: AksharaAppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlanLockedModuleView), findsOneWidget);
    expect(find.byType(DirectorComplianceScreen), findsNothing);
    expect(find.text('Upgrade on WhatsApp'), findsOneWidget);
  });

  // DIREC-2: AI executive summary failure surfaces an error snackbar.
  testWidgets(
      'DIREC-2 · generate executive summary shows an error snackbar on failure',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(await _scope(
      home: const DirectorReportsScreen(),
      prefs: prefs,
      ceiling: _enterpriseCeiling,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate AI Executive Summary'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not generate executive summary'),
      findsOneWidget,
    );
  });

  // DIREC-3: compliance acknowledge failure surfaces an error snackbar.
  testWidgets(
      'DIREC-3 · acknowledge compliance shows an error snackbar on failure',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Phone-sized window forces the fully-laid-out card layout (the data-table
    // path virtualizes rows, which can leave the action button unlaid-out).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _scope(
      home: const DirectorComplianceScreen(),
      prefs: prefs,
      ceiling: _enterpriseCeiling,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Acknowledge').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not acknowledge compliance item'),
      findsOneWidget,
    );
  });
}
