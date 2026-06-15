import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/audit/audit_provider.dart';
import '../../core/tenant/tenant_provider.dart';
import '../auth/auth_provider.dart';

Future<void> recordManagementAudit(
  Ref ref, {
  required String action,
  required String entityId,
  AuditEventType type = AuditEventType.leadUpdated,
  Map<String, String> metadata = const {},
}) {
  final auth = ref.read(authProvider);
  return recordAuditEvent(
    ref,
    type: type,
    userId: auth.claims?.userId,
    tenantId: ref.read(tenantContextProvider).tenantId,
    schoolId: auth.claims?.schoolId,
    metadata: {
      'module': 'management',
      'action': action,
      'entityId': entityId,
      ...metadata,
    },
  );
}
