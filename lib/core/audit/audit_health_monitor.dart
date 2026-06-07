import 'audit_upload_queue.dart';
import 'audit_upload_status.dart';

/// Snapshot of audit upload pipeline health for compliance monitoring.
class AuditHealthSnapshot {
  const AuditHealthSnapshot({
    required this.pendingCount,
    required this.failedCount,
    required this.uploadingCount,
    required this.lastFlushAt,
    required this.isHealthy,
    required this.issues,
  });

  final int pendingCount;
  final int failedCount;
  final int uploadingCount;
  final DateTime? lastFlushAt;
  final bool isHealthy;
  final List<String> issues;
}

/// Monitors audit queue depth and delivery health.
class AuditHealthMonitor {
  AuditHealthMonitor({
    required AuditUploadQueue queue,
    this.maxPendingThreshold = 50,
    this.maxFailedThreshold = 10,
  }) : _queue = queue;

  final AuditUploadQueue _queue;
  final int maxPendingThreshold;
  final int maxFailedThreshold;

  DateTime? _lastFlushAt;

  void recordFlush({required bool success}) {
    _lastFlushAt = DateTime.now();
  }

  Future<AuditHealthSnapshot> snapshot() async {
    final entries = await _queue.readAll();
    var pending = 0;
    var failed = 0;
    var uploading = 0;

    for (final entry in entries) {
      switch (entry.status) {
        case UploadStatus.pending:
          pending++;
        case UploadStatus.failed:
          failed++;
        case UploadStatus.uploading:
          uploading++;
        case UploadStatus.uploaded:
          break;
      }
    }

    final issues = <String>[];
    if (pending > maxPendingThreshold) {
      issues.add('Pending audit queue exceeds threshold ($pending > $maxPendingThreshold)');
    }
    if (failed > maxFailedThreshold) {
      issues.add('Failed audit uploads exceed threshold ($failed > $maxFailedThreshold)');
    }

    return AuditHealthSnapshot(
      pendingCount: pending,
      failedCount: failed,
      uploadingCount: uploading,
      lastFlushAt: _lastFlushAt,
      isHealthy: issues.isEmpty,
      issues: issues,
    );
  }
}
