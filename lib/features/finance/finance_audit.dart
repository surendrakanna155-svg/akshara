import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/audit/audit_provider.dart';
import '../../core/errors/api_failure.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';

/// Records a finance workflow audit event with session context.
Future<void> recordFinanceAudit(
  Ref ref, {
  required String action,
  required String entityId,
  AuditEventType type = AuditEventType.financeHandoffSent,
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

/// STEP-5 — the checker permission for fee reductions (scholarship awards /
/// discount applications). Reuses [Permission.approveFeeConcession] — the
/// SAME approval permission the Approval Center uses for the sibling
/// fee-concession type — and mirrors the backend's `requireReductionApproval`
/// (finance_fee_reductions_handlers.ts).
void assertApproveFeeConcession(Ref ref) {
  if (!ref.read(rbacServiceProvider).hasPermission(Permission.approveFeeConcession)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to approve fee reductions.',
        code: 'RBAC_APPROVE_FEE_CONCESSION',
      ),
    );
  }
}
