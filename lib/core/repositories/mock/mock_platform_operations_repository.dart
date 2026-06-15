import '../../../features/platform_operations/platform_operations_models.dart';
import '../../ai/ai_inference_models.dart';
import '../../ai/ai_inference_pipeline.dart';
import '../interfaces/platform_operations_repository.dart';
import '../repository_query.dart';

class MockPlatformOperationsRepository implements PlatformOperationsRepository {
  MockPlatformOperationsRepository({required AiInferencePipeline pipeline})
      : _pipeline = pipeline;

  final AiInferencePipeline _pipeline;

  static const _monthLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static List<MetricTrendPoint> _trend(List<double> values) {
    return List<MetricTrendPoint>.generate(
      values.length,
      (index) => MetricTrendPoint(
        label: _monthLabels[index % _monthLabels.length],
        value: values[index],
      ),
      growable: false,
    );
  }

  final List<PlatformAlert> _activeAlerts = [
    PlatformAlert(
      id: 'plat_alert_1',
      title: 'API error rate spike',
      message: 'Finance API 5xx rate exceeded 2% threshold for 10 minutes.',
      severity: 'high',
      status: 'active',
      triggeredAt: DateTime(2026, 6, 15, 8, 12),
      source: 'observability',
    ),
    PlatformAlert(
      id: 'plat_alert_2',
      title: 'Workflow queue depth',
      message: 'Admissions approval queue depth above 120 items.',
      severity: 'medium',
      status: 'active',
      triggeredAt: DateTime(2026, 6, 15, 7, 45),
      source: 'workflow',
    ),
    PlatformAlert(
      id: 'plat_alert_3',
      title: 'Tenant isolation probe failure',
      message: 'Cross-tenant read probe failed for tenant sch_102.',
      severity: 'critical',
      status: 'active',
      triggeredAt: DateTime(2026, 6, 14, 22, 30),
      source: 'tenant',
    ),
  ];

  final List<PlatformAlert> _alertHistory = [
    PlatformAlert(
      id: 'plat_alert_hist_1',
      title: 'Memory utilization',
      message: 'Worker pod memory above 85% — auto-scaled.',
      severity: 'medium',
      status: 'resolved',
      triggeredAt: DateTime(2026, 6, 13, 14, 0),
      acknowledgedAt: DateTime(2026, 6, 13, 14, 15),
      acknowledgedBy: 'ops@akshara.io',
      ackNote: 'Scaled worker pool to 6 replicas.',
      source: 'platform',
    ),
  ];

  final List<AccessReviewItem> _accessReviews = [
    AccessReviewItem(
      id: 'ar_1',
      subject: 'finance.lead@akshara.io',
      role: 'financeAdmin',
      dueAt: DateTime(2026, 6, 20),
      status: 'pending',
    ),
    AccessReviewItem(
      id: 'ar_2',
      subject: 'transport.mgr@akshara.io',
      role: 'transportManager',
      dueAt: DateTime(2026, 6, 18),
      status: 'pending',
    ),
  ];

  TenantVerificationReport? _lastVerificationReport;

  @override
  Future<ObservabilityDashboard> getObservabilityDashboard({
    required RepositoryQuery query,
  }) async {
    return ObservabilityDashboard(
      kpis: const [
        PlatformKpi(
          id: 'audit_events_24h',
          label: 'Audit Events (24h)',
          value: '18,420',
          deltaLabel: '+6%',
          trend: 'up',
        ),
        PlatformKpi(
          id: 'api_success_rate',
          label: 'API Success Rate',
          value: '99.4%',
          trend: 'stable',
        ),
        PlatformKpi(
          id: 'active_tenants',
          label: 'Active Tenants',
          value: '213',
          deltaLabel: '+3',
          trend: 'up',
        ),
        PlatformKpi(
          id: 'pending_audit_uploads',
          label: 'Pending Audit Uploads',
          value: '42',
          severity: 'medium',
        ),
      ],
      auditMetrics: const [
        AuditVisibilityMetric(
          id: 'upload_lag',
          label: 'Upload lag (p95)',
          value: '4.2 min',
          status: 'healthy',
        ),
        AuditVisibilityMetric(
          id: 'retention_compliance',
          label: 'Retention compliance',
          value: '98%',
          status: 'healthy',
        ),
        AuditVisibilityMetric(
          id: 'mutation_coverage',
          label: 'Mutation audit coverage',
          value: '96%',
          status: 'watch',
          detail: '4 mutations missing server-side audit hooks',
        ),
      ],
      requestTrend: _trend([1240, 1180, 1320, 1410, 1380, 1520, 1460]),
      generatedAt: DateTime(2026, 6, 15, 9, 0),
    );
  }

