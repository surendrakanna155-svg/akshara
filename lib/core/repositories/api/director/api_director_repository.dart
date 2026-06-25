import 'package:flutter/material.dart';

import '../../../../features/director/director_models.dart';
import '../../interfaces/director_repository.dart';
import '../../repository_query.dart';
import 'remote/director_remote_datasource.dart';

/// Live Director portal repository. Parses the org-scoped aggregate responses
/// from the backend into the domain models. KPI icons are resolved client-side
/// (the server sends id + label + value only — no Flutter types over the wire).
class ApiDirectorRepository implements DirectorRepository {
  ApiDirectorRepository({required DirectorRemoteDataSource remote})
      : _remote = remote;

  final DirectorRemoteDataSource _remote;

  // ─── primitives ───────────────────────────────────────────────────────────

  static String _str(Object? v) => v?.toString() ?? '';

  static int _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _double(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static bool _bool(Object? v) => v == true || v == 'true';

  static DateTime _date(Object? v) =>
      DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime(1970);

  static DirectorSchoolStatus _schoolStatus(Object? v) {
    switch (v?.toString()) {
      case 'topPerformer':
        return DirectorSchoolStatus.topPerformer;
      case 'atRisk':
        return DirectorSchoolStatus.atRisk;
      case 'critical':
        return DirectorSchoolStatus.critical;
      case 'onTrack':
      default:
        return DirectorSchoolStatus.onTrack;
    }
  }

  static DirectorComplianceStatus _complianceStatus(Object? v) {
    switch (v?.toString()) {
      case 'overdue':
        return DirectorComplianceStatus.overdue;
      case 'dueSoon':
        return DirectorComplianceStatus.dueSoon;
      case 'notApplicable':
        return DirectorComplianceStatus.notApplicable;
      case 'compliant':
      default:
        return DirectorComplianceStatus.compliant;
    }
  }

  static const Map<String, IconData> _kpiIcons = {
    'schools': Icons.domain_outlined,
    'students': Icons.groups_outlined,
    'revenue': Icons.currency_rupee_outlined,
    'admissions': Icons.school_outlined,
    'risk': Icons.warning_amber_outlined,
  };

  // ─── model mappers ────────────────────────────────────────────────────────

  static DirectorSchoolRow _school(Map<String, dynamic> m) => DirectorSchoolRow(
        schoolId: _str(m['schoolId']),
        schoolName: _str(m['schoolName']),
        location: _str(m['location']),
        students: _int(m['students']),
        revenueCr: _double(m['revenueCr']),
        admissionsQtd: _int(m['admissionsQtd']),
        feeCollectionPercent: _int(m['feeCollectionPercent']),
        healthScore: _int(m['healthScore']),
        status: _schoolStatus(m['status']),
      );

  static List<DirectorSchoolRow> _schools(Object? list) =>
      (list as List<dynamic>? ?? const [])
          .map((e) => _school(e as Map<String, dynamic>))
          .toList(growable: false);

  static DirectorTrendPoint _trend(Map<String, dynamic> m) => DirectorTrendPoint(
        label: _str(m['label']),
        value: _double(m['value']),
        target: m['target'] == null ? null : _double(m['target']),
      );

  static List<DirectorTrendPoint> _trends(Object? list) =>
      (list as List<dynamic>? ?? const [])
          .map((e) => _trend(e as Map<String, dynamic>))
          .toList(growable: false);

  static DirectorKpi _kpi(Map<String, dynamic> m) {
    final id = _str(m['id']);
    return DirectorKpi(
      id: id,
      label: _str(m['label']),
      value: _str(m['value']),
      icon: _kpiIcons[id] ?? Icons.insights_outlined,
      detail: m['detail'] == null ? null : _str(m['detail']),
    );
  }

  static DirectorRevenueSnapshot _revenue(Map<String, dynamic> m) =>
      DirectorRevenueSnapshot(
        chainRevenueCr: _double(m['chainRevenueCr']),
        expensesCr: _double(m['expensesCr']),
        netCr: _double(m['netCr']),
        marginPercent: _int(m['marginPercent']),
        forecastCr: _double(m['forecastCr']),
        revenueBySchool: _schools(m['revenueBySchool']),
        revenueTrend: _trends(m['revenueTrend']),
      );

  static DirectorGrowthSnapshot _growth(Map<String, dynamic> m) =>
      DirectorGrowthSnapshot(
        yoyGrowthPercent: _int(m['yoyGrowthPercent']),
        newEnrollments: _int(m['newEnrollments']),
        withdrawals: _int(m['withdrawals']),
        netGrowth: _int(m['netGrowth']),
        capacityPercent: _int(m['capacityPercent']),
        enrollmentTrend: _trends(m['enrollmentTrend']),
        retentionTrend: _trends(m['retentionTrend']),
      );

  static DirectorMarketingSnapshot _marketing(Map<String, dynamic> m) =>
      DirectorMarketingSnapshot(
        totalSpendLakhs: _double(m['totalSpendLakhs']),
        totalLeads: _int(m['totalLeads']),
        cplInr: _int(m['cplInr']),
        roiPercent: _int(m['roiPercent']),
        channelPerformance:
            (m['channelPerformance'] as Map<String, dynamic>? ?? const {})
                .map((key, value) => MapEntry(key, _double(value))),
      );

  static DirectorAdmissionsSnapshot _admissions(Map<String, dynamic> m) =>
      DirectorAdmissionsSnapshot(
        inquiries: _int(m['inquiries']),
        applications: _int(m['applications']),
        interviews: _int(m['interviews']),
        enrolled: _int(m['enrolled']),
        conversionPercent: _int(m['conversionPercent']),
        bySchoolConversion:
            (m['bySchoolConversion'] as Map<String, dynamic>? ?? const {})
                .map((key, value) => MapEntry(key, _int(value))),
      );

  static DirectorComplianceItem _compliance(Map<String, dynamic> m) =>
      DirectorComplianceItem(
        id: _str(m['id']),
        schoolName: _str(m['schoolName']),
        category: _str(m['category']),
        requirement: _str(m['requirement']),
        status: _complianceStatus(m['status']),
        dueDate: _date(m['dueDate']),
        owner: _str(m['owner']),
        evidenceUploaded: _bool(m['evidenceUploaded']),
        acknowledged: _bool(m['acknowledged']),
      );

  static DirectorReportItem _report(Map<String, dynamic> m) => DirectorReportItem(
        id: _str(m['id']),
        title: _str(m['title']),
        description: _str(m['description']),
        lastGeneratedAt: _date(m['lastGeneratedAt']),
        fileType: _str(m['fileType']),
      );

  static DirectorMetricInput _metricInput(Map<String, dynamic> m) =>
      DirectorMetricInput(
        id: _str(m['id']),
        schoolId: _str(m['schoolId']),
        schoolName: _str(m['schoolName']),
        periodMonth: _str(m['periodMonth']),
        marketingSpendInr: _double(m['marketingSpendInr']),
        operatingExpenseInr: _double(m['operatingExpenseInr']),
        studentCapacity: _int(m['studentCapacity']),
      );

  static DirectorBoardPack _boardPack(Map<String, dynamic> m) {
    final revenue = m['revenue'] as Map<String, dynamic>? ?? const {};
    final growth = m['growth'] as Map<String, dynamic>? ?? const {};
    final admissions = m['admissions'] as Map<String, dynamic>? ?? const {};
    final marketing = m['marketing'] as Map<String, dynamic>? ?? const {};
    final compliance = m['compliance'] as Map<String, dynamic>? ?? const {};
    return DirectorBoardPack(
      reportId: _str(m['reportId']),
      title: _str(m['title']),
      description: _str(m['description']),
      fileType: _str(m['fileType']),
      generatedAt: _date(m['generatedAt']),
      executiveSummary: _str(m['executiveSummary']),
      kpis: (m['kpis'] as List<dynamic>? ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .map((e) => DirectorBoardPackKpi(
                label: _str(e['label']),
                value: _str(e['value']),
              ))
          .toList(growable: false),
      schools: _schools(m['schools']),
      chainRevenueCr: _double(revenue['chainRevenueCr']),
      expensesCr: _double(revenue['expensesCr']),
      netCr: _double(revenue['netCr']),
      marginPercent: _int(revenue['marginPercent']),
      forecastCr: _double(revenue['forecastCr']),
      yoyGrowthPercent: _int(growth['yoyGrowthPercent']),
      netGrowth: _int(growth['netGrowth']),
      capacityPercent: _int(growth['capacityPercent']),
      inquiries: _int(admissions['inquiries']),
      enrolled: _int(admissions['enrolled']),
      conversionPercent: _int(admissions['conversionPercent']),
      totalSpendLakhs: _double(marketing['totalSpendLakhs']),
      totalLeads: _int(marketing['totalLeads']),
      roiPercent: _int(marketing['roiPercent']),
      complianceTotal: _int(compliance['total']),
      complianceOverdue: _int(compliance['overdue']),
    );
  }

  // ─── interface ────────────────────────────────────────────────────────────

  @override
  Future<DirectorDashboardData> getExecutiveDashboard({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchDashboard(query: query);
    return DirectorDashboardData(
      kpis: (data['kpis'] as List<dynamic>? ?? const [])
          .map((e) => _kpi(e as Map<String, dynamic>))
          .toList(growable: false),
      schoolRows: _schools(data['schoolRows']),
      revenue: _revenue(data['revenue'] as Map<String, dynamic>? ?? const {}),
      growth: _growth(data['growth'] as Map<String, dynamic>? ?? const {}),
      marketing:
          _marketing(data['marketing'] as Map<String, dynamic>? ?? const {}),
      admissions:
          _admissions(data['admissions'] as Map<String, dynamic>? ?? const {}),
      complianceAlerts: (data['complianceAlerts'] as List<dynamic>? ?? const [])
          .map((e) => _compliance(e as Map<String, dynamic>))
          .toList(growable: false),
      executiveSummary: _str(data['executiveSummary']),
    );
  }

  @override
  Future<List<DirectorSchoolRow>> getMultiSchoolOverview({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchSchools(query: query);
    return rows.map(_school).toList(growable: false);
  }

  @override
  Future<DirectorGrowthSnapshot> getPortfolioAnalytics({
    required RepositoryQuery query,
  }) async {
    return _growth(await _remote.fetchPortfolio(query: query));
  }

  @override
  Future<DirectorRevenueSnapshot> getRevenueOverview({
    required RepositoryQuery query,
  }) async {
    return _revenue(await _remote.fetchRevenue(query: query));
  }

  @override
  Future<DirectorGrowthSnapshot> getGrowthAnalytics({
    required RepositoryQuery query,
  }) async {
    return _growth(await _remote.fetchGrowth(query: query));
  }

  @override
  Future<DirectorMarketingSnapshot> getMarketingPerformance({
    required RepositoryQuery query,
  }) async {
    return _marketing(await _remote.fetchMarketing(query: query));
  }

  @override
  Future<DirectorAdmissionsSnapshot> getAdmissionsPerformance({
    required RepositoryQuery query,
  }) async {
    return _admissions(await _remote.fetchAdmissions(query: query));
  }

  @override
  Future<List<DirectorComplianceItem>> getComplianceMonitoring({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchCompliance(query: query);
    return rows.map(_compliance).toList(growable: false);
  }

  @override
  Future<List<DirectorReportItem>> getStrategicReports({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchReports(query: query);
    return rows.map(_report).toList(growable: false);
  }

  @override
  Future<String> generateExecutiveSummary({
    required RepositoryQuery query,
    required String focusArea,
  }) async {
    return _remote.generateSummary(query: query, focusArea: focusArea);
  }

  @override
  Future<DirectorComplianceItem> acknowledgeCompliance({
    required RepositoryQuery query,
    required String complianceId,
  }) async {
    final data = await _remote.acknowledgeCompliance(
      query: query,
      complianceId: complianceId,
    );
    return _compliance(data);
  }

  @override
  Future<List<DirectorMetricInput>> getMetricInputs({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchMetricInputs(query: query);
    return rows.map(_metricInput).toList(growable: false);
  }

  @override
  Future<DirectorMetricInput> saveMetricInput({
    required RepositoryQuery query,
    required DirectorMetricInputDraft draft,
  }) async {
    final data = await _remote.saveMetricInput(
      query: query,
      body: draft.toJson(),
    );
    return _metricInput(data);
  }

  @override
  Future<DirectorBoardPack> exportReport({
    required RepositoryQuery query,
    required String reportId,
  }) async {
    final data = await _remote.exportReport(query: query, reportId: reportId);
    return _boardPack(data);
  }
}
