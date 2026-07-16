import 'package:flutter/material.dart';

import '../../../features/platform/control_center/control_center_models.dart';
import '../../../features/platform/control_center/control_center_requests.dart';
import '../../../router/route_names.dart';
import '../interfaces/control_center_repository.dart';
import '../paginated_result.dart';
import '../pagination_helpers.dart';
import '../repository_query.dart';
import 'mock_control_center_write_store.dart';

class MockControlCenterRepository implements ControlCenterRepository {
  static const _schoolGrowthTrend = [
    ControlCenterTrendPoint(label: 'Jan', amountLakhs: 38, targetLakhs: 40),
    ControlCenterTrendPoint(label: 'Feb', amountLakhs: 39, targetLakhs: 41),
    ControlCenterTrendPoint(label: 'Mar', amountLakhs: 41, targetLakhs: 42),
    ControlCenterTrendPoint(label: 'Apr', amountLakhs: 42, targetLakhs: 43),
    ControlCenterTrendPoint(label: 'May', amountLakhs: 44, targetLakhs: 44),
    ControlCenterTrendPoint(label: 'Jun', amountLakhs: 48, targetLakhs: 46),
  ];

  static const _revenueTrend = [
    ControlCenterTrendPoint(label: 'Jan', amountLakhs: 32, targetLakhs: 34),
    ControlCenterTrendPoint(label: 'Feb', amountLakhs: 34, targetLakhs: 35),
    ControlCenterTrendPoint(label: 'Mar', amountLakhs: 36, targetLakhs: 37),
    ControlCenterTrendPoint(label: 'Apr', amountLakhs: 38, targetLakhs: 39),
    ControlCenterTrendPoint(label: 'May', amountLakhs: 40, targetLakhs: 41),
    ControlCenterTrendPoint(label: 'Jun', amountLakhs: 42.8, targetLakhs: 42),
  ];

  static const _erpModules = [
    ErpModuleReference(
      module: ErpModuleId.admissions,
      label: 'Admissions',
      route: RouteNames.admissionsDashboard,
      schoolCount: 42,
      adoptionPercent: 88,
    ),
    ErpModuleReference(
      module: ErpModuleId.finance,
      label: 'Finance',
      route: RouteNames.financeDashboard,
      schoolCount: 40,
      adoptionPercent: 92,
    ),
    ErpModuleReference(
      module: ErpModuleId.sis,
      label: 'Student SIS',
      route: RouteNames.sisDashboard,
      schoolCount: 41,
      adoptionPercent: 95,
    ),
    ErpModuleReference(
      module: ErpModuleId.hr,
      label: 'HR',
      route: RouteNames.hrDashboard,
      schoolCount: 28,
      adoptionPercent: 71,
    ),
    ErpModuleReference(
      module: ErpModuleId.management,
      label: 'Management',
      route: RouteNames.managementDashboard,
      schoolCount: 38,
      adoptionPercent: 84,
    ),
    ErpModuleReference(
      module: ErpModuleId.transport,
      label: 'Transport',
      route: RouteNames.transportDashboard,
      schoolCount: 22,
      adoptionPercent: 62,
    ),
    ErpModuleReference(
      module: ErpModuleId.hostel,
      label: 'Hostel',
      route: RouteNames.hostelDashboard,
      schoolCount: 14,
      adoptionPercent: 48,
    ),
  ];

