import '../../../../../features/management/management_models.dart';
import '../dto/management_enum_codec.dart';
import '../dto/management_responses_dto.dart';

/// Maps Management API DTOs to domain models.
class ManagementMapper {
  const ManagementMapper();

  ManagementDashboardData toDashboard(ManagementDashboardDto dto) {
    final raw = dto.raw;
    return ManagementDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      revenueTrend: _mapTrendPoints(
        raw['revenueTrend'] as List<dynamic>? ?? const [],
      ),
      expenseBreakdown: _mapSegments(
        raw['expenseBreakdown'] as List<dynamic>? ?? const [],
      ),
      approvalQueue: _mapApprovals(
        raw['approvalQueue'] as List<dynamic>? ?? const [],
      ),
      admissionsSnapshot: _mapAdmissionsSnapshot(
        raw['admissionsSnapshot'] as Map<String, dynamic>? ?? const {},
      ),
      feeSnapshot: _mapFeeSnapshot(
        raw['feeSnapshot'] as Map<String, dynamic>? ?? const {},
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  ManagementAnalyticsData toAnalytics(ManagementAnalyticsResponseDto dto) {
    final raw = dto.raw;
    return ManagementAnalyticsData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      enrollmentTrend: _mapTrendPoints(
        raw['enrollmentTrend'] as List<dynamic>? ?? const [],
      ),
      attendanceByClass: _mapSegments(
        raw['attendanceByClass'] as List<dynamic>? ?? const [],
      ),
      classSummary: _mapClassSummary(
        raw['classSummary'] as List<dynamic>? ?? const [],
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  ManagementAdmissionsFunnelData toAdmissionsFunnel(
    ManagementAdmissionsFunnelResponseDto dto,
  ) {
    final raw = dto.raw;
    return ManagementAdmissionsFunnelData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      funnelStages: _mapFunnelStages(
        raw['funnelStages'] as List<dynamic>? ?? const [],
      ),
      sourcePerformance: _mapSegments(
        raw['sourcePerformance'] as List<dynamic>? ?? const [],
      ),
      recentConversions: _mapRecentConversions(
        raw['recentConversions'] as List<dynamic>? ?? const [],
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
      admissionsReportsRoute: raw['admissionsReportsRoute'] as String? ?? '',
    );
  }

  ManagementFinancialHealthData toFinancialHealth(
    ManagementFinancialHealthResponseDto dto,
  ) {
    final raw = dto.raw;
    return ManagementFinancialHealthData(
      revenue: raw['revenue'] as String? ?? '',
      expenses: raw['expenses'] as String? ?? '',
      netProfit: raw['netProfit'] as String? ?? '',
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      plTrend: _mapTrendPoints(raw['plTrend'] as List<dynamic>? ?? const []),
      cashFlowTrend: _mapTrendPoints(
        raw['cashFlowTrend'] as List<dynamic>? ?? const [],
      ),
      drillLinks: _mapDrillLinks(
        raw['drillLinks'] as List<dynamic>? ?? const [],
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  ManagementAcademicHealthData toAcademicHealth(
    ManagementAcademicHealthResponseDto dto,
  ) {
    final raw = dto.raw;
    return ManagementAcademicHealthData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      metrics: _mapAcademicMetrics(
        raw['metrics'] as List<dynamic>? ?? const [],
      ),
      subjectPerformance: _mapSubjectPerformance(
        raw['subjectPerformance'] as List<dynamic>? ?? const [],
      ),
      atRiskStudents: _stringList(raw['atRiskStudents']),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  ManagementPerformanceData toSchoolPerformance(
    ManagementPerformanceResponseDto dto,
  ) {
    final raw = dto.raw;
    return ManagementPerformanceData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      classPerformance: _mapClassPerformance(
        raw['classPerformance'] as List<dynamic>? ?? const [],
      ),
      atRiskStudents: _stringList(raw['atRiskStudents']),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  ManagementTasksData toTasksAndApprovals(ManagementTasksResponseDto dto) {
    final raw = dto.raw;
    return ManagementTasksData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      approvals: _mapApprovals(raw['approvals'] as List<dynamic>? ?? const []),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  ManagementSettingsData toSettings(ManagementSettingsResponseDto dto) {
    final raw = dto.raw;
    return ManagementSettingsData(
      sections: _mapSettingsSections(
        raw['sections'] as List<dynamic>? ?? const [],
      ),
      academicYear: raw['academicYear'] as String? ?? '',
    );
  }

  List<ManagementKpi> _mapKpis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementKpi(
            id: item['id'] as String? ?? '',
            value: item['value'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: ManagementEnumCodec.iconForKpi(
              item['icon'] as String?,
              item['accentName'] as String?,
            ),
            accentName: item['accentName'] as String? ?? 'neutral',
            detail: item['detail'] as String?,
            drillRoute: item['drillRoute'] as String?,
          ),
    ];
  }

  List<ManagementTrendPoint> _mapTrendPoints(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementTrendPoint(
            label: item['label'] as String? ?? '',
            amountLakhs: (item['amountLakhs'] as num?)?.toDouble() ?? 0,
            targetLakhs: (item['targetLakhs'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<ManagementSegment> _mapSegments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementSegment(
            label: item['label'] as String? ?? '',
            value: (item['value'] as num?)?.toDouble() ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<ManagementApprovalItem> _mapApprovals(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementApprovalItem(
            id: item['id'] as String? ?? '',
            type: ManagementEnumCodec.parseApprovalType(
              item['type'] as String?,
            ),
            title: item['title'] as String? ?? '',
            requester: item['requester'] as String? ?? '',
            amount: item['amount'] as String? ?? '',
            dateLabel: item['dateLabel'] as String? ?? '',
            status: ManagementEnumCodec.parseApprovalStatus(
              item['status'] as String?,
            ),
            aiRecommendation: ManagementEnumCodec.parseAiRecommendation(
              item['aiRecommendation'] as String?,
            ),
            sourceModuleRoute: item['sourceModuleRoute'] as String? ?? '',
          ),
    ];
  }

  ManagementAdmissionsSnapshot _mapAdmissionsSnapshot(
    Map<String, dynamic> raw,
  ) {
    return ManagementAdmissionsSnapshot(
      leadsMtd: raw['leadsMtd'] as int? ?? 0,
      confirmed: raw['confirmed'] as int? ?? 0,
      joined: raw['joined'] as int? ?? 0,
      conversionRate: raw['conversionRate'] as String? ?? '',
      recentConversions: _mapRecentConversions(
        raw['recentConversions'] as List<dynamic>? ?? const [],
      ),
    );
  }

  ManagementFeeSnapshot _mapFeeSnapshot(Map<String, dynamic> raw) {
    return ManagementFeeSnapshot(
      collectedMtd: raw['collectedMtd'] as String? ?? '',
      outstanding: raw['outstanding'] as String? ?? '',
      collectionRate: raw['collectionRate'] as String? ?? '',
      defaulters: raw['defaulters'] as int? ?? 0,
    );
  }

  List<ManagementRecentConversion> _mapRecentConversions(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementRecentConversion(
            id: item['id'] as String? ?? '',
            leadName: item['leadName'] as String? ?? '',
            classLabel: item['classLabel'] as String? ?? '',
            source: item['source'] as String? ?? '',
            counselor: item['counselor'] as String? ?? '',
            stage: item['stage'] as String? ?? '',
            daysInPipeline: item['daysInPipeline'] as int? ?? 0,
          ),
    ];
  }

  List<ManagementClassSummaryRow> _mapClassSummary(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementClassSummaryRow(
            classLabel: item['classLabel'] as String? ?? '',
            students: item['students'] as int? ?? 0,
            attendancePercent: item['attendancePercent'] as String? ?? '',
            avgMarks: item['avgMarks'] as String? ?? '',
            feeCollectionPercent: item['feeCollectionPercent'] as String? ?? '',
            teachers: item['teachers'] as int? ?? 0,
          ),
    ];
  }

  List<ManagementFunnelStage> _mapFunnelStages(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementFunnelStage(
            label: item['label'] as String? ?? '',
            count: item['count'] as int? ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<ManagementFinanceDrillLink> _mapDrillLinks(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementFinanceDrillLink(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            subtitle: item['subtitle'] as String? ?? '',
            route: item['route'] as String? ?? '',
            metric: item['metric'] as String? ?? '',
          ),
    ];
  }

  List<ManagementAcademicMetric> _mapAcademicMetrics(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementAcademicMetric(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            value: item['value'] as String? ?? '',
            trend: item['trend'] as String? ?? '',
            accentName: item['accentName'] as String? ?? 'neutral',
          ),
    ];
  }

  List<ManagementSubjectPerformance> _mapSubjectPerformance(
    List<dynamic> items,
  ) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementSubjectPerformance(
            subject: item['subject'] as String? ?? '',
            passPercent: item['passPercent'] as String? ?? '',
            avgScore: item['avgScore'] as String? ?? '',
            atRiskCount: item['atRiskCount'] as int? ?? 0,
          ),
    ];
  }

  List<ManagementClassPerformanceRow> _mapClassPerformance(
    List<dynamic> items,
  ) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementClassPerformanceRow(
            classLabel: item['classLabel'] as String? ?? '',
            students: item['students'] as int? ?? 0,
            passPercent: item['passPercent'] as String? ?? '',
            avgMarks: item['avgMarks'] as String? ?? '',
            attendance: item['attendance'] as String? ?? '',
            disciplineScore: item['disciplineScore'] as String? ?? '',
            rank: item['rank'] as int? ?? 0,
          ),
    ];
  }

  List<ManagementSettingsSection> _mapSettingsSections(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementSettingsSection(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            items: _mapSettingItems(item['items'] as List<dynamic>? ?? const []),
          ),
    ];
  }

  List<ManagementSettingItem> _mapSettingItems(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ManagementSettingItem(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            value: item['value'] as String? ?? '',
            description: item['description'] as String? ?? '',
            editable: item['editable'] as bool? ?? false,
          ),
    ];
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item != null) '$item',
    ];
  }
}
