import '../../../../features/platform/platform_operations/platform_operations_models.dart';
import '../../interfaces/platform_operations_repository.dart';
import '../../repository_query.dart';
import 'remote/platform_operations_remote_datasource.dart';

class ApiPlatformOperationsRepository implements PlatformOperationsRepository {
  ApiPlatformOperationsRepository({
    required PlatformOperationsRemoteDataSource remote,
  }) : _remote = remote;

  final PlatformOperationsRemoteDataSource _remote;

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  PlatformKpi _kpiFromMap(Map<String, dynamic> data) => PlatformKpi(
        id: data['id'] as String? ?? '',
        label: data['label'] as String? ?? '',
        value: data['value'] as String? ?? '',
        deltaLabel: data['deltaLabel'] as String?,
        trend: data['trend'] as String?,
        severity: data['severity'] as String?,
      );

  MetricTrendPoint _trendFromMap(Map<String, dynamic> data) =>
      MetricTrendPoint(
        label: data['label'] as String? ?? '',
        value: (data['value'] as num?)?.toDouble() ?? 0,
      );

  ServiceHealthItem _serviceFromMap(Map<String, dynamic> data) =>
      ServiceHealthItem(
        id: data['id'] as String? ?? '',
        name: data['name'] as String? ?? '',
        status: data['status'] as String? ?? '',
        uptimePercent: (data['uptimePercent'] as num?)?.toDouble() ?? 0,
        latencyMs: data['latencyMs'] as int?,
        lastCheckedAt: _parseDate(data['lastCheckedAt'] as String?),
      );

  PlatformAlert _alertFromMap(Map<String, dynamic> data) => PlatformAlert(
        id: data['id'] as String? ?? '',
        title: data['title'] as String? ?? '',
        message: data['message'] as String? ?? '',
        severity: data['severity'] as String? ?? '',
        status: data['status'] as String? ?? '',
        triggeredAt:
            _parseDate(data['triggeredAt'] as String?) ?? DateTime.now(),
        acknowledgedAt: _parseDate(data['acknowledgedAt'] as String?),
        acknowledgedBy: data['acknowledgedBy'] as String?,
        ackNote: data['ackNote'] as String?,
        source: data['source'] as String?,
      );