  static const _schools = [
    PlatformSchool(
      id: 'SCH-1001',
      name: 'Akshara International — Hyderabad',
      plan: SubscriptionPlan.premium,
      studentCount: 2840,
      status: PlatformSchoolStatus.active,
      createdDate: '2023-08-12',
      mrrLakhs: 4.2,
      healthScore: 92,
      region: 'South',
      tenantId: 'tenant_hyd_001',
    ),
    PlatformSchool(
      id: 'SCH-1002',
      name: 'Green Valley Public School',
      plan: SubscriptionPlan.standard,
      studentCount: 1120,
      status: PlatformSchoolStatus.trial,
      createdDate: '2025-11-03',
      mrrLakhs: 1.1,
      healthScore: 68,
      region: 'West',
      tenantId: 'tenant_gv_002',
    ),
    PlatformSchool(
      id: 'SCH-1003',
      name: 'Sunrise Academy — Bengaluru',
      plan: SubscriptionPlan.enterprise,
      studentCount: 4200,
      status: PlatformSchoolStatus.active,
      createdDate: '2022-04-18',
      mrrLakhs: 8.5,
      healthScore: 96,
      region: 'South',
      tenantId: 'tenant_blr_003',
    ),
    PlatformSchool(
      id: 'SCH-1004',
      name: 'Heritage Convent — Pune',
      plan: SubscriptionPlan.standard,
      studentCount: 890,
      status: PlatformSchoolStatus.churnRisk,
      createdDate: '2024-01-22',
      mrrLakhs: 0.9,
      healthScore: 54,
      region: 'West',
      tenantId: 'tenant_pune_004',
    ),
    PlatformSchool(
      id: 'SCH-1005',
      name: 'Delhi Public School — Noida',
      plan: SubscriptionPlan.premium,
      studentCount: 3100,
      status: PlatformSchoolStatus.active,
      createdDate: '2021-09-05',
      mrrLakhs: 5.1,
      healthScore: 89,
      region: 'North',
      tenantId: 'tenant_noida_005',
    ),
  ];

  @override
  Future<ControlCenterDashboardData> getDashboard({required RepositoryQuery query}) async {
    return const ControlCenterDashboardData(
      kpis: [
        ControlCenterKpi(
          id: 'total_schools',
          value: '48',
          label: 'Total Schools',
          icon: Icons.apartment_outlined,
          accentName: 'primary',
        ),
        ControlCenterKpi(
          id: 'active_schools',
          value: '41',
          label: 'Active',
          icon: Icons.check_circle_outline,
          accentName: 'success',
        ),
        ControlCenterKpi(
          id: 'trial_schools',
          value: '4',
          label: 'Trial',
          icon: Icons.hourglass_empty_outlined,
          accentName: 'warning',
        ),
        ControlCenterKpi(
          id: 'expiring',
          value: '3',
          label: 'Expiring 30d',
          icon: Icons.event_busy_outlined,
          accentName: 'error',
        ),
        ControlCenterKpi(
          id: 'mrr',
          value: '₹42.8L',
          label: 'MRR',
          icon: Icons.payments_outlined,
          accentName: 'primary',
        ),
        ControlCenterKpi(
          id: 'arr',
          value: '₹5.1Cr',
          label: 'ARR',
          icon: Icons.trending_up_outlined,
          accentName: 'success',
        ),
        ControlCenterKpi(
          id: 'churn_risk',
          value: '2',
          label: 'Churn Risk',
          icon: Icons.warning_amber_outlined,
          accentName: 'error',
        ),
      ],
      schoolGrowthTrend: [
        ControlCenterTrendPoint(label: 'Jan', amountLakhs: 38, targetLakhs: 40),
        ControlCenterTrendPoint(label: 'Feb', amountLakhs: 39, targetLakhs: 41),
        ControlCenterTrendPoint(label: 'Mar', amountLakhs: 41, targetLakhs: 42),
        ControlCenterTrendPoint(label: 'Apr', amountLakhs: 42, targetLakhs: 43),
        ControlCenterTrendPoint(label: 'May', amountLakhs: 44, targetLakhs: 44),
        ControlCenterTrendPoint(label: 'Jun', amountLakhs: 48, targetLakhs: 46),
      ],
      revenueTrend: [
        ControlCenterTrendPoint(label: 'Jan', amountLakhs: 32, targetLakhs: 34),
        ControlCenterTrendPoint(label: 'Feb', amountLakhs: 34, targetLakhs: 35),
        ControlCenterTrendPoint(label: 'Mar', amountLakhs: 36, targetLakhs: 37),
        ControlCenterTrendPoint(label: 'Apr', amountLakhs: 38, targetLakhs: 39),
        ControlCenterTrendPoint(label: 'May', amountLakhs: 40, targetLakhs: 41),
        ControlCenterTrendPoint(label: 'Jun', amountLakhs: 42.8, targetLakhs: 42),
      ],
      planDistribution: [
        ControlCenterSegment(label: 'Standard', value: 18, percent: 38),
        ControlCenterSegment(label: 'Premium', value: 22, percent: 46),
        ControlCenterSegment(label: 'Enterprise', value: 8, percent: 16),
      ],
      expiringSchools: [
        'Heritage Convent — Pune renews 2026-06-28',
        'Green Valley Public School trial ends 2026-06-15',
      ],
      erpModules: _erpModules,
      aiInsight:
          '3 schools expire within 30 days. Heritage Convent adoption score is 54 — assign CS owner and review Transport + Hostel module usage.',
    );
  }

