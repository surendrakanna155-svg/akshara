import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_preferences_provider.dart';
import 'audit_retention_policy.dart';
import 'audit_upload_queue.dart';
import 'audit_upload_service.dart';
import 'audit_upload_status.dart';

final auditRetentionPolicyProvider = Provider<AuditRetentionPolicy>((ref) {
  return const AuditRetentionPolicy();
});

final auditUploadQueueProvider = Provider<AuditUploadQueue>((ref) {
  return AuditUploadQueue(ref.watch(sharedPreferencesProvider));
});

final auditBatchUploaderProvider = Provider<AuditBatchUploader>((ref) {
  return (batch) async {
    // Server ingestion endpoint will be wired when the audit API ships.
    throw UnimplementedError('Audit batch upload is not configured');
  };
});

final auditUploadServiceProvider = Provider<AuditUploadService>((ref) {
  return AuditUploadService(
    queue: ref.watch(auditUploadQueueProvider),
    uploader: ref.watch(auditBatchUploaderProvider),
  );
});

final auditPendingUploadsProvider =
    FutureProvider<List<AuditUploadEntry>>((ref) async {
  return ref.watch(auditUploadQueueProvider).pendingEntries();
});