  @override
  Future<ObservabilityDashboard> getObservabilityDashboard({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchObservabilityDashboard(query: query);
    return ObservabilityDashboard(
      kpis: (data['kpis'] as List<dynamic>? ?? const [])
          .map((item) => _kpiFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      auditMetrics: (data['auditMetrics'] as List<dynamic>? ?? const [])
          .map(
            (item) => AuditVisibilityMetric(
              id: item['id'] as String? ?? '',
              label: item['label'] as String? ?? '',
              value: item['value'] as String? ?? '',
              status: item['status'] as String? ?? '',
              detail: item['detail'] as String?,
            ),
          )
          .toList(growable: false),
      requestTrend: (data['requestTrend'] as List<dynamic>? ?? const [])
          .map((item) => _trendFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      generatedAt: _parseDate(data['generatedAt'] as String?) ?? DateTime.now(),
    );
  }

  @override
  Future<ApplicationHealthSnapshot> getApplicationHealth({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchApplicationHealth(query: query);
    return ApplicationHealthSnapshot(
      overallStatus: data['overallStatus'] as String? ?? '',
      uptimePercent: (data['uptimePercent'] as num?)?.toDouble() ?? 0,
      services: (data['services'] as List<dynamic>? ?? const [])
          .map((item) => _serviceFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      checkedAt: _parseDate(data['checkedAt'] as String?) ?? DateTime.now(),
    );
  }

  @override
  Future<ErrorDashboard> getErrorDashboard({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchErrorDashboard(query: query);
    return ErrorDashboard(
      totalErrors24h: data['totalErrors24h'] as int? ?? 0,
      errorRatePercent: (data['errorRatePercent'] as num?)?.toDouble() ?? 0,
      topErrors: (data['topErrors'] as List<dynamic>? ?? const [])
          .map(
            (item) => ErrorSummaryItem(
              id: item['id'] as String? ?? '',
              code: item['code'] as String? ?? '',
              message: item['message'] as String? ?? '',
              count: item['count'] as int? ?? 0,
              severity: item['severity'] as String? ?? '',
              module: item['module'] as String?,
              lastSeenAt: _parseDate(item['lastSeenAt'] as String?),
            ),
          )
          .toList(growable: false),
      trend: (data['trend'] as List<dynamic>? ?? const [])
          .map((item) => _trendFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<WorkflowMonitoringSnapshot> getWorkflowMonitoring({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchWorkflowMonitoring(query: query);
    return WorkflowMonitoringSnapshot(
      totalFailures24h: data['totalFailures24h'] as int? ?? 0,
      totalQueueDepth: data['totalQueueDepth'] as int? ?? 0,
      workflows: (data['workflows'] as List<dynamic>? ?? const [])
          .map(
            (item) => WorkflowQueueMetric(
              workflowId: item['workflowId'] as String? ?? '',
              workflowName: item['workflowName'] as String? ?? '',
              failedCount: item['failedCount'] as int? ?? 0,
              queueDepth: item['queueDepth'] as int? ?? 0,
              avgDurationSec:
                  (item['avgDurationSec'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<AiMonitoringSnapshot> getAiMonitoring({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchAiMonitoring(query: query);
    return AiMonitoringSnapshot(
      totalInferences24h: data['totalInferences24h'] as int? ?? 0,
      failureRatePercent:
          (data['failureRatePercent'] as num?)?.toDouble() ?? 0,
      avgLatencyMs: (data['avgLatencyMs'] as num?)?.toDouble() ?? 0,
      cacheHitRatePercent:
          (data['cacheHitRatePercent'] as num?)?.toDouble() ?? 0,
      providerBreakdown:
          (data['providerBreakdown'] as Map<String, dynamic>? ?? const {})
              .map((key, value) => MapEntry(key, value as int? ?? 0)),
      latencyTrend: (data['latencyTrend'] as List<dynamic>? ?? const [])
          .map((item) => _trendFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<PlatformMonitoringSnapshot> getPlatformMonitoring({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchPlatformMonitoring(query: query);
    return PlatformMonitoringSnapshot(
      overallStatus: data['overallStatus'] as String? ?? '',
      services: (data['services'] as List<dynamic>? ?? const [])
          .map((item) => _serviceFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      infrastructureKpis: (data['infrastructureKpis'] as List<dynamic>? ??
              const [])
          .map((item) => _kpiFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<SchoolHealthMonitoringSnapshot> getSchoolHealthMonitoring({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchSchoolHealthMonitoring(query: query);
    return SchoolHealthMonitoringSnapshot(
      portfolioScore: data['portfolioScore'] as int? ?? 0,
      atRiskCount: data['atRiskCount'] as int? ?? 0,
      schools: (data['schools'] as List<dynamic>? ?? const [])
          .map(
            (item) => SchoolHealthRow(
              schoolId: item['schoolId'] as String? ?? '',
              schoolName: item['schoolName'] as String? ?? '',
              healthScore: item['healthScore'] as int? ?? 0,
              status: item['status'] as String? ?? '',
              openIncidents: item['openIncidents'] as int? ?? 0,
              region: item['region'] as String?,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<SystemMetricsSnapshot> getSystemMetrics({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchSystemMetrics(query: query);
    return SystemMetricsSnapshot(
      cpuPercent: (data['cpuPercent'] as num?)?.toDouble() ?? 0,
      memoryPercent: (data['memoryPercent'] as num?)?.toDouble() ?? 0,
      requestsPerMinute: data['requestsPerMinute'] as int? ?? 0,
      cpuTrend: (data['cpuTrend'] as List<dynamic>? ?? const [])
          .map((item) => _trendFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      memoryTrend: (data['memoryTrend'] as List<dynamic>? ?? const [])
          .map((item) => _trendFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      requestTrend: (data['requestTrend'] as List<dynamic>? ?? const [])
          .map((item) => _trendFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<List<AlertDefinition>> listAlertDefinitions({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchAlertDefinitions(query: query);
    return rows
        .map(
          (item) => AlertDefinition(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            metric: item['metric'] as String? ?? '',
            threshold: item['threshold'] as String? ?? '',
            severity: item['severity'] as String? ?? '',
            enabled: item['enabled'] as bool? ?? false,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<PlatformAlert>> listActiveAlerts({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchActiveAlerts(query: query);
    return rows.map(_alertFromMap).toList(growable: false);
  }

  @override
  Future<List<PlatformAlert>> listAlertHistory({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchAlertHistory(query: query);
    return rows.map(_alertFromMap).toList(growable: false);
  }

  @override
  Future<PlatformAlert> acknowledgeAlert({
    required RepositoryQuery query,
    required String alertId,
    String? note,
  }) async {
    final data = await _remote.acknowledgeAlert(
      query: query,
      alertId: alertId,
      note: note,
    );
    return _alertFromMap(data);
  }

  @override
  Future<TenantIsolationDashboard> getTenantIsolationDashboard({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchTenantIsolationDashboard(query: query);
    return TenantIsolationDashboard(
      totalProbes: data['totalProbes'] as int? ?? 0,
      passedProbes: data['passedProbes'] as int? ?? 0,
      boundaryStatus: data['boundaryStatus'] as String? ?? '',
      probes: (data['probes'] as List<dynamic>? ?? const [])
          .map(
            (item) => TenantProbeSummary(
              probeId: item['probeId'] as String? ?? '',
              label: item['label'] as String? ?? '',
              passed: item['passed'] as bool? ?? false,
              detail: item['detail'] as String? ?? '',
            ),
          )
          .toList(growable: false),
      lastVerifiedAt:
          _parseDate(data['lastVerifiedAt'] as String?) ?? DateTime.now(),
    );
  }

  @override
  Future<TenantVerificationReport> runTenantVerification({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.runTenantVerification(query: query);
    return TenantVerificationReport(
      reportId: data['reportId'] as String? ?? '',
      status: data['status'] as String? ?? '',
      passedCount: data['passedCount'] as int? ?? 0,
      failedCount: data['failedCount'] as int? ?? 0,
      findings: (data['findings'] as List<dynamic>? ?? const [])
          .map(
            (item) => TenantVerificationFinding(
              id: item['id'] as String? ?? '',
              severity: item['severity'] as String? ?? '',
              message: item['message'] as String? ?? '',
              resolved: item['resolved'] as bool? ?? false,
            ),
          )
          .toList(growable: false),
      completedAt:
          _parseDate(data['completedAt'] as String?) ?? DateTime.now(),
    );
  }

  @override
  Future<List<TenantDiagnostic>> getTenantDiagnostics({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchTenantDiagnostics(query: query);
    return rows
        .map(
          (item) => TenantDiagnostic(
            tenantId: item['tenantId'] as String? ?? '',
            tenantName: item['tenantName'] as String? ?? '',
            isolationScore: item['isolationScore'] as int? ?? 0,
            status: item['status'] as String? ?? '',
            issues: (item['issues'] as List<dynamic>? ?? const [])
                .map((issue) => issue.toString())
                .toList(growable: false),
            lastCheckedAt:
                _parseDate(item['lastCheckedAt'] as String?) ?? DateTime.now(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<SecurityDashboard> getSecurityDashboard({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchSecurityDashboard(query: query);
    return SecurityDashboard(
      kpis: (data['kpis'] as List<dynamic>? ?? const [])
          .map((item) => _kpiFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      threatLevel: data['threatLevel'] as String? ?? '',
      openFindings: data['openFindings'] as int? ?? 0,
      lastScanAt: _parseDate(data['lastScanAt'] as String?) ?? DateTime.now(),
    );
  }

  @override
  Future<PermissionAuditSummary> getPermissionAuditSummary({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchPermissionAuditSummary(query: query);
    return PermissionAuditSummary(
      totalPermissions: data['totalPermissions'] as int? ?? 0,
      anomalyCount: data['anomalyCount'] as int? ?? 0,
      rows: (data['rows'] as List<dynamic>? ?? const [])
          .map(
            (item) => PermissionAuditRow(
              permission: item['permission'] as String? ?? '',
              roleCount: item['roleCount'] as int? ?? 0,
              userCount: item['userCount'] as int? ?? 0,
              anomalyFlag: item['anomalyFlag'] as bool? ?? false,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<RoleAuditSummary> getRoleAuditSummary({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchRoleAuditSummary(query: query);
    return RoleAuditSummary(
      totalRoles: data['totalRoles'] as int? ?? 0,
      staleCount: data['staleCount'] as int? ?? 0,
      rows: (data['rows'] as List<dynamic>? ?? const [])
          .map(
            (item) => RoleAuditRow(
              role: item['role'] as String? ?? '',
              permissionCount: item['permissionCount'] as int? ?? 0,
              userCount: item['userCount'] as int? ?? 0,
              lastReviewedAt:
                  _parseDate(item['lastReviewedAt'] as String?),
              stale: item['stale'] as bool? ?? false,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<List<MutationAuditEntry>> listMutationAudits({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchMutationAudits(query: query);
    return rows
        .map(
          (item) => MutationAuditEntry(
            id: item['id'] as String? ?? '',
            mutationId: item['mutationId'] as String? ?? '',
            actor: item['actor'] as String? ?? '',
            module: item['module'] as String? ?? '',
            occurredAt:
                _parseDate(item['occurredAt'] as String?) ?? DateTime.now(),
            success: item['success'] as bool? ?? false,
            detail: item['detail'] as String?,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<PrivilegedAction>> listPrivilegedActions({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchPrivilegedActions(query: query);
    return rows
        .map(
          (item) => PrivilegedAction(
            id: item['id'] as String? ?? '',
            action: item['action'] as String? ?? '',
            actor: item['actor'] as String? ?? '',
            target: item['target'] as String? ?? '',
            occurredAt:
                _parseDate(item['occurredAt'] as String?) ?? DateTime.now(),
            riskLevel: item['riskLevel'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<AccessReviewItem>> listAccessReviews({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchAccessReviews(query: query);
    return rows
        .map(
          (item) => AccessReviewItem(
            id: item['id'] as String? ?? '',
            subject: item['subject'] as String? ?? '',
            role: item['role'] as String? ?? '',
            dueAt: _parseDate(item['dueAt'] as String?) ?? DateTime.now(),
            status: item['status'] as String? ?? '',
            reviewer: item['reviewer'] as String?,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<AccessReviewItem> completeAccessReview({
    required RepositoryQuery query,
    required String reviewId,
  }) async {
    final data = await _remote.completeAccessReview(
      query: query,
      reviewId: reviewId,
    );
    return AccessReviewItem(
      id: data['id'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      role: data['role'] as String? ?? '',
      dueAt: _parseDate(data['dueAt'] as String?) ?? DateTime.now(),
      status: data['status'] as String? ?? '',
      reviewer: data['reviewer'] as String?,
    );
  }

  @override
  Future<List<SecurityRecommendation>> getSecurityRecommendations({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchSecurityRecommendations(query: query);
    return rows
        .map(
          (item) => SecurityRecommendation(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            detail: item['detail'] as String? ?? '',
            priority: item['priority'] as String? ?? '',
            confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<ProductionReadinessReport> getProductionReadinessReport({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchProductionReadinessReport(query: query);
    return ProductionReadinessReport(
      overallScore: data['overallScore'] as int? ?? 0,
      status: data['status'] as String? ?? '',
      generatedAt:
          _parseDate(data['generatedAt'] as String?) ?? DateTime.now(),
      categories: (data['categories'] as List<dynamic>? ?? const [])
          .map(
            (category) => ReadinessCategory(
              id: category['id'] as String? ?? '',
              name: category['name'] as String? ?? '',
              score: category['score'] as int? ?? 0,
              items: (category['items'] as List<dynamic>? ?? const [])
                  .map(
                    (item) => ReadinessCheckItem(
                      id: item['id'] as String? ?? '',
                      label: item['label'] as String? ?? '',
                      passed: item['passed'] as bool? ?? false,
                      detail: item['detail'] as String?,
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<ErrorIntelligenceSnapshot> getErrorIntelligence({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchErrorIntelligence(query: query);
    return ErrorIntelligenceSnapshot(
      totalClassified: data['totalClassified'] as int? ?? 0,
      classifications: (data['classifications'] as List<dynamic>? ?? const [])
          .map(
            (item) => ErrorClassification(
              category: item['category'] as String? ?? '',
              count: item['count'] as int? ?? 0,
              percent: (item['percent'] as num?)?.toDouble() ?? 0,
              trend: item['trend'] as String? ?? '',
            ),
          )
          .toList(growable: false),
      spikeAlerts: (data['spikeAlerts'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      trend: (data['trend'] as List<dynamic>? ?? const [])
          .map((item) => _trendFromMap(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<List<ErrorRecommendation>> getErrorRecommendations({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchErrorRecommendations(query: query);
    return rows
        .map(
          (item) => ErrorRecommendation(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            detail: item['detail'] as String? ?? '',
            confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
            relatedErrorCode: item['relatedErrorCode'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<PlatformHealthIntelligence> getPlatformHealthIntelligence({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchPlatformHealthIntelligence(query: query);
    return PlatformHealthIntelligence(
      overallScore: data['overallScore'] as int? ?? 0,
      scores: (data['scores'] as List<dynamic>? ?? const [])
          .map(
            (item) => PlatformHealthScore(
              dimension: item['dimension'] as String? ?? '',
              score: item['score'] as int? ?? 0,
              band: item['band'] as String? ?? '',
            ),
          )
          .toList(growable: false),
      riskIndicators: (data['riskIndicators'] as List<dynamic>? ?? const [])
          .map(
            (item) => RiskIndicator(
              id: item['id'] as String? ?? '',
              title: item['title'] as String? ?? '',
              severity: item['severity'] as String? ?? '',
              detail: item['detail'] as String? ?? '',
            ),
          )
          .toList(growable: false),
      aiRecommendations:
          (data['aiRecommendations'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false),
      generatedAt:
          _parseDate(data['generatedAt'] as String?) ?? DateTime.now(),
    );
  }
}
