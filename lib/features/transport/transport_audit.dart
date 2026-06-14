import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/audit/audit_provider.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';

Future<void> recordTransportAudit(
  Ref ref, {
  required AuditEventType type,
  required String allocationId,
  Map<String, String> metadata = const {},
}) {
  final auth = ref.read(authProvider);
  return recordAuditEvent(
    ref,
    type: type,
    userId: auth.claims?.userId,
    tenantId: ref.read(tenantContextProvider).tenantId,
    schoolId: auth.claims?.schoolId,
    category: AuditEventCategory.workflow,
    metadata: {
      'allocationId': allocationId,
      ...metadata,
    },
  );
}