  @override
  Future<ApplicationHealthSnapshot> getApplicationHealth({
    required RepositoryQuery query,
  }) async {
    return ApplicationHealthSnapshot(
      overallStatus: 'healthy',
      uptimePercent: 99.92,
      checkedAt: DateTime(2026, 6, 15, 9, 0),
      services: [
        ServiceHealthItem(
          id: 'svc_api',
          name: 'Core API',
          status: 'healthy',
          uptimePercent: 99.95,
          latencyMs: 142,
          lastCheckedAt: DateTime(2026, 6, 15, 8, 58),
        ),
        ServiceHealthItem(
          id: 'svc_auth',
          name: 'Auth Service',
          status: 'healthy',
          uptimePercent: 99.99,
          latencyMs: 68,
          lastCheckedAt: DateTime(2026, 6, 15, 8, 58),
        ),
        ServiceHealthItem(
          id: 'svc_workflow',
          name: 'Workflow Engine',
          status: 'degraded',
          uptimePercent: 99.1,
          latencyMs: 890,
          lastCheckedAt: DateTime(2026, 6, 15, 8, 58),
        ),
        ServiceHealthItem(
          id: 'svc_ai',
          name: 'AI Inference',
          status: 'healthy',
          uptimePercent: 99.7,
          latencyMs: 1240,
          lastCheckedAt: DateTime(2026, 6, 15, 8, 58),
        ),
      ],
    );
  }

  @override
  Future<ErrorDashboard> getErrorDashboard({
    required RepositoryQuery query,
  }) async {
    return ErrorDashboard(
      totalErrors24h: 284,
      errorRatePercent: 0.42,
      topErrors: [
        ErrorSummaryItem(
          id: 'err_1',
          code: 'FIN_PAYMENT_TIMEOUT',
          message: 'Payment gateway timeout during fee collection',
          count: 48,
          severity: 'high',
          module: 'finance',
          lastSeenAt: DateTime(2026, 6, 15, 8, 40),
        ),
        ErrorSummaryItem(
          id: 'err_2',
          code: 'WF_APPROVAL_STALE',
          message: 'Workflow approval step exceeded SLA',
          count: 36,
          severity: 'medium',
          module: 'workflow',
          lastSeenAt: DateTime(2026, 6, 15, 7, 55),
        ),
        ErrorSummaryItem(
          id: 'err_3',
          code: 'AI_INFERENCE_RATE_LIMIT',
          message: 'AI provider rate limit exceeded',
          count: 22,
          severity: 'medium',
          module: 'ai',
          lastSeenAt: DateTime(2026, 6, 15, 6, 20),
        ),
      ],
      trend: _trend([32, 28, 41, 38, 45, 36, 42]),
    );
  }

  @override
  Future<WorkflowMonitoringSnapshot> getWorkflowMonitoring({
    required RepositoryQuery query,
  }) async {
    return const WorkflowMonitoringSnapshot(
      totalFailures24h: 17,
      totalQueueDepth: 186,
      workflows: [
        WorkflowQueueMetric(
          workflowId: 'wf_admissions_approval',
          workflowName: 'Admissions Approval',
          failedCount: 8,
          queueDepth: 124,
          avgDurationSec: 42.5,
        ),
        WorkflowQueueMetric(
          workflowId: 'wf_fee_refund',
          workflowName: 'Fee Refund',
          failedCount: 5,
          queueDepth: 38,
          avgDurationSec: 68.2,
        ),
        WorkflowQueueMetric(
          workflowId: 'wf_leave_approval',
          workflowName: 'Leave Approval',
          failedCount: 4,
          queueDepth: 24,
          avgDurationSec: 18.0,
        ),
      ],
    );
  }

