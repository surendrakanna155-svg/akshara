import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_mutations_provider.dart';
import 'package:akshara_erp/features/finance/finance_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  ProviderContainer containerFor(ErpRole role) {
    final container = ProviderContainer(
      overrides: [
        ...providerTestOverrides(),
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(role),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Discount rule mutations', () {
    test('createDiscountRule adds a pending rule visible in the dashboard',
        () async {
      final container = containerFor(ErpRole.financeAdmin);

      final before = await container
          .read(financeRepositoryProvider)
          .getDiscountsDashboard(query: RepositoryQuery.demo);

      final created =
          await container.read(createDiscountRuleProvider.notifier).execute(
                const CreateDiscountRuleRequest(
                  name: 'Sibling discount',
                  discountPercent: '10%',
                  appliesTo: 'Second child onwards',
                ),
              );

      expect(created, isNotNull);
      expect(created!.status, DiscountApprovalStatus.pending);

      final after = await container
          .read(financeRepositoryProvider)
          .getDiscountsDashboard(query: RepositoryQuery.demo);

      expect(after.rules.length, before.rules.length + 1);
      expect(after.rules.any((r) => r.name == 'Sibling discount'), isTrue);
    });

    test('updateDiscountRule changes name and status', () async {
      final container = containerFor(ErpRole.financeAdmin);

      final dashboard = await container
          .read(financeRepositoryProvider)
          .getDiscountsDashboard(query: RepositoryQuery.demo);
      final target = dashboard.rules.first;

      final updated =
          await container.read(updateDiscountRuleProvider.notifier).execute(
                ruleId: target.id,
                request: const UpdateDiscountRuleRequest(
                  name: 'Renamed rule',
                  status: DiscountApprovalStatus.approved,
                ),
              );

      expect(updated, isNotNull);
      expect(updated!.name, 'Renamed rule');
      expect(updated.status, DiscountApprovalStatus.approved);
    });

    test('createDiscountRule fails without manageFinance permission', () async {
      final container = containerFor(ErpRole.inventoryManager);

      await container.read(createDiscountRuleProvider.notifier).execute(
            const CreateDiscountRuleRequest(
              name: 'Blocked rule',
              discountPercent: '5%',
              appliesTo: 'Anything',
            ),
          );

      expect(container.read(createDiscountRuleProvider).hasError, isTrue);
    });
  });
}
