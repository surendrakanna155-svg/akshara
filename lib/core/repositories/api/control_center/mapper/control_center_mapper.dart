import '../../../../../features/platform/control_center/control_center_models.dart';
import '../dto/control_center_enum_codec.dart';
import '../dto/control_center_responses_dto.dart';

/// Maps Control Center API DTOs to domain models.
class ControlCenterMapper {
  const ControlCenterMapper();

  ControlCenterDashboardData toDashboard(ControlCenterDashboardDto dto) {
    final raw = dto.raw;
    return ControlCenterDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      schoolGrowthTrend: _mapTrendPoints(
        raw['schoolGrowthTrend'] as List<dynamic>? ?? const [],
      ),
      revenueTrend: _mapTrendPoints(
        raw['revenueTrend'] as List<dynamic>? ?? const [],
      ),
      planDistribution: _mapSegments(
        raw['planDistribution'] as List<dynamic>? ?? const [],
      ),
      expiringSchools: _stringList(raw['expiringSchools']),
      erpModules: _mapErpModules(
        raw['erpModules'] as List<dynamic>? ?? const [],
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  List<PlatformSchool> toSchools(PlatformSchoolsResponseDto dto) {
    return [for (final item in dto.items) toSchool(item)];
  }

  PlatformSchool toSchool(PlatformSchoolDto dto) {
    final raw = dto.raw;
    return PlatformSchool(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      plan: ControlCenterEnumCodec.parseSubscriptionPlan(raw['plan'] as String?),
      studentCount: raw['studentCount'] as int? ?? 0,
      status: ControlCenterEnumCodec.parseSchoolStatus(raw['status'] as String?),
      createdDate: raw['createdDate'] as String? ?? '',
      mrrLakhs: (raw['mrrLakhs'] as num?)?.toDouble() ?? 0,
      healthScore: raw['healthScore'] as int? ?? 0,
      region: raw['region'] as String? ?? '',
      tenantId: raw['tenantId'] as String? ?? '',
    );
  }

  ControlCenterSubscriptionsData toSubscriptions(
    ControlCenterSubscriptionsResponseDto dto,
  ) {
    final raw = dto.raw;
    return ControlCenterSubscriptionsData(
      plans: _mapSubscriptionPlans(raw['plans'] as List<dynamic>? ?? const []),
      expiringCount: raw['expiringCount'] as int? ?? 0,
      renewalRatePercent: raw['renewalRatePercent'] as int? ?? 0,
      planDistribution: _mapSegments(
        raw['planDistribution'] as List<dynamic>? ?? const [],
      ),
    );
  }

  ControlCenterBillingData toBilling(ControlCenterBillingResponseDto dto) {
    final raw = dto.raw;
    return ControlCenterBillingData(
      mrrLakhs: (raw['mrrLakhs'] as num?)?.toDouble() ?? 0,
      arrLakhs: (raw['arrLakhs'] as num?)?.toDouble() ?? 0,
      outstandingLakhs: (raw['outstandingLakhs'] as num?)?.toDouble() ?? 0,
      invoices: _mapInvoices(raw['invoices'] as List<dynamic>? ?? const []),
      revenueTrend: _mapTrendPoints(
        raw['revenueTrend'] as List<dynamic>? ?? const [],
      ),
      revenueByPlan: _mapSegments(
        raw['revenueByPlan'] as List<dynamic>? ?? const [],
      ),
    );
  }

  ControlCenterCrmData toCrmPipeline(ControlCenterCrmResponseDto dto) {
    final raw = dto.raw;
    return ControlCenterCrmData(
      deals: _mapDeals(raw['deals'] as List<dynamic>? ?? const []),
      pipelineValueLakhs: (raw['pipelineValueLakhs'] as num?)?.toDouble() ?? 0,
      winRatePercent: raw['winRatePercent'] as int? ?? 0,
      stageDistribution: _mapSegments(
        raw['stageDistribution'] as List<dynamic>? ?? const [],
      ),
    );
  }

  List<SupportTicket> toSupportTickets(SupportTicketsResponseDto dto) {
    return [for (final item in dto.items) toSupportTicket(item)];
  }

  SupportTicket toSupportTicket(SupportTicketDto dto) {
    final raw = dto.raw;
    return SupportTicket(
      id: raw['id'] as String? ?? '',
      subject: raw['subject'] as String? ?? '',
      schoolName: raw['schoolName'] as String? ?? '',
      status: ControlCenterEnumCodec.parseTicketStatus(raw['status'] as String?),
      priority: raw['priority'] as String? ?? '',
      slaRemaining: raw['slaRemaining'] as String? ?? '',
      assignee: raw['assignee'] as String? ?? '',
      createdDate: raw['createdDate'] as String? ?? '',
    );
  }

  ControlCenterSuccessData toCustomerSuccess(
    ControlCenterSuccessResponseDto dto,
  ) {
    final raw = dto.raw;
    return ControlCenterSuccessData(
      schools: _mapCustomerSuccessSchools(
        raw['schools'] as List<dynamic>? ?? const [],
      ),
      atRiskCount: raw['atRiskCount'] as int? ?? 0,
      avgAdoptionScore: raw['avgAdoptionScore'] as int? ?? 0,
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  List<WhiteLabelConfig> toWhiteLabelConfigs(
    WhiteLabelConfigsResponseDto dto,
  ) {
    return [for (final item in dto.items) toWhiteLabelConfig(item)];
  }

  WhiteLabelConfig toWhiteLabelConfig(WhiteLabelConfigDto dto) {
    final raw = dto.raw;
    return WhiteLabelConfig(
      schoolId: raw['schoolId'] as String? ?? '',
      schoolName: raw['schoolName'] as String? ?? '',
      logoUrl: raw['logoUrl'] as String? ?? '',
      primaryColorHex: raw['primaryColorHex'] as String? ?? '',
      customDomain: raw['customDomain'] as String? ?? '',
      loginBackgroundUrl: raw['loginBackgroundUrl'] as String? ?? '',
      isPublished: raw['isPublished'] as bool? ?? false,
    );
  }

  ControlCenterAnalyticsData toAnalytics(
    ControlCenterAnalyticsResponseDto dto,
  ) {
    final raw = dto.raw;
    return ControlCenterAnalyticsData(
      schoolGrowthTrend: _mapTrendPoints(
        raw['schoolGrowthTrend'] as List<dynamic>? ?? const [],
      ),
      studentGrowthTrend: _mapTrendPoints(
        raw['studentGrowthTrend'] as List<dynamic>? ?? const [],
      ),
      moduleUsage: _mapSegments(
        raw['moduleUsage'] as List<dynamic>? ?? const [],
      ),
      marketingAttribution: _mapSegments(
        raw['marketingAttribution'] as List<dynamic>? ?? const [],
      ),
    );
  }

  ControlCenterMonitoringData toMonitoring(
    ControlCenterMonitoringResponseDto dto,
  ) {
    final raw = dto.raw;
    return ControlCenterMonitoringData(
      services: _mapServices(raw['services'] as List<dynamic>? ?? const []),
      errorRatePercent: (raw['errorRatePercent'] as num?)?.toDouble() ?? 0,
      activeDeployments: raw['activeDeployments'] as int? ?? 0,
      featureFlags: _stringList(raw['featureFlags']),
    );
  }

  ControlCenterRolesData toRoles(ControlCenterRolesResponseDto dto) {
    final raw = dto.raw;
    return ControlCenterRolesData(
      roles: _mapRoles(raw['roles'] as List<dynamic>? ?? const []),
      permissionGroups: _stringList(raw['permissionGroups']),
    );
  }

  ControlCenterSettingsData toSettings(ControlCenterSettingsResponseDto dto) {
    final raw = dto.raw;
    return ControlCenterSettingsData(
      sections: _mapSettingsSections(
        raw['sections'] as List<dynamic>? ?? const [],
      ),
      maintenanceMode: raw['maintenanceMode'] as bool? ?? false,
    );
  }

  List<ControlCenterKpi> _mapKpis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ControlCenterKpi(
            id: item['id'] as String? ?? '',
            value: item['value'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: ControlCenterEnumCodec.iconForKpi(
              item['icon'] as String?,
              item['accentName'] as String?,
            ),
            accentName: item['accentName'] as String? ?? 'neutral',
            detail: item['detail'] as String?,
          ),
    ];
  }

  List<ControlCenterTrendPoint> _mapTrendPoints(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ControlCenterTrendPoint(
            label: item['label'] as String? ?? '',
            amountLakhs: (item['amountLakhs'] as num?)?.toDouble() ?? 0,
            targetLakhs: (item['targetLakhs'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<ControlCenterSegment> _mapSegments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ControlCenterSegment(
            label: item['label'] as String? ?? '',
            value: (item['value'] as num?)?.toDouble() ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<ErpModuleReference> _mapErpModules(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ErpModuleReference(
            module: ControlCenterEnumCodec.parseErpModuleId(
              item['module'] as String?,
            ),
            label: item['label'] as String? ?? '',
            route: item['route'] as String? ?? '',
            schoolCount: item['schoolCount'] as int? ?? 0,
            adoptionPercent: item['adoptionPercent'] as int? ?? 0,
          ),
    ];
  }

  List<SubscriptionPlanInfo> _mapSubscriptionPlans(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          SubscriptionPlanInfo(
            plan: ControlCenterEnumCodec.parseSubscriptionPlan(
              item['plan'] as String?,
            ),
            monthlyPriceLakhs:
                (item['monthlyPriceLakhs'] as num?)?.toDouble() ?? 0,
            schoolCount: item['schoolCount'] as int? ?? 0,
            features: _stringList(item['features']),
            dedicatedDb: item['dedicatedDb'] as bool? ?? false,
          ),
    ];
  }

  List<BillingInvoice> _mapInvoices(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          BillingInvoice(
            id: item['id'] as String? ?? '',
            schoolName: item['schoolName'] as String? ?? '',
            amountLakhs: (item['amountLakhs'] as num?)?.toDouble() ?? 0,
            dueDate: item['dueDate'] as String? ?? '',
            status: item['status'] as String? ?? '',
            plan: ControlCenterEnumCodec.parseSubscriptionPlan(
              item['plan'] as String?,
            ),
          ),
    ];
  }

  List<CrmDeal> _mapDeals(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          CrmDeal(
            id: item['id'] as String? ?? '',
            schoolName: item['schoolName'] as String? ?? '',
            contactName: item['contactName'] as String? ?? '',
            stage: ControlCenterEnumCodec.parseCrmStage(item['stage'] as String?),
            estimatedMrrLakhs:
                (item['estimatedMrrLakhs'] as num?)?.toDouble() ?? 0,
            owner: item['owner'] as String? ?? '',
            lastActivity: item['lastActivity'] as String? ?? '',
          ),
    ];
  }

  List<CustomerSuccessSchool> _mapCustomerSuccessSchools(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          CustomerSuccessSchool(
            schoolId: item['schoolId'] as String? ?? '',
            schoolName: item['schoolName'] as String? ?? '',
            adoptionScore: item['adoptionScore'] as int? ?? 0,
            renewalProbability: item['renewalProbability'] as int? ?? 0,
            churnRisk: item['churnRisk'] as bool? ?? false,
            csOwner: item['csOwner'] as String? ?? '',
            lowUsageModules: _stringList(item['lowUsageModules']),
          ),
    ];
  }

  List<PlatformServiceHealth> _mapServices(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          PlatformServiceHealth(
            serviceName: item['serviceName'] as String? ?? '',
            status: ControlCenterEnumCodec.parseHealthStatus(
              item['status'] as String?,
            ),
            uptimePercent: item['uptimePercent'] as String? ?? '',
            lastIncident: item['lastIncident'] as String? ?? '',
          ),
    ];
  }

  List<PlatformRole> _mapRoles(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          PlatformRole(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            description: item['description'] as String? ?? '',
            permissionCount: item['permissionCount'] as int? ?? 0,
            userCount: item['userCount'] as int? ?? 0,
          ),
    ];
  }

  List<ControlCenterSettingsSection> _mapSettingsSections(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ControlCenterSettingsSection(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            items: _mapSettingItems(item['items'] as List<dynamic>? ?? const []),
          ),
    ];
  }

  List<ControlCenterSettingItem> _mapSettingItems(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ControlCenterSettingItem(
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
