import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/operations/operations_hub_mutations_provider.dart';
import 'package:akshara_erp/features/phase5/phase5_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  group('Operations hub mutations', () {
    test('dismiss alert succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(dismissOperationsAlertProvider.notifier)
          .execute('student-risk');

      final refreshed = await container.read(operationsHubProvider.future);
      expect(
          refreshed.criticalAlerts.any((a) => a.id == 'student-risk'), isFalse);
    });

    test('complete action fails without manageManagement permission', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(completeOperationsActionProvider.notifier)
          .execute('inv-pending');

      expect(container.read(completeOperationsActionProvider).hasError, isTrue);
    });
  });

  // PRI-3 — "Daily school report" export (Operations Hub snapshot → PDF, rides
  // XCT-1). The export path shipped in C18; these close the verified
  // test-coverage gap on its RBAC guard (assertViewOperationsHub) and that it
  // produces real PDF bytes from the snapshot a viewer can already see.
  group('PRI-3 daily school report export', () {
    test('export produces PDF bytes for a hub viewer', () async {
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
          .read(exportOperationsHubReportProvider.notifier)
          .execute();

      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue);
    });

    test('export is denied without viewOperationsHub permission', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.parent),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(exportOperationsHubReportProvider.notifier).execute(),
        throwsA(isA<ApiFailureException>()),
      );
    });
  });
}