  List<PlatformSchool> get _allSchools => [
        ...MockControlCenterWriteStore.instance.schools,
        ..._schools,
      ];

  @override
  Future<PaginatedResult<PlatformSchool>> getSchools({
    required RepositoryQuery query,
  }) async =>
      paginateList(_allSchools, query);

  @override
  Future<ControlCenterSubscriptionsData> getSubscriptions({required RepositoryQuery query}) async {
    return const ControlCenterSubscriptionsData(
      plans: [
        SubscriptionPlanInfo(
          plan: SubscriptionPlan.standard,
          monthlyPriceLakhs: 1.0,
          schoolCount: 18,
          features: ['Core ERP', 'Admissions', 'Finance', 'SIS'],
          dedicatedDb: false,
        ),
        SubscriptionPlanInfo(
          plan: SubscriptionPlan.premium,
          monthlyPriceLakhs: 4.0,
          schoolCount: 22,
          features: ['All Standard', 'HR', 'Transport', 'Analytics'],
          dedicatedDb: false,
        ),
        SubscriptionPlanInfo(
          plan: SubscriptionPlan.enterprise,
          monthlyPriceLakhs: 8.0,
          schoolCount: 8,
          features: ['All Premium', 'Dedicated DB', 'White label', 'SLA'],
          dedicatedDb: true,
        ),
      ],
      expiringCount: 3,
      renewalRatePercent: 94,
      planDistribution: [
        ControlCenterSegment(label: 'Standard', value: 18, percent: 38),
        ControlCenterSegment(label: 'Premium', value: 22, percent: 46),
        ControlCenterSegment(label: 'Enterprise', value: 8, percent: 16),
      ],
    );
  }

  @override
  Future<ControlCenterBillingData> getBilling({required RepositoryQuery query}) async {
    return const ControlCenterBillingData(
      mrrLakhs: 42.8,
      arrLakhs: 514,
      outstandingLakhs: 6.2,
      invoices: [
        BillingInvoice(
          id: 'INV-2026-0412',
          schoolName: 'Heritage Convent — Pune',
          amountLakhs: 0.9,
          dueDate: '2026-06-15',
          status: 'Overdue',
          plan: SubscriptionPlan.standard,
        ),
        BillingInvoice(
          id: 'INV-2026-0418',
          schoolName: 'Green Valley Public School',
          amountLakhs: 1.1,
          dueDate: '2026-06-20',
          status: 'Pending',
          plan: SubscriptionPlan.standard,
        ),
        BillingInvoice(
          id: 'INV-2026-0420',
          schoolName: 'Akshara International — Hyderabad',
          amountLakhs: 4.2,
          dueDate: '2026-06-30',
          status: 'Paid',
          plan: SubscriptionPlan.premium,
        ),
      ],
      revenueTrend: _revenueTrend,
      revenueByPlan: [
        ControlCenterSegment(label: 'Standard', value: 18, percent: 22),
        ControlCenterSegment(label: 'Premium', value: 88, percent: 52),
        ControlCenterSegment(label: 'Enterprise', value: 64, percent: 26),
      ],
    );
  }

  static const _seedDeals = [
    CrmDeal(
      id: 'DEAL-301',
      schoolName: 'Lotus Valley School',
      contactName: 'Rajesh Mehta',
      stage: CrmPipelineStage.proposal,
      estimatedMrrLakhs: 3.5,
      owner: 'Anita Sales',
      lastActivity: '2026-06-04',
    ),
    CrmDeal(
      id: 'DEAL-302',
      schoolName: 'Oakridge International',
      contactName: 'Sunita Rao',
      stage: CrmPipelineStage.demo,
      estimatedMrrLakhs: 6.0,
      owner: 'Vikram Sales',
      lastActivity: '2026-06-05',
    ),
    CrmDeal(
      id: 'DEAL-303',
      schoolName: 'Cambridge Public School',
      contactName: 'David Fernandes',
      stage: CrmPipelineStage.negotiation,
      estimatedMrrLakhs: 2.2,
      owner: 'Anita Sales',
      lastActivity: '2026-06-03',
    ),
    CrmDeal(
      id: 'DEAL-304',
      schoolName: 'St. Mary\'s Academy',
      contactName: 'Fr. Thomas',
      stage: CrmPipelineStage.won,
      estimatedMrrLakhs: 4.8,
      owner: 'Vikram Sales',
      lastActivity: '2026-06-01',
    ),
  ];

