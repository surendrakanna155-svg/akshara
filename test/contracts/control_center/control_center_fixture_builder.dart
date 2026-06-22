import 'package:akshara_erp/core/repositories/api/control_center/dto/control_center_enum_codec.dart';
import 'package:akshara_erp/features/platform/control_center/control_center_models.dart';

/// Builds API-shaped JSON envelopes from Control Center domain models for contract tests.
class ControlCenterFixtureBuilder {
  const ControlCenterFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> trendPoint(ControlCenterTrendPoint point) => {
        'label': point.label,
        'amountLakhs': point.amountLakhs,
        'targetLakhs': point.targetLakhs,
      };

  Map<String, dynamic> segment(ControlCenterSegment segment) => {
        'label': segment.label,
        'value': segment.value,
        'percent': segment.percent,
      };

  Map<String, dynamic> schoolItem(PlatformSchool school) => {
        'id': school.id,
        'name': school.name,
        'plan': ControlCenterEnumCodec.subscriptionPlanToApi(school.plan),
        'studentCount': school.studentCount,
        'status': ControlCenterEnumCodec.schoolStatusToApi(school.status),
        'createdDate': school.createdDate,
        'mrrLakhs': school.mrrLakhs,
        'healthScore': school.healthScore,
        'region': school.region,
        'tenantId': school.tenantId,
      };

  Map<String, dynamic> supportTicketItem(SupportTicket ticket) => {
        'id': ticket.id,
        'subject': ticket.subject,
        'schoolName': ticket.schoolName,
        'status': ControlCenterEnumCodec.ticketStatusToApi(ticket.status),
        'priority': ticket.priority,
        'slaRemaining': ticket.slaRemaining,
        'assignee': ticket.assignee,
        'createdDate': ticket.createdDate,
      };

  Map<String, dynamic> whiteLabelItem(WhiteLabelConfig config) => {
        'schoolId': config.schoolId,
        'schoolName': config.schoolName,
        'logoUrl': config.logoUrl,
        'primaryColorHex': config.primaryColorHex,
        'customDomain': config.customDomain,
        'loginBackgroundUrl': config.loginBackgroundUrl,
        'isPublished': config.isPublished,
      };

  Map<String, dynamic> dashboardEnvelope(ControlCenterDashboardData data) {
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
      'schoolGrowthTrend': [
        for (final point in data.schoolGrowthTrend) trendPoint(point),
      ],
      'revenueTrend': [
        for (final point in data.revenueTrend) trendPoint(point),
      ],
      'planDistribution': [
        for (final segment in data.planDistribution) this.segment(segment),
      ],
      'expiringSchools': data.expiringSchools,
      'erpModules': [
        for (final module in data.erpModules)
          {
            'module': ControlCenterEnumCodec.erpModuleIdToApi(module.module),
            'label': module.label,
            'route': module.route,
            'schoolCount': module.schoolCount,
            'adoptionPercent': module.adoptionPercent,
          },
      ],
    });
  }

  Map<String, dynamic> subscriptionsEnvelope(
    ControlCenterSubscriptionsData data,
  ) {
    return envelope({
      'expiringCount': data.expiringCount,
      'renewalRatePercent': data.renewalRatePercent,
      'plans': [
        for (final plan in data.plans)
          {
            'plan': ControlCenterEnumCodec.subscriptionPlanToApi(plan.plan),
            'monthlyPriceLakhs': plan.monthlyPriceLakhs,
            'schoolCount': plan.schoolCount,
            'features': plan.features,
            'dedicatedDb': plan.dedicatedDb,
          },
      ],
      'planDistribution': [
        for (final segment in data.planDistribution) this.segment(segment),
      ],
    });
  }

  Map<String, dynamic> billingEnvelope(ControlCenterBillingData data) {
    return envelope({
      'mrrLakhs': data.mrrLakhs,
      'arrLakhs': data.arrLakhs,
      'outstandingLakhs': data.outstandingLakhs,
      'invoices': [
        for (final invoice in data.invoices)
          {
            'id': invoice.id,
            'schoolName': invoice.schoolName,
            'amountLakhs': invoice.amountLakhs,
            'dueDate': invoice.dueDate,
            'status': invoice.status,
            'plan': ControlCenterEnumCodec.subscriptionPlanToApi(invoice.plan),
          },
      ],
      'revenueTrend': [
        for (final point in data.revenueTrend) trendPoint(point),
      ],
      'revenueByPlan': [
        for (final segment in data.revenueByPlan) this.segment(segment),
      ],
    });
  }

  Map<String, dynamic> crmEnvelope(ControlCenterCrmData data) {
    return envelope({
      'pipelineValueLakhs': data.pipelineValueLakhs,
      'winRatePercent': data.winRatePercent,
      'deals': [
        for (final deal in data.deals)
          {
            'id': deal.id,
            'schoolName': deal.schoolName,
            'contactName': deal.contactName,
            'stage': ControlCenterEnumCodec.crmStageToApi(deal.stage),
            'estimatedMrrLakhs': deal.estimatedMrrLakhs,
            'owner': deal.owner,
            'lastActivity': deal.lastActivity,
          },
      ],
      'stageDistribution': [
        for (final segment in data.stageDistribution) this.segment(segment),
      ],
    });
  }

  Map<String, dynamic> customerSuccessEnvelope(ControlCenterSuccessData data) {
    return envelope({
      'atRiskCount': data.atRiskCount,
      'avgAdoptionScore': data.avgAdoptionScore,
      'aiInsight': data.aiInsight,
      'schools': [
        for (final school in data.schools)
          {
            'schoolId': school.schoolId,
            'schoolName': school.schoolName,
            'adoptionScore': school.adoptionScore,
            'renewalProbability': school.renewalProbability,
            'churnRisk': school.churnRisk,
            'csOwner': school.csOwner,
            'lowUsageModules': school.lowUsageModules,
          },
      ],
    });
  }

  Map<String, dynamic> analyticsEnvelope(ControlCenterAnalyticsData data) {
    return envelope({
      'schoolGrowthTrend': [
        for (final point in data.schoolGrowthTrend) trendPoint(point),
      ],
      'studentGrowthTrend': [
        for (final point in data.studentGrowthTrend) trendPoint(point),
      ],
      'moduleUsage': [
        for (final segment in data.moduleUsage) this.segment(segment),
      ],
      'marketingAttribution': [
        for (final segment in data.marketingAttribution) this.segment(segment),
      ],
    });
  }

  Map<String, dynamic> monitoringEnvelope(ControlCenterMonitoringData data) {
    return envelope({
      'errorRatePercent': data.errorRatePercent,
      'activeDeployments': data.activeDeployments,
      'featureFlags': data.featureFlags,
      'services': [
        for (final service in data.services)
          {
            'serviceName': service.serviceName,
            'status': ControlCenterEnumCodec.healthStatusToApi(service.status),
            'uptimePercent': service.uptimePercent,
            'lastIncident': service.lastIncident,
          },
      ],
    });
  }

  Map<String, dynamic> rolesEnvelope(ControlCenterRolesData data) {
    return envelope({
      'permissionGroups': data.permissionGroups,
      'roles': [
        for (final role in data.roles)
          {
            'id': role.id,
            'name': role.name,
            'description': role.description,
            'permissionCount': role.permissionCount,
            'userCount': role.userCount,
          },
      ],
    });
  }

  Map<String, dynamic> settingsEnvelope(ControlCenterSettingsData data) {
    return envelope({
      'maintenanceMode': data.maintenanceMode,
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
