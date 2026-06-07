import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/audit/audit_provider.dart';
import '../../core/tenant/tenant_provider.dart';
import '../auth/auth_provider.dart';

/// Records a teacher mobile workflow audit event with session context.
Future<void> recordTeacherAudit(
  Ref ref, {
  required String action,
  required String entityId,
  Map<String, String> metadata = const {},
}) {
  final auth = ref.read(authProvider);
  return recordAuditEvent(
    ref,
    type: AuditEventType.enrollmentSubmitted,
    userId: auth.claims?.userId,
    tenantId: ref.read(tenantContextProvider).tenantId,
    schoolId: auth.claims?.schoolId,
    metadata: {
      'module': 'teacher',
      'action': action,
      'entityId': entityId,
      ...metadata,
    },
  );
}