  @override
  Future<AiMonitoringSnapshot> getAiMonitoring({
    required RepositoryQuery query,
  }) async {
    return AiMonitoringSnapshot(
      totalInferences24h: 4820,
      failureRatePercent: 1.8,
      avgLatencyMs: 1180,
      cacheHitRatePercent: 62.4,
      providerBreakdown: const {
        'primary': 3200,
        'fallback': 980,
        'local': 640,
      },
      latencyTrend: _trend([1320, 1280, 1210, 1190, 1180, 1150, 1180]),
    );
  }

  @override
  Future<PlatformMonitoringSnapshot> getPlatformMonitoring({
    required RepositoryQuery query,
  }) async {
    return const PlatformMonitoringSnapshot(
      overallStatus: 'healthy',
      infrastructureKpis: [
        PlatformKpi(
          id: 'db_connections',
          label: 'DB Connections',
          value: '142 / 200',
        ),
        PlatformKpi(
          id: 'redis_hit_rate',
          label: 'Redis Hit Rate',
          value: '94.2%',
        ),
        PlatformKpi(
          id: 'storage_usage',
          label: 'Object Storage',
          value: '68%',
          severity: 'medium',
        ),
      ],
      services: [
        ServiceHealthItem(
          id: 'plat_postgres',
          name: 'PostgreSQL',
          status: 'healthy',
          uptimePercent: 99.99,
          latencyMs: 12,
        ),
        ServiceHealthItem(
          id: 'plat_redis',
          name: 'Redis',
          status: 'healthy',
          uptimePercent: 99.98,
          latencyMs: 2,
        ),
        ServiceHealthItem(
          id: 'plat_queue',
          name: 'Message Queue',
          status: 'healthy',
          uptimePercent: 99.9,
          latencyMs: 8,
        ),
      ],
    );
  }

  @override
  Future<SchoolHealthMonitoringSnapshot> getSchoolHealthMonitoring({
    required RepositoryQuery query,
  }) async {
    return const SchoolHealthMonitoringSnapshot(
      portfolioScore: 78,
      atRiskCount: 2,
      schools: [
        SchoolHealthRow(
          schoolId: 'sch_101',
          schoolName: 'Akshara Green Valley',
          healthScore: 88,
          status: 'healthy',
          openIncidents: 0,
          region: 'Bengaluru',
        ),
        SchoolHealthRow(
          schoolId: 'sch_102',
          schoolName: 'Akshara City Central',
          healthScore: 63,
          status: 'watch',
          openIncidents: 2,
          region: 'Hyderabad',
        ),
        SchoolHealthRow(
          schoolId: 'sch_103',
          schoolName: 'Akshara Horizon Campus',
          healthScore: 42,
          status: 'critical',
          openIncidents: 5,
          region: 'Chennai',
        ),
      ],
    );
  }

  @override
  Future<SystemMetricsSnapshot> getSystemMetrics({
    required RepositoryQuery query,
  }) async {
    return SystemMetricsSnapshot(
      cpuPercent: 58.4,
      memoryPercent: 72.1,
      requestsPerMinute: 1460,
      cpuTrend: _trend([52, 54, 56, 58, 57, 59, 58.4]),
      memoryTrend: _trend([68, 69, 70, 71, 72, 71, 72.1]),
      requestTrend: _trend([1240, 1180, 1320, 1410, 1380, 1520, 1460]),
    );
  }

  @override
  Future<List<AlertDefinition>> listAlertDefinitions({
    required RepositoryQuery query,
  }) async {
    return const [
      AlertDefinition(
        id: 'def_api_5xx',
        name: 'API 5xx rate',
        metric: 'api.error_rate_5xx',
        threshold: '> 2% for 10m',
        severity: 'high',
        enabled: true,
      ),
      AlertDefinition(
        id: 'def_queue_depth',
        name: 'Workflow queue depth',
        metric: 'workflow.queue_depth',
        threshold: '> 100',
        severity: 'medium',
        enabled: true,
      ),
      AlertDefinition(
        id: 'def_tenant_probe',
        name: 'Tenant isolation probe',
        metric: 'tenant.isolation_probe',
        threshold: 'any failure',
        severity: 'critical',
        enabled: true,
      ),
      AlertDefinition(
        id: 'def_ai_latency',
        name: 'AI inference latency',
        metric: 'ai.latency_p95',
        threshold: '> 3000ms',
        severity: 'medium',
        enabled: false,
      ),
    ];
  }

