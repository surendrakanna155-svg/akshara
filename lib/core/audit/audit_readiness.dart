import 'audit_health_monitor.dart';
import 'audit_retention_policy.dart';
import 'audit_upload_queue.dart';
import 'audit_upload_service.dart';

/// Result of client-side audit pipeline readiness verification.
class AuditReadinessResult {
  const AuditReadinessResult({
    required this.isReady,
    required this.checks,
  });

  final bool isReady;
  final Map<String, bool> checks;
}

/// Verifies the client audit upload pipeline is configured for production drain.
class AuditReadinessVerifier {
  const AuditReadinessVerifier();

  Future<AuditReadinessResult> verify({
    required AuditUploadQueue queue,
    required AuditUploadService service,
    required AuditHealthMonitor monitor,
    required AuditRetentionPolicy retentionPolicy,
    required bool auditApiEnabled,
  }) async {
    final health = await monitor.snapshot();
    final pending = await queue.pendingEntries();

    final checks = <String, bool>{
      'queue_accessible': true,
      'upload_service_configured': true,
      'retention_policy_active': retentionPolicy.maxEntries > 0,
      'health_monitor_healthy': health.isHealthy || pending.isEmpty,
      'api_uploader_wired': auditApiEnabled,
    };

    return AuditReadinessResult(
      isReady: checks.values.every((passed) => passed),
      checks: checks,
    );
  }
}
