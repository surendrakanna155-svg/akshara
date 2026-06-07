import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_preferences_provider.dart';
import 'audit_compliance_providers.dart';
import 'audit_event.dart';
import 'audit_logger.dart';

final auditLoggerProvider = Provider<AuditLogger>((ref) {
  return AuditLogger(
    ref.watch(sharedPreferencesProvider),
    retentionPolicy: ref.watch(auditRetentionPolicyProvider),
    uploadQueue: ref.watch(auditUploadQueueProvider),
  );
});

final auditEventsProvider = FutureProvider<List<AuditEvent>>((ref) async {
  return ref.watch(auditLoggerProvider).readAll();
});

/// Logs a security audit event with optional context from the active session.
Future<void> recordAuditEvent(
  Ref ref, {
  required AuditEventType type,
  String? userId,
  String? tenantId,
  String? schoolId,
  String? correlationId,
  AuditEventCategory? category,
  Map<String, String> metadata = const {},
}) {
  return ref.read(auditLoggerProvider).logTyped(
        type: type,
        userId: userId,
        tenantId: tenantId,
        schoolId: schoolId,
        correlationId: correlationId,
        category: category,
        metadata: metadata,
      );
}
