import 'package:akshara_erp/core/repositories/api/management/dto/management_enum_codec.dart';
import 'package:akshara_erp/features/management/management_models.dart';

/// Builds API-shaped JSON envelopes from Management domain models for contract tests.
class ManagementFixtureBuilder {
  const ManagementFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> trendPoint(ManagementTrendPoint point) => {
        'label': point.label,
        'amountLakhs': point.amountLakhs,
        'targetLakhs': point.targetLakhs,
      };

  Map<String, dynamic> segment(ManagementSegment segment) => {
        'label': segment.label,
        'value': segment.value,
        'percent': segment.percent,
      };

  Map<String, dynamic> approvalItem(ManagementApprovalItem item) => {
        'id': item.id,
        'type': ManagementEnumCodec.approvalTypeToApi(item.type),
        'title': item.title,
        'requester': item.requester,
        'amount': item.amount,
        'dateLabel': item.dateLabel,
        'status': ManagementEnumCodec.approvalStatusToApi(item.status),
        'aiRecommendation':
            ManagementEnumCodec.aiRecommendationToApi(item.aiRecommendation),
        'sourceModuleRoute': item.sourceModuleRoute,
      };

  Map<String, dynamic> recentConversion(ManagementRecentConversion item) => {
        'id': item.id,
        'leadName': item.leadName,
        'classLabel': item.classLabel,
        'source': item.source,
        'counselor': item.counselor,
        'stage': item.stage,
        'daysInPipeline': item.daysInPipeline,
      };

  Map<String, dynamic> dashboardEnvelope(ManagementDashboardData data) {
    return envelope({
      'aiInsight': data.aiInsight,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'revenueTrend': [
        for (final point in data.revenueTrend) trendPoint(point),
      ],
      'expenseBreakdown': [
        for (final segment in data.expenseBreakdown) this.segment(segment),
      ],
      'approvalQueue': [
        for (final item in data.approvalQueue) approvalItem(item),
      ],
      'admissionsSnapshot': {
        'leadsMtd': data.admissionsSnapshot.leadsMtd,
        'confirmed': data.admissionsSnapshot.confirmed,
        'joined': data.admissionsSnapshot.joined,
        'conversionRate': data.admissionsSnapshot.conversionRate,
        'recentConversions': [
          for (final item in data.admissionsSnapshot.recentConversions)
            recentConversion(item),
        ],
      },
      'feeSnapshot': {
        'collectedMtd': data.feeSnapshot.collectedMtd,
        'outstanding': data.feeSnapshot.outstanding,
        'collectionRate': data.feeSnapshot.collectionRate,
        'defaulters': data.feeSnapshot.defaulters,
      },
    });
  }

  Map<String, dynamic> analyticsEnvelope(ManagementAnalyticsData data) {
    return envelope({
      'aiInsight': data.aiInsight,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'enrollmentTrend': [
        for (final point in data.enrollmentTrend) trendPoint(point),
      ],
      'attendanceByClass': [
        for (final segment in data.attendanceByClass) this.segment(segment),
      ],
      'classSummary': [
        for (final row in data.classSummary)
          {
            'classLabel': row.classLabel,
            'students': row.students,
            'attendancePercent': row.attendancePercent,
            'avgMarks': row.avgMarks,
            'feeCollectionPercent': row.feeCollectionPercent,
            'teachers': row.teachers,
          },
      ],
    });
  }

  Map<String, dynamic> admissionsFunnelEnvelope(
    ManagementAdmissionsFunnelData data,
  ) {
    return envelope({
      'aiInsight': data.aiInsight,
      'admissionsReportsRoute': data.admissionsReportsRoute,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'funnelStages': [
        for (final stage in data.funnelStages)
          {
            'label': stage.label,
            'count': stage.count,
            'percent': stage.percent,
          },
      ],
      'sourcePerformance': [
        for (final segment in data.sourcePerformance) this.segment(segment),
      ],
      'recentConversions': [
        for (final item in data.recentConversions) recentConversion(item),
      ],
    });
  }

  Map<String, dynamic> financialHealthEnvelope(
    ManagementFinancialHealthData data,
  ) {
    return envelope({
      'revenue': data.revenue,
      'expenses': data.expenses,
      'netProfit': data.netProfit,
      'aiInsight': data.aiInsight,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'plTrend': [for (final point in data.plTrend) trendPoint(point)],
      'cashFlowTrend': [
        for (final point in data.cashFlowTrend) trendPoint(point),
      ],
      'drillLinks': [
        for (final link in data.drillLinks)
          {
            'id': link.id,
            'title': link.title,
            'subtitle': link.subtitle,
            'route': link.route,
            'metric': link.metric,
          },
      ],
    });
  }

  Map<String, dynamic> academicHealthEnvelope(
    ManagementAcademicHealthData data,
  ) {
    return envelope({
      'aiInsight': data.aiInsight,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'metrics': [
        for (final metric in data.metrics)
          {
            'id': metric.id,
            'label': metric.label,
            'value': metric.value,
            'trend': metric.trend,
            'accentName': metric.accentName,
          },
      ],
      'subjectPerformance': [
        for (final subject in data.subjectPerformance)
          {
            'subject': subject.subject,
            'passPercent': subject.passPercent,
            'avgScore': subject.avgScore,
            'atRiskCount': subject.atRiskCount,
          },
      ],
      'atRiskStudents': data.atRiskStudents,
    });
  }

  Map<String, dynamic> schoolPerformanceEnvelope(
    ManagementPerformanceData data,
  ) {
    return envelope({
      'aiInsight': data.aiInsight,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'classPerformance': [
        for (final row in data.classPerformance)
          {
            'classLabel': row.classLabel,
            'students': row.students,
            'passPercent': row.passPercent,
            'avgMarks': row.avgMarks,
            'attendance': row.attendance,
            'disciplineScore': row.disciplineScore,
            'rank': row.rank,
          },
      ],
      'atRiskStudents': data.atRiskStudents,
    });
  }

  Map<String, dynamic> tasksEnvelope(ManagementTasksData data) {
    return envelope({
      'aiInsight': data.aiInsight,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'approvals': [
        for (final item in data.approvals) approvalItem(item),
      ],
    });
  }

  Map<String, dynamic> settingsEnvelope(ManagementSettingsData data) {
    return envelope({
      'academicYear': data.academicYear,
      'sections': [
        for (final section in data.sections)
          {
            'id': section.id,
            'title': section.title,
            'items': [
              for (final item in section.items)
                {
                  'id': item.id,
                  'label': item.label,
                  'value': item.value,
                  'description': item.description,
                  'editable': item.editable,
                },
            ],
          },
      ],
    });
  }
}
