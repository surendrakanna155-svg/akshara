import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/audit/audit_event.dart';
import '../../core/audit/audit_provider.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';

/// Records an admissions workflow audit event with session context.
Future<void> recordAdmissionsAudit(
  Ref ref, {
  required AuditEventType type,
  required String entityId,
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
      'entityId': entityId,
      ...metadata,
    },
  );
}

void assertManageAdmissions(Ref ref) {
  if (!ref.read(canManageAdmissionsProvider)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage admissions.',
        code: 'RBAC_MANAGE_ADMISSIONS',
      ),
    );
  }
}

void assertApproveAdmissions(Ref ref) {
  if (!ref.read(canApproveAdmissionsProvider)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to approve admissions.',
        code: 'RBAC_APPROVE_ADMISSIONS',
      ),
    );
  }
}

/// Mutation result wrapper for UI snackbars.
class AdmissionsMutationResult<T> {
  const AdmissionsMutationResult({this.data, this.failure});

  final T? data;
  final ApiFailure? failure;

  bool get isSuccess => failure == null && data != null;
}
