import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/audit/audit_provider.dart';
import '../../core/errors/api_failure.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../auth/auth_provider.dart';

void assertManageSchoolMemories(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.manageSchoolMemories)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage school memories.',
        code: 'RBAC_MANAGE_SCHOOL_MEMORIES',
      ),
    );
  }
}

Future<void> recordMemoriesAudit(
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
      'module': 'school_memories',
      'action': action,
      'entityId': entityId,
      ...metadata,
    },
  );
}