  @override
  Future<ControlCenterCrmData> getCrmPipeline({required RepositoryQuery query}) async {
    final deals = [
      ...MockControlCenterWriteStore.instance.deals,
      ..._seedDeals,
    ];
    return ControlCenterCrmData(
      deals: deals,
      pipelineValueLakhs: 28.4,
      winRatePercent: 32,
      stageDistribution: const [
        ControlCenterSegment(label: 'Lead', value: 8, percent: 18),
        ControlCenterSegment(label: 'Demo', value: 12, percent: 27),
        ControlCenterSegment(label: 'Proposal', value: 10, percent: 22),
        ControlCenterSegment(label: 'Won', value: 6, percent: 14),
      ],
    );
  }

  @override
  Future<PaginatedResult<SupportTicket>> getSupportTickets({
    required RepositoryQuery query,
  }) async {
    return paginateList(const [
      SupportTicket(
        id: 'TKT-8801',
        subject: 'Finance module sync delay',
        schoolName: 'Heritage Convent — Pune',
        status: SupportTicketStatus.open,
        priority: 'High',
        slaRemaining: '2h 14m',
        assignee: 'Support Team A',
        createdDate: '2026-06-05',
      ),
      SupportTicket(
        id: 'TKT-8802',
        subject: 'White label domain verification',
        schoolName: 'Sunrise Academy — Bengaluru',
        status: SupportTicketStatus.inProgress,
        priority: 'Medium',
        slaRemaining: '6h 30m',
        assignee: 'Support Team B',
        createdDate: '2026-06-04',
      ),
      SupportTicket(
        id: 'TKT-8803',
        subject: 'Transport GPS integration',
        schoolName: 'Akshara International — Hyderabad',
        status: SupportTicketStatus.resolved,
        priority: 'Low',
        slaRemaining: '—',
        assignee: 'Support Team A',
        createdDate: '2026-06-02',
      ),
    ], query);
  }

  @override
  Future<ControlCenterSuccessData> getCustomerSuccess({required RepositoryQuery query}) async {
    return const ControlCenterSuccessData(
      schools: [
        CustomerSuccessSchool(
          schoolId: 'SCH-1004',
          schoolName: 'Heritage Convent — Pune',
          adoptionScore: 54,
          renewalProbability: 42,
          churnRisk: true,
          csOwner: 'Meera CS',
          lowUsageModules: ['Transport', 'Hostel'],
        ),
        CustomerSuccessSchool(
          schoolId: 'SCH-1002',
          schoolName: 'Green Valley Public School',
          adoptionScore: 68,
          renewalProbability: 71,
          churnRisk: false,
          csOwner: 'Arun CS',
          lowUsageModules: ['HR'],
        ),
        CustomerSuccessSchool(
          schoolId: 'SCH-1003',
          schoolName: 'Sunrise Academy — Bengaluru',
          adoptionScore: 96,
          renewalProbability: 98,
          churnRisk: false,
          csOwner: 'Meera CS',
          lowUsageModules: [],
        ),
      ],
      atRiskCount: 2,
      avgAdoptionScore: 78,
      aiInsight:
          'Heritage Convent has lowest adoption (54). Recommend CS call and Transport module onboarding workshop.',
    );
  }

