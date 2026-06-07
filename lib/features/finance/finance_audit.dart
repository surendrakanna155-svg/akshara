import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/audit/audit_provider.dart';
import '../../core/errors/api_failure.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';

/// Records a finance workflow audit event with session context.
Future<void> recordFinanceAudit(
  Ref ref, {
  required String action,
  required String entityId,
  Map<String, String> metadata = const {},
}) {
  final auth = ref.read(authProvider);
  return recordAuditEvent(
    ref,
    type: AuditEventType.financeHandoffSent,
    userId: auth.claims?.userId,
    tenantId: ref.read(tenantContextProvider).tenantId,
    schoolId: auth.claims?.schoolId,
    metadata: {
      'module': 'finance',
      'action': action,
      'entityId': entityId,
      ...metadata,
    },
  );
}

void assertManageFinance(Ref ref) {
  if (!ref.read(canManageFinanceProvider)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage finance.',
        code: 'RBAC_MANAGE_FINANCE',
      ),
    );
  }
}

void assertApproveRefunds(Ref ref) {
  if (!ref.read(canApproveRefundsProvider)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to approve refunds.',
        code: 'RBAC_APPROVE_REFUNDS',
      ),
    );
  }
}
