import 'package:flutter/foundation.dart';

@immutable
class PlatformKpi {
  const PlatformKpi({
    required this.id,
    required this.label,
    required this.value,
    this.deltaLabel,
    this.trend,
    this.severity,
  });

  final String id;
  final String label;
  final String value;
  final String? deltaLabel;
  final String? trend;
  final String? severity;
}

@immutable
class MetricTrendPoint {
  const MetricTrendPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

@immutable
class AuditVisibilityMetric {
  const AuditVisibilityMetric({
    required this.id,
    required this.label,
    required this.value,
    required this.status,
    this.detail,
  });

  final String id;
  final String label;
  final String value;
  final String status;
  final String? detail;
}

@immutable
class ObservabilityDashboard {
  const ObservabilityDashboard({
    required this.kpis,
    required this.auditMetrics,
    required this.requestTrend,
    required this.generatedAt,
  });

  final List<PlatformKpi> kpis;
  final List<AuditVisibilityMetric> auditMetrics;
  final List<MetricTrendPoint> requestTrend;
  final DateTime generatedAt;
}

@immutable
class ServiceHealthItem {
  const ServiceHealthItem({
    required this.id,
    required this.name,
    required this.status,
    required this.uptimePercent,
    this.latencyMs,
    this.lastCheckedAt,
  });

  final String id;
  final String name;
  final String status;
  final double uptimePercent;
  final int? latencyMs;
  final DateTime? lastCheckedAt;
}

@immutable
class ApplicationHealthSnapshot {
  const ApplicationHealthSnapshot({
    required this.overallStatus,
    required this.uptimePercent,
    required this.services,
    required this.checkedAt,
  });

  final String overallStatus;
  final double uptimePercent;
  final List<ServiceHealthItem> services;
  final DateTime checkedAt;
}

@immutable
class ErrorSummaryItem {
  const ErrorSummaryItem({
    required this.id,
    required this.code,
    required this.message,
    required this.count,
    required this.severity,
    this.module,
    this.lastSeenAt,
  });

  final String id;
  final String code;
  final String message;
  final int count;
  final String severity;
  final String? module;
  final DateTime? lastSeenAt;
}

@immutable
class ErrorDashboard {
  const ErrorDashboard({
    required this.totalErrors24h,
    required this.errorRatePercent,
    required this.topErrors,
    required this.trend,
  });

  final int totalErrors24h;
  final double errorRatePercent;
  final List<ErrorSummaryItem> topErrors;
  final List<MetricTrendPoint> trend;
}

@immutable
class WorkflowQueueMetric {
  const WorkflowQueueMetric({
    required this.workflowId,
    required this.workflowName,
    required this.failedCount,
    required this.queueDepth,
    required this.avgDurationSec,
  });

  final String workflowId;
  final String workflowName;
  final int failedCount;
  final int queueDepth;
  final double avgDurationSec;
}

@immutable
class WorkflowMonitoringSnapshot {
  const WorkflowMonitoringSnapshot({
    required this.totalFailures24h,
    required this.totalQueueDepth,
    required this.workflows,
  });

  final int totalFailures24h;
  final int totalQueueDepth;
  final List<WorkflowQueueMetric> workflows;
}

@immutable
class AiMonitoringSnapshot {
  const AiMonitoringSnapshot({
    required this.totalInferences24h,
    required this.failureRatePercent,
    required this.avgLatencyMs,
    required this.cacheHitRatePercent,
    required this.providerBreakdown,
    required this.latencyTrend,
  });

  final int totalInferences24h;
  final double failureRatePercent;
  final double avgLatencyMs;
  final double cacheHitRatePercent;
  final Map<String, int> providerBreakdown;
  final List<MetricTrendPoint> latencyTrend;
}

@immutable
class PlatformMonitoringSnapshot {
  const PlatformMonitoringSnapshot({
    required this.overallStatus,
    required this.services,
    required this.infrastructureKpis,
  });

  final String overallStatus;
  final List<ServiceHealthItem> services;
  final List<PlatformKpi> infrastructureKpis;
}

@immutable
class SchoolHealthRow {
  const SchoolHealthRow({
    required this.schoolId,
    required this.schoolName,
    required this.healthScore,
    required this.status,
    required this.openIncidents,
    this.region,
  });

  final String schoolId;
  final String schoolName;
  final int healthScore;
  final String status;
  final int openIncidents;
  final String? region;
}

@immutable
class SchoolHealthMonitoringSnapshot {
  const SchoolHealthMonitoringSnapshot({
    required this.portfolioScore,
    required this.schools,
    required this.atRiskCount,
  });