  @override
  Future<List<PlatformAlert>> listActiveAlerts({
    required RepositoryQuery query,
  }) async {
    return _activeAlerts
        .where((alert) => alert.status == 'active')
        .toList(growable: false);
  }

  @override
  Future<List<PlatformAlert>> listAlertHistory({
    required RepositoryQuery query,
  }) async {
    final history = [
      ..._alertHistory,
      ..._activeAlerts.where((alert) => alert.status != 'active'),
    ];
    history.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    return history;
  }

  @override
  Future<PlatformAlert> acknowledgeAlert({
    required RepositoryQuery query,
    required String alertId,
    String? note,
  }) async {
    final index = _activeAlerts.indexWhere((alert) => alert.id == alertId);
    if (index < 0) {
      throw StateError('Alert not found: $alertId');
    }
    final updated = _activeAlerts[index].copyWith(
      status: 'acknowledged',
      acknowledgedAt: DateTime.now(),
      acknowledgedBy: 'current-user',
      ackNote: note,
    );
    _activeAlerts[index] = updated;
    return updated;
  }

  @override
  Future<TenantIsolationDashboard> getTenantIsolationDashboard({
    required RepositoryQuery query,
  }) async {
    final probes = List<TenantProbeSummary>.generate(
      213,
      (index) {
        final passed = index != 42 && index != 87;
        return TenantProbeSummary(
          probeId: 'probe_${index + 1}',
          label: 'Tenant boundary probe #${index + 1}',
          passed: passed,
          detail: passed
              ? 'Read/write isolation verified'
              : 'Cross-tenant read attempt detected',
        );
      },
      growable: false,
    );
    final passed = probes.where((probe) => probe.passed).length;
    return TenantIsolationDashboard(
      totalProbes: probes.length,
      passedProbes: passed,
      boundaryStatus: passed == probes.length ? 'secure' : 'degraded',
      probes: probes.take(12).toList(growable: false),
      lastVerifiedAt: DateTime(2026, 6, 15, 6, 0),
    );
  }

  @override
  Future<TenantVerificationReport> runTenantVerification({
    required RepositoryQuery query,
  }) async {
    _lastVerificationReport = TenantVerificationReport(
      reportId: 'tvr_${DateTime.now().millisecondsSinceEpoch}',
      status: 'completed',
      passedCount: 211,
      failedCount: 2,
      findings: const [
        TenantVerificationFinding(
          id: 'tvf_1',
          severity: 'high',
          message: 'sch_102: stale tenant context in background job',
          resolved: false,
        ),
        TenantVerificationFinding(
          id: 'tvf_2',
          severity: 'medium',
          message: 'sch_087: cache key missing tenant prefix',
          resolved: false,
        ),
      ],
      completedAt: DateTime.now(),
    );
    return _lastVerificationReport!;
  }

  @override
  Future<List<TenantDiagnostic>> getTenantDiagnostics({
    required RepositoryQuery query,
  }) async {
    return [
      TenantDiagnostic(
        tenantId: 'sch_101',
        tenantName: 'Akshara Green Valley',
        isolationScore: 98,
        status: 'healthy',
        issues: const [],
        lastCheckedAt: DateTime(2026, 6, 15, 6, 0),
      ),
      TenantDiagnostic(
        tenantId: 'sch_102',
        tenantName: 'Akshara City Central',
        isolationScore: 72,
        status: 'watch',
        issues: const [
          'Background job missing tenant context',
          'Elevated cross-service calls',
        ],
        lastCheckedAt: DateTime(2026, 6, 15, 6, 0),
      ),
      TenantDiagnostic(
        tenantId: 'sch_103',
        tenantName: 'Akshara Horizon Campus',
        isolationScore: 85,
        status: 'healthy',
        issues: const ['Audit upload backlog'],
        lastCheckedAt: DateTime(2026, 6, 15, 6, 0),
      ),
    ];
  }

