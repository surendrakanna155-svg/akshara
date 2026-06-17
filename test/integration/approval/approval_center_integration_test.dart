import 'package:akshara_erp/core/approvals/approval_audit.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/management/approval/approval_center_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_test_overrides.dart';
import '../../helpers/provider_test_overrides.dart';

void main() {
  group('Approval center integration — M-D2 certification', () {
    test('end-to-end approve updates queue and audit trail', () async {
      await initProviderTestPrefs();
      final repository = MockApprovalRepository();
      final container = createProviderTestContainer(
        overrides: [
          approvalRepositoryProvider.overrideWithValue(repository),
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9999999999',
              displayName: 'Principal',
              role: UserRole.staff,
              claims: AuthClaims.demoForRole(erpRole: ErpRole.principal),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(approvalCenterFutureProvider.future);
      final target = container
          .read(approvalCenterListProvider)
          .firstWhere((a) => a.type == ApprovalRequestType.examResults);

      expect(target.status, ApprovalStatus.pending);

      await container
          .read(resolveApprovalRequestProvider.notifier)
          .approve(request: target);

      container.invalidate(approvalCenterFutureProvider);
      await container.read(approvalCenterFutureProvider.future);

      final updated = container
          .read(approvalCenterListProvider)
          .firstWhere((a) => a.id == target.id);
      expect(updated.status, ApprovalStatus.approved);

      final audit = await container.read(
        approvalCenterAuditFutureProvider(target.id).future,
      );
      expect(audit.length, greaterThanOrEqualTo(2));
      expect(
        audit.map((e) => e.action).toSet(),
        containsAll({
          ApprovalAuditAction.submitted,
          ApprovalAuditAction.approved,
        }),
      );
    });

    test('end-to-end reject requires comment then updates audit', () async {
      await initProviderTestPrefs();
      final repository = MockApprovalRepository();
      final container = createProviderTestContainer(
        overrides: [
          approvalRepositoryProvider.overrideWithValue(repository),
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9999999999',
              displayName: 'Principal',
              role: UserRole.staff,
              claims: AuthClaims.demoForRole(erpRole: ErpRole.principal),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(approvalCenterFutureProvider.future);
      final target = container
          .read(approvalCenterListProvider)
          .firstWhere((a) => a.type == ApprovalRequestType.studentLeave);

      final rejected = await container
          .read(resolveApprovalRequestProvider.notifier)
          .reject(
            request: target,
            comment: 'Leave documentation incomplete.',
          );

      expect(rejected?.status, ApprovalStatus.rejected);

      final audit = await container.read(
        approvalCenterAuditFutureProvider(target.id).future,
      );
      expect(
        audit.any((e) => e.action == ApprovalAuditAction.rejected),
        isTrue,
      );
      expect(
        audit.any((e) => e.comment?.contains('Leave documentation') ?? false),
        isTrue,
      );
    });
  });
}