  final int portfolioScore;
  final List<SchoolHealthRow> schools;
  final int atRiskCount;
}

@immutable
class SystemMetricsSnapshot {
  const SystemMetricsSnapshot({
    required this.cpuPercent,
    required this.memoryPercent,
    required this.requestsPerMinute,
    required this.cpuTrend,
    required this.memoryTrend,
    required this.requestTrend,
  });

  final double cpuPercent;
  final double memoryPercent;
  final int requestsPerMinute;
  final List<MetricTrendPoint> cpuTrend;
  final List<MetricTrendPoint> memoryTrend;
  final List<MetricTrendPoint> requestTrend;
}

@immutable
class AlertDefinition {
  const AlertDefinition({
    required this.id,
    required this.name,
    required this.metric,
    required this.threshold,
    required this.severity,
    required this.enabled,
  });

  final String id;
  final String name;
  final String metric;
  final String threshold;
  final String severity;
  final bool enabled;
}

@immutable
class PlatformAlert {
  const PlatformAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.status,
    required this.triggeredAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.ackNote,
    this.source,
  });

  final String id;
  final String title;
  final String message;
  final String severity;
  final String status;
  final DateTime triggeredAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final String? ackNote;
  final String? source;

  PlatformAlert copyWith({
    String? status,
    DateTime? acknowledgedAt,
    String? acknowledgedBy,
    String? ackNote,
  }) {
    return PlatformAlert(
      id: id,
      title: title,
      message: message,
      severity: severity,
      status: status ?? this.status,
      triggeredAt: triggeredAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      ackNote: ackNote ?? this.ackNote,
      source: source,
    );
  }
}

@immutable
class TenantProbeSummary {
  const TenantProbeSummary({
    required this.probeId,
    required this.label,
    required this.passed,
    required this.detail,
  });

  final String probeId;
  final String label;
  final bool passed;
  final String detail;
}

@immutable
class TenantIsolationDashboard {
  const TenantIsolationDashboard({
    required this.totalProbes,
    required this.passedProbes,
    required this.boundaryStatus,
    required this.probes,
    required this.lastVerifiedAt,
  });

  final int totalProbes;
  final int passedProbes;
  final String boundaryStatus;
  final List<TenantProbeSummary> probes;
  final DateTime lastVerifiedAt;
}

@immutable
class TenantVerificationFinding {
  const TenantVerificationFinding({
    required this.id,
    required this.severity,
    required this.message,
    required this.resolved,
  });

  final String id;
  final String severity;
  final String message;
  final bool resolved;
}

@immutable
class TenantVerificationReport {
  const TenantVerificationReport({
    required this.reportId,
    required this.status,
    required this.passedCount,
    required this.failedCount,
    required this.findings,
    required this.completedAt,
  });

  final String reportId;
  final String status;
  final int passedCount;
  final int failedCount;
  final List<TenantVerificationFinding> findings;
  final DateTime completedAt;
}

@immutable
class TenantDiagnostic {
  const TenantDiagnostic({
    required this.tenantId,
    required this.tenantName,
    required this.isolationScore,
    required this.status,
    required this.issues,
    required this.lastCheckedAt,
  });

  final String tenantId;
  final String tenantName;
  final int isolationScore;
  final String status;
  final List<String> issues;
  final DateTime lastCheckedAt;
}

@immutable
class SecurityDashboard {
  const SecurityDashboard({
    required this.kpis,
    required this.threatLevel,
    required this.openFindings,
    required this.lastScanAt,
  });

  final List<PlatformKpi> kpis;
  final String threatLevel;
  final int openFindings;
  final DateTime lastScanAt;
}

@immutable
class PermissionAuditRow {
  const PermissionAuditRow({
    required this.permission,
    required this.roleCount,
    required this.userCount,
    required this.anomalyFlag,
  });

  final String permission;
  final int roleCount;
  final int userCount;
  final bool anomalyFlag;
}

@immutable
class PermissionAuditSummary {
  const PermissionAuditSummary({
    required this.totalPermissions,
    required this.anomalyCount,
    required this.rows,
  });

  final int totalPermissions;
  final int anomalyCount;
  final List<PermissionAuditRow> rows;
}

@immutable
class RoleAuditRow {
  const RoleAuditRow({
    required this.role,
    required this.permissionCount,
    required this.userCount,
    required this.lastReviewedAt,
    required this.stale,
  });