  @override
  Future<SecurityDashboard> getSecurityDashboard({
    required RepositoryQuery query,
  }) async {
    return SecurityDashboard(
      kpis: const [
        PlatformKpi(
          id: 'failed_logins',
          label: 'Failed Logins (24h)',
          value: '38',
        ),
        PlatformKpi(
          id: 'privileged_actions',
          label: 'Privileged Actions',
          value: '12',
          severity: 'medium',
        ),
        PlatformKpi(
          id: 'stale_roles',
          label: 'Stale Role Reviews',
          value: '4',
          severity: 'high',
        ),
      ],
      threatLevel: 'elevated',
      openFindings: 6,
      lastScanAt: DateTime(2026, 6, 15, 5, 30),
    );
  }

  @override
  Future<PermissionAuditSummary> getPermissionAuditSummary({
    required RepositoryQuery query,
  }) async {
    return const PermissionAuditSummary(
      totalPermissions: 178,
      anomalyCount: 2,
      rows: [
        PermissionAuditRow(
          permission: 'manageFinance',
          roleCount: 8,
          userCount: 14,
          anomalyFlag: false,
        ),
        PermissionAuditRow(
          permission: 'managePlatformOperations',
          roleCount: 3,
          userCount: 5,
          anomalyFlag: true,
        ),
        PermissionAuditRow(
          permission: 'approveRefunds',
          roleCount: 4,
          userCount: 6,
          anomalyFlag: false,
        ),
      ],
    );
  }

  @override
  Future<RoleAuditSummary> getRoleAuditSummary({
    required RepositoryQuery query,
  }) async {
    return RoleAuditSummary(
      totalRoles: 12,
      staleCount: 4,
      rows: [
        RoleAuditRow(
          role: 'financeAdmin',
          permissionCount: 18,
          userCount: 6,
          lastReviewedAt: DateTime(2026, 3, 1),
          stale: true,
        ),
        RoleAuditRow(
          role: 'schoolAdmin',
          permissionCount: 64,
          userCount: 24,
          lastReviewedAt: DateTime(2026, 5, 15),
          stale: false,
        ),
        RoleAuditRow(
          role: 'transportManager',
          permissionCount: 8,
          userCount: 12,
          lastReviewedAt: DateTime(2026, 1, 20),
          stale: true,
        ),
      ],
    );
  }

  @override
  Future<List<MutationAuditEntry>> listMutationAudits({
    required RepositoryQuery query,
  }) async {
    return [
      MutationAuditEntry(
        id: 'ma_1',
        mutationId: 'acknowledgeAlert',
        actor: 'ops@akshara.io',
        module: 'platform_operations',
        occurredAt: DateTime(2026, 6, 14, 16, 20),
        success: true,
      ),
      MutationAuditEntry(
        id: 'ma_2',
        mutationId: 'approveRefunds',
        actor: 'finance.lead@akshara.io',
        module: 'finance',
        occurredAt: DateTime(2026, 6, 14, 14, 5),
        success: true,
        detail: 'Refund batch #RB-4421',
      ),
      MutationAuditEntry(
        id: 'ma_3',
        mutationId: 'runTenantVerification',
        actor: 'security@akshara.io',
        module: 'platform_operations',
        occurredAt: DateTime(2026, 6, 14, 6, 0),
        success: true,
      ),
    ];
  }

  @override
  Future<List<PrivilegedAction>> listPrivilegedActions({
    required RepositoryQuery query,
  }) async {
    return [
      PrivilegedAction(
        id: 'pa_1',
        action: 'Role permission override',
        actor: 'superadmin@akshara.io',
        target: 'finance.lead@akshara.io',
        occurredAt: DateTime(2026, 6, 13, 11, 0),
        riskLevel: 'high',
      ),
      PrivilegedAction(
        id: 'pa_2',
        action: 'Tenant data export',
        actor: 'ops@akshara.io',
        target: 'sch_103',
        occurredAt: DateTime(2026, 6, 12, 9, 30),
        riskLevel: 'medium',
      ),
    ];
  }

  @override
  Future<List<AccessReviewItem>> listAccessReviews({
    required RepositoryQuery query,
  }) async {
    return List<AccessReviewItem>.unmodifiable(_accessReviews);
  }

  @override
  Future<AccessReviewItem> completeAccessReview({
    required RepositoryQuery query,
    required String reviewId,
  }) async {
    final index = _accessReviews.indexWhere((item) => item.id == reviewId);
    if (index < 0) {
      throw StateError('Access review not found: $reviewId');
    }
    final updated = _accessReviews[index].copyWith(
      status: 'completed',
      reviewer: 'current-user',
    );
    _accessReviews[index] = updated;
    return updated;
  }

