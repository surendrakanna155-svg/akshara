import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_provider.dart';
import '../audit/audit_event.dart';
import '../audit/audit_provider.dart';
import 'permissions.dart';

/// Records an access-denied audit event with route and permission metadata.
Future<void> recordDeniedAccess(
  WidgetRef ref, {
  required String route,
  required Permission permission,
  String? userId,
  String? tenantId,
}) {
  final auth = ref.read(authProvider);
  return ref.read(auditLoggerProvider).logTyped(
        type: AuditEventType.accessDenied,
        userId: userId ?? auth.claims?.userId,
        tenantId: tenantId ?? auth.claims?.tenantId,
        metadata: {
          'route': route,
          'permission': permission.name,
        },
      );
}

/// Records denied access from a [Ref] (auth/notifier contexts).
Future<void> recordDeniedAccessRef(
  Ref ref, {
  required String route,
  required Permission permission,
  String? userId,
  String? tenantId,
}) {
  final auth = ref.read(authProvider);
  return recordAuditEvent(
    ref,
    type: AuditEventType.accessDenied,
    userId: userId ?? auth.claims?.userId,
    tenantId: tenantId ?? auth.claims?.tenantId,
    metadata: {
      'route': route,
      'permission': permission.name,
    },
  );
}
