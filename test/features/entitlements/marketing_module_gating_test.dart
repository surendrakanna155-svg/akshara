import 'package:akshara_erp/core/entitlements/entitlement_models.dart';
import 'package:akshara_erp/core/entitlements/entitlement_provider.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/features/admin/admin_navigation_provider.dart';
import 'package:akshara_erp/features/admin/models/admin_nav_models.dart';
import 'package:akshara_erp/features/entitlements/entitlement_module_gate.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake subscription notifier returning a fixed resolved subscription.
class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  _FakeSubscriptionNotifier(this._value);
  final ResolvedSubscription _value;
  @override
  ResolvedSubscription build() => _value;
}

ResolvedSubscription _sub(List<String> entitlements) => ResolvedSubscription(
      planSlug: 'test',
      planName: 'Test',
      tierRank: 1,
      status: SubscriptionStatus.active,
      entitlements: entitlements,
    );

void main() {
  group('B6 — Marketing module entitlement gating', () {
    test('locked when the entitlement layer is on and the plan lacks marketing',
        () {
      final container = ProviderContainer(overrides: [
        entitlementApiEnabledProvider.overrideWithValue(true),
        subscriptionProvider.overrideWith(
          () => _FakeSubscriptionNotifier(_sub(const [])),
        ),
      ]);
      addTearDown(container.dispose);
      expect(
        container.read(modulePlanLockedProvider(AdminModule.marketing)),
        isTrue,
      );
    });

    test('unlocked when the plan grants module.marketing', () {
      final container = ProviderContainer(overrides: [
        entitlementApiEnabledProvider.overrideWithValue(true),
        subscriptionProvider.overrideWith(
          () => _FakeSubscriptionNotifier(_sub(const [EntitlementSlugs.marketing])),
        ),
      ]);
      addTearDown(container.dispose);
      expect(
        container.read(modulePlanLockedProvider(AdminModule.marketing)),
        isFalse,
      );
    });

    test('never locked when the entitlement layer is disabled (pre-B2 behaviour)',
        () {
      final container = ProviderContainer(overrides: [
        entitlementApiEnabledProvider.overrideWithValue(false),
        // Even a marketing-less subscription must not lock when the layer is off.
        subscriptionProvider.overrideWith(
          () => _FakeSubscriptionNotifier(_sub(const [])),
        ),
      ]);
      addTearDown(container.dispose);
      expect(
        container.read(modulePlanLockedProvider(AdminModule.marketing)),
        isFalse,
      );
    });
  });

  group('B6 — Marketing nav destination', () {
    test('Marketing tile routes to the growth platform, gated by view permission',
        () {
      final marketing = kAllAdminNavDestinations
          .firstWhere((d) => d.module == AdminModule.marketing);
      expect(marketing.route, RouteNames.growthPlatform);
      expect(marketing.requiredPermission, Permission.viewGrowthPlatform);
      expect(marketing.label, 'Marketing');
    });
  });
}