  @override
  Future<List<SecurityRecommendation>> getSecurityRecommendations({
    required RepositoryQuery query,
  }) async {
    final response = await _pipeline.complete(
      AiInferenceRequest(
        prompt:
            'Provide three prioritized security hardening recommendations for a multi-tenant school ERP platform.',
        taskType: aiTaskTypeName(AiInferenceTaskType.intelligenceCompute),
        systemPrompt:
            'You are a platform security advisor. Return concise actionable recommendations without PII.',
        context: const {
          'openFindings': 6,
          'staleRoles': 4,
          'tenantProbeFailures': 2,
        },
      ),
    );
    return [
      const SecurityRecommendation(
        id: 'sec_rec_1',
        title: 'Rotate stale role permissions',
        detail:
            '4 roles have not been reviewed in 90+ days. Schedule quarterly access reviews.',
        priority: 'high',
        confidence: 0.92,
      ),
      const SecurityRecommendation(
        id: 'sec_rec_2',
        title: 'Harden tenant context propagation',
        detail:
            '2 tenant isolation probes failed. Audit background jobs for missing tenant headers.',
        priority: 'critical',
        confidence: 0.95,
      ),
      SecurityRecommendation(
        id: 'sec_rec_3',
        title: 'AI-assisted security summary',
        detail: response.content.isNotEmpty
            ? response.content
            : 'Enable MFA for all privileged accounts and restrict export permissions.',
        priority: 'medium',
        confidence: 0.78,
      ),
    ];
  }

