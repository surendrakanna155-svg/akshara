import 'package:flutter/material.dart';

import '../../../features/director/director_models.dart';
import '../../ai/ai_inference_models.dart';
import '../../ai/ai_inference_pipeline.dart';
import '../interfaces/director_repository.dart';
import '../repository_query.dart';

class MockDirectorRepository implements DirectorRepository {
  MockDirectorRepository({required AiInferencePipeline pipeline})
      : _pipeline = pipeline;

  final AiInferencePipeline _pipeline;

  static final List<DirectorSchoolRow> _schools = [
    const DirectorSchoolRow(
      schoolId: 'DR-SCH-001',
      schoolName: 'Akshara North Campus',
      location: 'Hyderabad',
      students: 2140,
      revenueCr: 3.2,
      admissionsQtd: 128,
      feeCollectionPercent: 94,
      healthScore: 91,
      status: DirectorSchoolStatus.topPerformer,
    ),
    const DirectorSchoolRow(
      schoolId: 'DR-SCH-002',
      schoolName: 'Akshara East Campus',
      location: 'Warangal',
      students: 1670,
      revenueCr: 2.4,
      admissionsQtd: 96,
      feeCollectionPercent: 88,
      healthScore: 78,
      status: DirectorSchoolStatus.onTrack,
    ),
    const DirectorSchoolRow(
      schoolId: 'DR-SCH-003',
      schoolName: 'Akshara Central Campus',
      location: 'Vijayawada',
      students: 1420,
      revenueCr: 1.9,
      admissionsQtd: 72,
      feeCollectionPercent: 81,
      healthScore: 66,
      status: DirectorSchoolStatus.atRisk,
    ),
    const DirectorSchoolRow(
      schoolId: 'DR-SCH-004',
      schoolName: 'Akshara South Campus',
      location: 'Tirupati',
      students: 980,
      revenueCr: 1.2,
      admissionsQtd: 44,
      feeCollectionPercent: 73,
      healthScore: 54,
      status: DirectorSchoolStatus.critical,
    ),
  ];

  static List<DirectorTrendPoint> _monthlyTrend({
    required List<double> values,
  }) {
    const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    return List<DirectorTrendPoint>.generate(
      labels.length,
      (index) => DirectorTrendPoint(label: labels[index], value: values[index]),
      growable: false,
    );
  }

  static List<DirectorComplianceItem> _complianceItems = [
    DirectorComplianceItem(
      id: 'cmp-1',
      schoolName: 'Akshara Central Campus',
      category: 'Data privacy',
      requirement: 'Annual data processing policy attestation',
      status: DirectorComplianceStatus.overdue,
      dueDate: DateTime(2026, 6, 10),
      owner: 'Compliance Officer',
      evidenceUploaded: false,
      acknowledged: false,
    ),
    DirectorComplianceItem(
      id: 'cmp-2',
      schoolName: 'Akshara South Campus',
      category: 'Safety inspection',
      requirement: 'Fire NOC renewal',
      status: DirectorComplianceStatus.dueSoon,
      dueDate: DateTime(2026, 6, 20),
      owner: 'Campus Admin',
      evidenceUploaded: true,
      acknowledged: false,
    ),
    DirectorComplianceItem(
      id: 'cmp-3',
      schoolName: 'Akshara North Campus',
      category: 'Financial audit',
      requirement: 'Quarterly internal audit report',
      status: DirectorComplianceStatus.compliant,
      dueDate: DateTime(2026, 7, 15),
      owner: 'Finance Lead',
      evidenceUploaded: true,
      acknowledged: true,
    ),
  ];

  @override
  Future<DirectorDashboardData> getExecutiveDashboard({
    required RepositoryQuery query,
  }) async {
    return DirectorDashboardData(
      kpis: const [
        DirectorKpi(
          id: 'schools',
          label: 'Total Schools',
          value: '4',
          icon: Icons.domain_outlined,
        ),
        DirectorKpi(
          id: 'students',
          label: 'Total Students',
          value: '6,210',
          icon: Icons.groups_outlined,
        ),
        DirectorKpi(
          id: 'revenue',
          label: 'Combined Revenue',
          value: '8.7 Cr',
          icon: Icons.currency_rupee_outlined,
        ),
        DirectorKpi(
          id: 'admissions',
          label: 'New Admissions QTD',
          value: '340',
          icon: Icons.school_outlined,
        ),
        DirectorKpi(
          id: 'risk',
          label: 'Schools at Risk',
          value: '2',
          icon: Icons.warning_amber_outlined,
        ),
      ],
      schoolRows: _schools,
      revenue: await getRevenueOverview(query: query),
      growth: await getGrowthAnalytics(query: query),
      marketing: await getMarketingPerformance(query: query),
      admissions: await getAdmissionsPerformance(query: query),
      complianceAlerts: await getComplianceMonitoring(query: query),
      executiveSummary: await generateExecutiveSummary(
        query: query,
        focusArea: 'dashboard',
      ),
    );
  }

