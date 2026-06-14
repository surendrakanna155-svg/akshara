import 'package:akshara_erp/core/repositories/mock/mock_management_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/management/management_models.dart';
import 'package:akshara_erp/features/management/management_mutations_provider.dart';
import 'package:akshara_erp/features/management/management_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  group('Management mock writes', () {
    const query = RepositoryQuery.demo;

    test('resolveManagementApproval approves pending item', () async {
      final repo = MockManagementRepository();

      final resolved = await repo.resolveManagementApproval(
        query: query,
        request: const ResolveManagementApprovalRequest(
          approvalId: 'appr_mg_1',
          status: ManagementApprovalStatus.approved,
        ),
      );

      expect(resolved.status, ManagementApprovalStatus.approved);

      final tasks = await repo.getTasksAndApprovals(query: query);
      final updated = tasks.approvals.firstWhere((a) => a.id == 'appr_mg_1');
      expect(updated.status, ManagementApprovalStatus.approved);
    });

    test('resolveManagementApproval rejects pending item', () async {
      final repo = MockManagementRepository();

      final resolved = await repo.resolveManagementApproval(
        query: query,
        request: const ResolveManagementApprovalRequest(
          approvalId: 'appr_mg_2',
          status: ManagementApprovalStatus.rejected,
        ),
      );

      expect(resolved.status, ManagementApprovalStatus.rejected);
    });
  });

  group('Management RBAC mutations', () {
    test('resolveManagementApproval fails without manageManagement', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(resolveManagementApprovalProvider.notifier).execute(
            const ResolveManagementApprovalRequest(
              approvalId: 'appr_mg_1',
              status: ManagementApprovalStatus.approved,
            ),
          );

      expect(container.read(resolveManagementApprovalProvider).hasError, isTrue);
    });

    test('resolveManagementApproval succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(resolveManagementApprovalProvider.notifier).execute(
            const ResolveManagementApprovalRequest(
              approvalId: 'appr_mg_3',
              status: ManagementApprovalStatus.approved,
            ),
          );

      expect(container.read(resolveManagementApprovalProvider).hasValue, isTrue);
      expect(
        container.read(resolveManagementApprovalProvider).value?.status,
        ManagementApprovalStatus.approved,
      );
    });
  });
}