  final String role;
  final int permissionCount;
  final int userCount;
  final DateTime? lastReviewedAt;
  final bool stale;
}

@immutable
class RoleAuditSummary {
  const RoleAuditSummary({
    required this.totalRoles,
    required this.staleCount,
    required this.rows,
  });

  final int totalRoles;
  final int staleCount;
  final List<RoleAuditRow> rows;
}

@immutable
class MutationAuditEntry {
  const MutationAuditEntry({
    required this.id,
    required this.mutationId,
    required this.actor,
    required this.module,
    required this.occurredAt,
    required this.success,
    this.detail,
  });

  final String id;
  final String mutationId;
  final String actor;
  final String module;
  final DateTime occurredAt;
  final bool success;
  final String? detail;
}

@immutable
class PrivilegedAction {
  const PrivilegedAction({
    required this.id,
    required this.action,
    required this.actor,
    required this.target,
    required this.occurredAt,
    required this.riskLevel,
  });

  final String id;
  final String action;
  final String actor;
  final String target;
  final DateTime occurredAt;
  final String riskLevel;
}

@immutable
class AccessReviewItem {
  const AccessReviewItem({
    required this.id,
    required this.subject,
    required this.role,
    required this.dueAt,
    required this.status,
    this.reviewer,
  });

  final String id;
  final String subject;
  final String role;
  final DateTime dueAt;
  final String status;
  final String? reviewer;

  AccessReviewItem copyWith({String? status, String? reviewer}) {
    return AccessReviewItem(
      id: id,
      subject: subject,
      role: role,
      dueAt: dueAt,
      status: status ?? this.status,
      reviewer: reviewer ?? this.reviewer,
    );
  }
}

@immutable
class SecurityRecommendation {
  const SecurityRecommendation({
    required this.id,
    required this.title,
    required this.detail,
    required this.priority,
    required this.confidence,
  });

  final String id;
  final String title;
  final String detail;
  final String priority;
  final double confidence;
}

@immutable
class ReadinessCheckItem {
  const ReadinessCheckItem({
    required this.id,
    required this.label,
    required this.passed,
    this.detail,
  });

  final String id;
  final String label;
  final bool passed;
  final String? detail;
}

@immutable
class ReadinessCategory {
  const ReadinessCategory({
    required this.id,
    required this.name,
    required this.score,
    required this.items,
  });

  final String id;
  final String name;
  final int score;
  final List<ReadinessCheckItem> items;
}

@immutable
class ProductionReadinessReport {
  const ProductionReadinessReport({
    required this.overallScore,
    required this.status,
    required this.categories,
    required this.generatedAt,
  });

  final int overallScore;
  final String status;
  final List<ReadinessCategory> categories;
  final DateTime generatedAt;
}

@immutable
class ErrorClassification {
  const ErrorClassification({
    required this.category,
    required this.count,
    required this.percent,
    required this.trend,
  });

  final String category;
  final int count;
  final double percent;
  final String trend;
}

@immutable
class ErrorIntelligenceSnapshot {
  const ErrorIntelligenceSnapshot({
    required this.totalClassified,
    required this.classifications,
    required this.spikeAlerts,
    required this.trend,
  });

  final int totalClassified;
  final List<ErrorClassification> classifications;
  final List<String> spikeAlerts;
  final List<MetricTrendPoint> trend;
}

@immutable
class ErrorRecommendation {
  const ErrorRecommendation({
    required this.id,
    required this.title,
    required this.detail,
    required this.confidence,
    required this.relatedErrorCode,
  });

  final String id;
  final String title;
  final String detail;
  final double confidence;
  final String relatedErrorCode;
}

@immutable
class PlatformHealthScore {
  const PlatformHealthScore({
    required this.dimension,
    required this.score,
    required this.band,
  });

  final String dimension;
  final int score;
  final String band;
}

@immutable
class RiskIndicator {
  const RiskIndicator({
    required this.id,
    required this.title,
    required this.severity,
    required this.detail,
  });

  final String id;
  final String title;
  final String severity;
  final String detail;
}

@immutable
class PlatformHealthIntelligence {
  const PlatformHealthIntelligence({
    required this.overallScore,
    required this.scores,
    required this.riskIndicators,
    required this.aiRecommendations,
    required this.generatedAt,
  });

  final int overallScore;
  final List<PlatformHealthScore> scores;
  final List<RiskIndicator> riskIndicators;
  final List<String> aiRecommendations;
  final DateTime generatedAt;
}