  @override
  Future<PaginatedResult<WhiteLabelConfig>> getWhiteLabelConfigs({
    required RepositoryQuery query,
  }) async {
    return paginateList(const [
      WhiteLabelConfig(
        schoolId: 'SCH-1003',
        schoolName: 'Sunrise Academy — Bengaluru',
        logoUrl: 'assets/branding/sunrise_logo.png',
        primaryColorHex: '#1565C0',
        customDomain: 'erp.sunriseacademy.edu.in',
        loginBackgroundUrl: 'assets/branding/sunrise_login.jpg',
        isPublished: true,
      ),
      WhiteLabelConfig(
        schoolId: 'SCH-1001',
        schoolName: 'Akshara International — Hyderabad',
        logoUrl: 'assets/branding/akshara_intl_logo.png',
        primaryColorHex: '#2E7D32',
        customDomain: 'portal.aksharainternational.in',
        loginBackgroundUrl: 'assets/branding/akshara_login.jpg',
        isPublished: true,
      ),
      WhiteLabelConfig(
        schoolId: 'SCH-1002',
        schoolName: 'Green Valley Public School',
        logoUrl: 'assets/branding/greenvalley_logo.png',
        primaryColorHex: '#558B2F',
        customDomain: '—',
        loginBackgroundUrl: '—',
        isPublished: false,
      ),
    ], query);
  }

  @override
  Future<ControlCenterAnalyticsData> getAnalytics({required RepositoryQuery query}) async {
    return const ControlCenterAnalyticsData(
      schoolGrowthTrend: _schoolGrowthTrend,
      studentGrowthTrend: [
        ControlCenterTrendPoint(label: 'Jan', amountLakhs: 82, targetLakhs: 85),
        ControlCenterTrendPoint(label: 'Feb', amountLakhs: 84, targetLakhs: 86),
        ControlCenterTrendPoint(label: 'Mar', amountLakhs: 86, targetLakhs: 88),
        ControlCenterTrendPoint(label: 'Apr', amountLakhs: 88, targetLakhs: 90),
        ControlCenterTrendPoint(label: 'May', amountLakhs: 91, targetLakhs: 92),
        ControlCenterTrendPoint(label: 'Jun', amountLakhs: 94, targetLakhs: 94),
      ],
      moduleUsage: [
        ControlCenterSegment(label: 'Admissions', value: 88, percent: 88),
        ControlCenterSegment(label: 'Finance', value: 92, percent: 92),
        ControlCenterSegment(label: 'SIS', value: 95, percent: 95),
        ControlCenterSegment(label: 'Transport', value: 62, percent: 62),
      ],
      marketingAttribution: [
        ControlCenterSegment(label: 'Referral', value: 14, percent: 35),
        ControlCenterSegment(label: 'Digital ads', value: 10, percent: 25),
        ControlCenterSegment(label: 'Events', value: 8, percent: 20),
        ControlCenterSegment(label: 'Partners', value: 8, percent: 20),
      ],
    );
  }

  @override
  Future<ControlCenterMonitoringData> getMonitoring({required RepositoryQuery query}) async {
    return const ControlCenterMonitoringData(
      services: [
        PlatformServiceHealth(
          serviceName: 'API Gateway',
          status: PlatformHealthStatus.healthy,
          uptimePercent: '99.98%',
          lastIncident: 'None (30d)',
        ),
        PlatformServiceHealth(
          serviceName: 'Auth Service',
          status: PlatformHealthStatus.healthy,
          uptimePercent: '99.95%',
          lastIncident: '2026-05-12 (4m)',
        ),
        PlatformServiceHealth(
          serviceName: 'Multi-tenant DB',
          status: PlatformHealthStatus.degraded,
          uptimePercent: '99.82%',
          lastIncident: '2026-06-04 (18m)',
        ),
        PlatformServiceHealth(
          serviceName: 'Notification Bus',
          status: PlatformHealthStatus.healthy,
          uptimePercent: '99.91%',
          lastIncident: '2026-04-28 (2m)',
        ),
      ],
      errorRatePercent: 0.12,
      activeDeployments: 2,
      featureFlags: [
        'hostel_mvp_enabled',
        'transport_gps_beta',
        'ai_copilot_platform',
      ],
    );
  }

