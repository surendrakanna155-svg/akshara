import 'package:akshara_erp/core/repositories/mock/mock_management_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
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

    test('updateSettings persists editable setting value', () async {
      final repo = MockManagementRepository();
      final updated = await repo.updateSettings(
        query: query,
        request: const UpdateManagementSettingsRequest(
          updates: [
            ManagementSettingUpdate(
              sectionId: 'approvals',
              itemId: 'vendor',
              value: '₹65,000',
            ),
          ],
        ),
      );

      final setting = updated.sections
          .firstWhere((s) => s.id == 'approvals')
          .items
          .firstWhere((item) => item.id == 'vendor');
      expect(setting.value, '₹65,000');
    });
  });

  group('Management RBAC mutations', () {
    test('updateManagementSettings fails without manageManagement', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateManagementSettingsProvider.notifier).execute(
            const UpdateManagementSettingsRequest(
              updates: [
                ManagementSettingUpdate(
                  sectionId: 'school',
                  itemId: 'name',
                  value: 'Updated Name',
                ),
              ],
            ),
          );

      expect(container.read(updateManagementSettingsProvider).hasError, isTrue);
    });

    test('exportManagementDashboard succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final bytes = await container
          .read(exportManagementDashboardProvider.notifier)
          .execute();
      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue);
    });
  });
}