  @override
  Future<List<DirectorSchoolRow>> getMultiSchoolOverview({
    required RepositoryQuery query,
  }) async {
    return _schools;
  }

  @override
  Future<DirectorGrowthSnapshot> getPortfolioAnalytics({
    required RepositoryQuery query,
  }) async {
    return getGrowthAnalytics(query: query);
  }

  @override
  Future<DirectorRevenueSnapshot> getRevenueOverview({
    required RepositoryQuery query,
  }) async {
    return DirectorRevenueSnapshot(
      chainRevenueCr: 8.7,
      expensesCr: 5.4,
      netCr: 3.3,
      marginPercent: 38,
      forecastCr: 9.4,
      revenueBySchool: _schools,
      revenueTrend: _monthlyTrend(values: [6.9, 7.2, 7.4, 7.8, 8.2, 8.7]),
    );
  }

  @override
  Future<DirectorGrowthSnapshot> getGrowthAnalytics({
    required RepositoryQuery query,
  }) async {
    return DirectorGrowthSnapshot(
      yoyGrowthPercent: 16,
      newEnrollments: 512,
      withdrawals: 172,
      netGrowth: 340,
      capacityPercent: 84,
      enrollmentTrend:
          _monthlyTrend(values: [5800, 5890, 5950, 6020, 6115, 6210]),
      retentionTrend: _monthlyTrend(values: [92, 91, 92, 93, 93, 94]),
    );
  }

  @override
  Future<DirectorMarketingSnapshot> getMarketingPerformance({
    required RepositoryQuery query,
  }) async {
    return const DirectorMarketingSnapshot(
      totalSpendLakhs: 24.0,
      totalLeads: 1220,
      cplInr: 1967,
      roiPercent: 142,
      channelPerformance: {
        'Digital': 156,
        'Referral': 172,
        'Events': 118,
        'Outdoor': 94,
      },
    );
  }

  @override
  Future<DirectorAdmissionsSnapshot> getAdmissionsPerformance({
    required RepositoryQuery query,
  }) async {
    return const DirectorAdmissionsSnapshot(
      inquiries: 1640,
      applications: 920,
      interviews: 610,
      enrolled: 340,
      conversionPercent: 37,
      bySchoolConversion: {
        'Akshara North Campus': 43,
        'Akshara East Campus': 39,
        'Akshara Central Campus': 34,
        'Akshara South Campus': 30,
      },
    );
  }

  @override
  Future<List<DirectorComplianceItem>> getComplianceMonitoring({
    required RepositoryQuery query,
  }) async {
    return _complianceItems;
  }

  @override
  Future<List<DirectorReportItem>> getStrategicReports({
    required RepositoryQuery query,
  }) async {
    return [
      DirectorReportItem(
        id: 'rpt-1',
        title: 'Executive Summary',
        description: 'Board-level strategic summary with key risks',
        lastGeneratedAt: DateTime(2026, 6, 12),
        fileType: 'PDF',
      ),
      DirectorReportItem(
        id: 'rpt-2',
        title: 'Revenue Analysis',
        description: 'Chain revenue, margin, fee collection and forecast',
        lastGeneratedAt: DateTime(2026, 6, 11),
        fileType: 'XLSX',
      ),
      DirectorReportItem(
        id: 'rpt-3',
        title: 'Compliance Status',
        description: 'Campus compliance checklist and overdue items',
        lastGeneratedAt: DateTime(2026, 6, 9),
        fileType: 'PDF',
      ),
    ];
  }

  @override
  Future<String> generateExecutiveSummary({
    required RepositoryQuery query,
    required String focusArea,
  }) async {
    final response = await _pipeline.complete(
      AiInferenceRequest(
        prompt:
            'Create a concise director executive summary for $focusArea using aggregated school portfolio metrics only.',
        taskType: aiTaskTypeName(AiInferenceTaskType.intelligenceCompute),
        systemPrompt:
            'You are an executive assistant for a school chain director. Never include student or parent PII.',
        context: {
          'focusArea': focusArea,
          'schools': _schools.length,
          'totalStudents':
              _schools.fold<int>(0, (sum, school) => sum + school.students),
        },
      ),
    );
    return response.content;
  }

  @override
  Future<DirectorComplianceItem> acknowledgeCompliance({
    required RepositoryQuery query,
    required String complianceId,
  }) async {
    _complianceItems = _complianceItems
        .map(
          (item) => item.id == complianceId
              ? DirectorComplianceItem(
                  id: item.id,
                  schoolName: item.schoolName,
                  category: item.category,
                  requirement: item.requirement,
                  status: item.status,
                  dueDate: item.dueDate,
                  owner: item.owner,
                  evidenceUploaded: item.evidenceUploaded,
                  acknowledged: true,
                )
              : item,
        )
        .toList(growable: false);
    return _complianceItems.firstWhere((item) => item.id == complianceId);
  }

  @override
  Future<String> exportReport({
    required RepositoryQuery query,
    required String reportId,
  }) async {
    return 'director-report-$reportId-${DateTime.now().millisecondsSinceEpoch}';
  }
}
