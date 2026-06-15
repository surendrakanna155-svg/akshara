import 'package:akshara_erp/core/repositories/interfaces/director_repository.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/director/director_dashboard_screen.dart';
import 'package:akshara_erp/features/director/director_models.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDirectorRepository implements DirectorRepository {
  @override
  Future<DirectorComplianceItem> acknowledgeCompliance({
    required RepositoryQuery query,
    required String complianceId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> exportReport({
    required RepositoryQuery query,
    required String reportId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> generateExecutiveSummary({
    required RepositoryQuery query,
    required String focusArea,
  }) async {
    return 'Executive summary from AI';
  }

  @override
  Future<DirectorAdmissionsSnapshot> getAdmissionsPerformance({
    required RepositoryQuery query,
  }) async {
    return const DirectorAdmissionsSnapshot(
      inquiries: 10,
      applications: 8,
      interviews: 5,
      enrolled: 3,
      conversionPercent: 30,
      bySchoolConversion: {},
    );
  }

  @override
  Future<List<DirectorComplianceItem>> getComplianceMonitoring({
    required RepositoryQuery query,
  }) async {
    return const [];
  }

  @override
  Future<DirectorDashboardData> getExecutiveDashboard({
    required RepositoryQuery query,
  }) async {
    return const DirectorDashboardData(
      kpis: [
        DirectorKpi(
          id: 'schools',
          label: 'Total Schools',
          value: '4',
          icon: Icons.domain_outlined,
        ),
      ],
      schoolRows: [
        DirectorSchoolRow(
          schoolId: 'd1',
          schoolName: 'Akshara North Campus',
          location: 'Hyderabad',
          students: 1200,
          revenueCr: 2.2,
          admissionsQtd: 58,
          feeCollectionPercent: 92,
          healthScore: 88,
          status: DirectorSchoolStatus.topPerformer,
        ),
      ],
      revenue: DirectorRevenueSnapshot(
        chainRevenueCr: 2.2,
        expensesCr: 1.1,
        netCr: 1.1,
        marginPercent: 50,
        forecastCr: 2.4,
        revenueBySchool: [],
        revenueTrend: [],
      ),
      growth: DirectorGrowthSnapshot(
        yoyGrowthPercent: 12,
        newEnrollments: 100,
        withdrawals: 20,
        netGrowth: 80,
        capacityPercent: 82,
        enrollmentTrend: [],
        retentionTrend: [],
      ),
      marketing: DirectorMarketingSnapshot(
        totalSpendLakhs: 8.0,
        totalLeads: 140,
        cplInr: 1800,
        roiPercent: 120,
        channelPerformance: {},
      ),
      admissions: DirectorAdmissionsSnapshot(
        inquiries: 120,
        applications: 80,
        interviews: 50,
        enrolled: 30,
        conversionPercent: 37,
        bySchoolConversion: {},
      ),
      complianceAlerts: [],
      executiveSummary: 'Executive summary from AI',
    );
  }

  @override
  Future<DirectorGrowthSnapshot> getGrowthAnalytics({
    required RepositoryQuery query,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<DirectorMarketingSnapshot> getMarketingPerformance({
    required RepositoryQuery query,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<DirectorSchoolRow>> getMultiSchoolOverview({
    required RepositoryQuery query,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<DirectorGrowthSnapshot> getPortfolioAnalytics({
    required RepositoryQuery query,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<DirectorRevenueSnapshot> getRevenueOverview({
    required RepositoryQuery query,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<DirectorReportItem>> getStrategicReports({
    required RepositoryQuery query,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('renders director dashboard and privacy banner', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          directorRepositoryProvider
              .overrideWithValue(_FakeDirectorRepository()),
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const DirectorDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Total Schools'), findsOneWidget);
    expect(find.text(kDirectorPrivacyBannerMessage), findsOneWidget);
    expect(find.text('Akshara North Campus'), findsOneWidget);
    expect(find.text('Director AI Assistant'), findsOneWidget);
    expect(find.byType(DirectorDashboardScreen), findsOneWidget);
    expect(RouteNames.directorDashboard, isNotEmpty);
  });
}