  @override
  Future<ProductionReadinessReport> getProductionReadinessReport({
    required RepositoryQuery query,
  }) async {
    return ProductionReadinessReport(
      overallScore: 86,
      status: 'ready_with_gaps',
      generatedAt: DateTime(2026, 6, 15, 9, 0),
      categories: const [
        ReadinessCategory(
          id: 'security',
          name: 'Security & RBAC',
          score: 88,
          items: [
            ReadinessCheckItem(
              id: 'rbac_coverage',
              label: 'RBAC route coverage',
              passed: true,
            ),
            ReadinessCheckItem(
              id: 'mutation_audit',
              label: 'Mutation audit registry',
              passed: true,
            ),
            ReadinessCheckItem(
              id: 'access_reviews',
              label: 'Quarterly access reviews',
              passed: false,
              detail: '2 pending reviews overdue',
            ),
          ],
        ),
        ReadinessCategory(
          id: 'observability',
          name: 'Observability',
          score: 90,
          items: [
            ReadinessCheckItem(
              id: 'metrics',
              label: 'Centralized metrics',
              passed: true,
            ),
            ReadinessCheckItem(
              id: 'alerting',
              label: 'Alert definitions',
              passed: true,
            ),
          ],
        ),
        ReadinessCategory(
          id: 'tenant',
          name: 'Tenant Isolation',
          score: 78,
          items: [
            ReadinessCheckItem(
              id: 'probes',
              label: '213 isolation probes',
              passed: false,
              detail: '2 probes failing',
            ),
            ReadinessCheckItem(
              id: 'diagnostics',
              label: 'Per-tenant diagnostics',
              passed: true,
            ),
          ],
        ),
        ReadinessCategory(
          id: 'reliability',
          name: 'Reliability',
          score: 84,
          items: [
            ReadinessCheckItem(
              id: 'uptime',
              label: '99.9% uptime target',
              passed: true,
            ),
            ReadinessCheckItem(
              id: 'workflow_sla',
              label: 'Workflow SLA compliance',
              passed: false,
              detail: 'Admissions queue above threshold',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<ErrorIntelligenceSnapshot> getErrorIntelligence({
    required RepositoryQuery query,
  }) async {
    return ErrorIntelligenceSnapshot(
      totalClassified: 284,
      classifications: const [
        ErrorClassification(
          category: 'Integration',
          count: 98,
          percent: 34.5,
          trend: 'up',
        ),
        ErrorClassification(
          category: 'Workflow',
          count: 72,
          percent: 25.4,
          trend: 'stable',
        ),
        ErrorClassification(
          category: 'Authentication',
          count: 48,
          percent: 16.9,
          trend: 'down',
        ),
        ErrorClassification(
          category: 'AI Inference',
          count: 38,
          percent: 13.4,
          trend: 'up',
        ),
      ],
      spikeAlerts: const [
        'Finance payment timeouts up 40% vs 7-day baseline',
        'AI rate-limit errors clustered around 06:00 UTC',
      ],
      trend: _trend([220, 240, 260, 255, 270, 278, 284]),
    );
  }

  @override
  Future<List<ErrorRecommendation>> getErrorRecommendations({
    required RepositoryQuery query,
  }) async {
    final response = await _pipeline.complete(
      AiInferenceRequest(
        prompt:
            'Suggest remediation for top ERP platform errors: payment timeouts, workflow SLA breaches, AI rate limits.',
        taskType: aiTaskTypeName(AiInferenceTaskType.intelligenceCompute),
        systemPrompt:
            'You are an SRE advisor. Provide concise remediation steps.',
        context: const {
          'topError': 'FIN_PAYMENT_TIMEOUT',
          'errorRate': 0.42,
        },
      ),
    );
    return [
      const ErrorRecommendation(
        id: 'err_rec_1',
        title: 'Increase payment gateway timeout',
        detail:
            'Raise timeout to 30s and add circuit breaker for FIN_PAYMENT_TIMEOUT.',
        confidence: 0.88,
        relatedErrorCode: 'FIN_PAYMENT_TIMEOUT',
      ),
      const ErrorRecommendation(
        id: 'err_rec_2',
        title: 'Scale workflow workers',
        detail:
            'Add 2 workflow workers during peak admissions window (08:00–12:00).',
        confidence: 0.82,
        relatedErrorCode: 'WF_APPROVAL_STALE',
      ),
      ErrorRecommendation(
        id: 'err_rec_3',
        title: 'AI pipeline tuning',
        detail: response.content.isNotEmpty
            ? response.content
            : 'Enable response cache and stagger batch inference jobs.',
        confidence: 0.75,
        relatedErrorCode: 'AI_INFERENCE_RATE_LIMIT',
      ),
    ];
  }

  @override
  Future<PlatformHealthIntelligence> getPlatformHealthIntelligence({
    required RepositoryQuery query,
  }) async {
    final response = await _pipeline.complete(
      AiInferenceRequest(
        prompt:
            'Summarize platform health risks and recommendations for school/tenant/platform dimensions.',
        taskType: aiTaskTypeName(AiInferenceTaskType.intelligenceCompute),
        systemPrompt:
            'You are a platform health analyst. No PII. Focus on operational risk.',
        context: const {
          'portfolioScore': 78,
          'platformUptime': 99.92,
          'tenantProbeFailures': 2,
        },
      ),
    );
    final recommendations = response.content.isNotEmpty
        ? response.content
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .take(4)
            .toList(growable: false)
        : const [
            'Prioritize tenant isolation probe failures in sch_102',
            'Scale workflow engine during admissions peak',
            'Complete pending access reviews before production cutover',
          ];
    return PlatformHealthIntelligence(
      overallScore: 81,
      scores: const [
        PlatformHealthScore(
          dimension: 'Platform',
          score: 86,
          band: 'Healthy',
        ),
        PlatformHealthScore(
          dimension: 'Tenant',
          score: 78,
          band: 'Watch',
        ),
        PlatformHealthScore(
          dimension: 'School Portfolio',
          score: 74,
          band: 'Watch',
        ),
      ],
      riskIndicators: const [
        RiskIndicator(
          id: 'risk_1',
          title: 'Tenant isolation degradation',
          severity: 'high',
          detail: '2 of 213 probes failing — investigate sch_102',
        ),
        RiskIndicator(
          id: 'risk_2',
          title: 'Workflow backlog',
          severity: 'medium',
          detail: 'Admissions queue depth above SLA threshold',
        ),
        RiskIndicator(
          id: 'risk_3',
          title: 'School churn signal',
          severity: 'medium',
          detail: 'Akshara Horizon Campus health score 42',
        ),
      ],
      aiRecommendations: recommendations,
      generatedAt: DateTime(2026, 6, 15, 9, 0),
    );
  }
}
