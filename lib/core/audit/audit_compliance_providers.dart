import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_preferences_provider.dart';
import '../repositories/api/audit/audit_upload_providers.dart';
import 'audit_retention_policy.dart';
import 'audit_upload_queue.dart';
import 'audit_upload_service.dart';
import 'audit_health_monitor.dart';
import 'audit_readiness.dart';
import 'audit_upload_status.dart';

final auditRetentionPolicyProvider = Provider<AuditRetentionPolicy>((ref) {
  return const AuditRetentionPolicy();
});

final auditUploadQueueProvider = Provider<AuditUploadQueue>((ref) {
  return AuditUploadQueue(ref.watch(sharedPreferencesProvider));
});

final auditBatchUploaderProvider = Provider<AuditBatchUploader>((ref) {
  return resolveAuditBatchUploader(ref);
});

final auditUploadServiceProvider = Provider<AuditUploadService>((ref) {
  return AuditUploadService(
    queue: ref.watch(auditUploadQueueProvider),
    uploader: ref.watch(auditBatchUploaderProvider),
  );
});

final auditHealthMonitorProvider = Provider<AuditHealthMonitor>((ref) {
  return AuditHealthMonitor(queue: ref.watch(auditUploadQueueProvider));
});

final auditReadinessVerifierProvider = Provider<AuditReadinessVerifier>((ref) {
  return const AuditReadinessVerifier();
});

final auditHealthSnapshotProvider = FutureProvider<AuditHealthSnapshot>((ref) async {
  return ref.watch(auditHealthMonitorProvider).snapshot();
});

final auditPendingUploadsProvider =
    FutureProvider<List<AuditUploadEntry>>((ref) async {
  return ref.watch(auditUploadQueueProvider).pendingEntries();
});