  @override
  Future<ControlCenterRolesData> getRoles({required RepositoryQuery query}) async {
    return const ControlCenterRolesData(
      roles: [
        PlatformRole(
          id: 'role_super_admin',
          name: 'Super Admin',
          description: 'Full platform configuration and school lifecycle',
          permissionCount: 48,
          userCount: 3,
        ),
        PlatformRole(
          id: 'role_director',
          name: 'Akshara Director',
          description: 'Platform revenue and analytics — no school PII',
          permissionCount: 22,
          userCount: 5,
        ),
        PlatformRole(
          id: 'role_sales',
          name: 'Sales',
          description: 'CRM pipeline and school-as-customer leads',
          permissionCount: 14,
          userCount: 8,
        ),
        PlatformRole(
          id: 'role_support',
          name: 'Support',
          description: 'Ticket management with audited data access',
          permissionCount: 12,
          userCount: 12,
        ),
      ],
      permissionGroups: [
        'schools.lifecycle',
        'subscriptions.manage',
        'billing.view',
        'crm.pipeline',
        'support.tickets',
        'white_label.config',
        'platform.settings',
      ],
    );
  }

  @override
  Future<ControlCenterSettingsData> getSettings({required RepositoryQuery query}) async {
    return const ControlCenterSettingsData(
      maintenanceMode: false,
      sections: [
        ControlCenterSettingsSection(
          id: 'feature_flags',
          title: 'Feature flags',
          items: [
            ControlCenterSettingItem(
              id: 'hostel_mvp',
              label: 'Hostel MVP',
              value: 'Enabled',
              description: 'HO-01 → HO-08 module rollout',
              editable: true,
            ),
            ControlCenterSettingItem(
              id: 'transport_gps',
              label: 'Transport GPS beta',
              value: 'Enabled (12 schools)',
              description: 'TR-07 live tracking integration',
              editable: true,
            ),
          ],
        ),
        ControlCenterSettingsSection(
          id: 'platform_limits',
          title: 'Platform limits',
          items: [
            ControlCenterSettingItem(
              id: 'api_rate',
              label: 'API rate limit',
              value: '1200 req/min per tenant',
              description: 'Per-school API throttling',
              editable: true,
            ),
            ControlCenterSettingItem(
              id: 'maintenance',
              label: 'Maintenance mode',
              value: 'Off',
              description: 'ACC-D-08 maintenance wizard placeholder',
              editable: true,
            ),
          ],
        ),
        ControlCenterSettingsSection(
          id: 'multi_school',
          title: 'Multi-school architecture',
          items: [
            ControlCenterSettingItem(
              id: 'tenant_isolation',
              label: 'Tenant isolation',
              value: 'Supabase RLS per school',
              description: 'TechnicalArchitecture.md §13.6',
              editable: false,
            ),
            ControlCenterSettingItem(
              id: 'enterprise_db',
              label: 'Enterprise dedicated DB',
              value: '8 schools',
              description: 'Separate Supabase URL at login',
              editable: false,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<ControlCenterProvidersData> getProviders({required RepositoryQuery query}) async {
    return const ControlCenterProvidersData(
      providers: [
        PlatformProviderConfig(
          id: 'prov_ai',
          providerCategory: 'ai',
          providerName: 'openai',
          hasCredential: true,
          isActive: true,
          isPrimary: true,
          healthStatus: 'healthy',
        ),
        PlatformProviderConfig(
          id: 'prov_wa',
          providerCategory: 'whatsapp',
          providerName: 'msg91',
          hasCredential: true,
          isActive: true,
          isPrimary: true,
          healthStatus: 'healthy',
        ),
        PlatformProviderConfig(
          id: 'prov_sms',
          providerCategory: 'sms',
          providerName: 'msg91',
          hasCredential: true,
          isActive: true,
          isPrimary: true,
          healthStatus: 'healthy',
        ),
      ],
      usage: PlatformUsageAnalytics(
        totalEvents: 1250,
        totalCostInr: 8420,
        byCategory: {
          'ai': PlatformUsageCategoryStats(events: 400, costInr: 6200),
          'whatsapp': PlatformUsageCategoryStats(events: 650, costInr: 1820),
          'sms': PlatformUsageCategoryStats(events: 200, costInr: 400),
        },
      ),
      features: [
        FeatureEnablement(schoolId: 'school_1', featureKey: 'parent_insights', enabled: true),
        FeatureEnablement(schoolId: 'school_1', featureKey: 'teacher_assistant', enabled: true),
      ],
    );
  }

  @override
  Future<void> saveProvider({
    required RepositoryQuery query,
    required String providerCategory,
    required String providerName,
    String? credential,
    bool isActive = true,
    bool isPrimary = false,
    Map<String, dynamic>? config,
  }) async {}

  @override
  Future<void> setFeatureEnablement({
    required RepositoryQuery query,
    required String schoolId,
    required String featureKey,
    required bool enabled,
  }) async {}

  @override
  Future<PlatformSchool> createSchool({
    required RepositoryQuery query,
    required CreateSchoolRequest request,
  }) async {
    return MockControlCenterWriteStore.instance.createSchool(request);
  }

  @override
  Future<CrmDeal> createLead({
    required RepositoryQuery query,
    required CreateCrmLeadRequest request,
  }) async {
    return MockControlCenterWriteStore.instance.createLead(request);
  }

  static const _seedAiCreditEntries = [
    AiCreditEntry(
      id: 'AICR-101',
      entryType: 'top_up',
      units: 5000,
      reason: 'Quarterly AI credit purchase — Q2 2026',
      actorId: 'plat_admin_1',
      externalRef: 'PO-2026-0044',
      createdAt: '2026-04-01T09:00:00.000Z',
    ),
    AiCreditEntry(
      id: 'AICR-108',
      entryType: 'adjustment',
      units: -120,
      reason: 'Correction: duplicate AI call billed twice',
      actorId: 'plat_admin_1',
      createdAt: '2026-05-14T11:30:00.000Z',
    ),
    AiCreditEntry(
      id: 'AICR-112',
      entryType: 'expiry',
      units: -300,
      reason: 'Unused promotional credits expired',
      createdAt: '2026-06-01T00:00:00.000Z',
    ),
  ];

  /// Debits/reservations come from `ai_call_log` / `ai_call_reservations`,
  /// which this mock module does not model — held constant to keep the
  /// wallet's balance projection realistic without a second AI-usage mock.
  static const _mockDebitedUnits = 3120;
  static const _mockReservedUnits = 40;

  List<AiCreditEntry> get _allAiCreditEntries => [
        ...MockControlCenterWriteStore.instance.aiCreditEntries,
        ..._seedAiCreditEntries,
      ];

  /// Mirrors `readWalletBalance()` / `walletHealth()` in
  /// `ai_wallet_repository.ts`: available = granted - debited - reserved
  /// (may be negative); health falls back to lifetime grants when there has
  /// never been a top_up.
  AiWalletBalance _computeAiWalletBalance(List<AiCreditEntry> entries) {
    final granted = entries.fold<int>(0, (sum, e) => sum + e.units);
    const debited = _mockDebitedUnits;
    const reserved = _mockReservedUnits;
    final available = granted - debited - reserved;
    final lastTopUp = entries
        .firstWhere(
          (e) => e.entryType == 'top_up',
          orElse: () => const AiCreditEntry(
            id: '',
            entryType: 'top_up',
            units: 0,
            reason: '',
            createdAt: '',
          ),
        )
        .units;
    final ceiling = lastTopUp > 0 ? lastTopUp : granted;
    final health = available <= 0 || ceiling <= 0
        ? AiWalletHealth.empty
        : (available <= (ceiling * 0.1).ceil() ? AiWalletHealth.low : AiWalletHealth.healthy);

    return AiWalletBalance(
      grantedUnits: granted,
      debitedUnits: debited,
      reservedUnits: reserved,
      availableUnits: available,
      lastTopUpUnits: lastTopUp,
      health: health,
    );
  }

  @override
  Future<AiWalletData> getAiWallet({required RepositoryQuery query}) async {
    final entries = _allAiCreditEntries;
    return AiWalletData(
      balance: _computeAiWalletBalance(entries),
      entries: entries,
    );
  }

  @override
  Future<AiWalletData> grantAiCredits({
    required RepositoryQuery query,
    required String entryType,
    required int units,
    required String reason,
    String? externalRef,
  }) async {
    MockControlCenterWriteStore.instance.grantAiCredits(
      entryType: entryType,
      units: units,
      reason: reason,
      externalRef: externalRef,
    );
    final entries = _allAiCreditEntries;
    return AiWalletData(
      balance: _computeAiWalletBalance(entries),
      entries: entries,
    );
  }
}
