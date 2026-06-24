import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_provider.dart';
import '../providers/shared_preferences_provider.dart';
import '../repositories/api/entitlements/entitlement_api_repository.dart';
import '../repositories/repository_config.dart';
import '../school_config/school_configuration_models.dart';
import '../tenant/tenant_provider.dart';
import 'entitlement_models.dart';
import 'entitlement_resolver.dart';
import 'entitlement_storage.dart';

/// B2 — Entitlement Layer · Step 3 · client providers.
///
/// Resolves the org's plan and exposes the plan *ceiling* that bounds the
/// existing per-school capability gating. When the entitlement API is disabled
/// the ceiling is unrestricted, so behaviour is identical to pre-B2.

final entitlementStorageProvider = Provider<EntitlementStorage?>((ref) {
  if (!ref.exists(sharedPreferencesProvider)) return null;
  return EntitlementStorage(ref.watch(sharedPreferencesProvider));
});

/// Read-only entitlement client — null unless the entitlement API is enabled.
final entitlementApiRepositoryProvider =
    Provider<EntitlementApiRepository?>((ref) {
  if (!ref.watch(entitlementApiEnabledProvider)) return null;
  return EntitlementApiRepository(ref.watch(dioProvider));
});

/// The org's resolved subscription. Seeds synchronously from cache (or the Trial
/// fail-safe), then refreshes from the backend without blocking the first frame.
final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, ResolvedSubscription>(
  SubscriptionNotifier.new,
);

class SubscriptionNotifier extends Notifier<ResolvedSubscription> {
  @override
  ResolvedSubscription build() {
    final api = ref.watch(entitlementApiRepositoryProvider);
    // When the entitlement layer is off, there is nothing to resolve — return a
    // Trial-shaped placeholder; the ceiling provider ignores it in that mode.
    if (api == null) return ResolvedSubscription.trialFallback();

    final cached = ref.read(entitlementStorageProvider)?.readSync();
    final seed = cached ?? ResolvedSubscription.trialFallback();
    _refreshFromBackend(api);
    return seed;
  }

  /// Pulls the tenant-authoritative subscription and reconciles the cache.
  /// On failure the seeded (cached / Trial) value stands — never downgrade a
  /// live org to Trial on a transient outage.
  Future<void> _refreshFromBackend(EntitlementApiRepository api) async {
    try {
      final remote = await api.fetchSubscription();
      if (remote == null) return;
      await ref.read(entitlementStorageProvider)?.write(remote);
      state = remote;
    } on Object {
      // Offline / unreachable: keep the seeded subscription.
    }
  }

  /// Forces a re-fetch (e.g. after a plan change elsewhere).
  Future<void> refresh() async {
    final api = ref.read(entitlementApiRepositoryProvider);
    if (api != null) await _refreshFromBackend(api);
  }
}

/// The plan ceiling that bounds capability gating:
///   * entitlement API off → unrestricted (no narrowing; pre-B2 behaviour);
///   * on → derived from the resolved subscription's plan-allowed entitlements.
final planCapabilityCeilingProvider = Provider<SchoolCapabilities>((ref) {
  if (!ref.watch(entitlementApiEnabledProvider)) {
    return EntitlementResolver.unrestrictedCeiling;
  }
  final subscription = ref.watch(subscriptionProvider);
  return EntitlementResolver.planCeiling(subscription.entitlementSet);
});

/// The public plan catalog (`GET /plans`) — read-only, for later upgrade UX.
final planCatalogProvider = FutureProvider<List<SubscriptionPlan>>((ref) async {
  final api = ref.watch(entitlementApiRepositoryProvider);
  if (api == null) return const [];
  // Keep the tenant context observed so the catalog re-resolves on switch.
  ref.watch(tenantContextProvider);
  try {
    return await api.fetchPlans();
  } on Object {
    return const [];
  }
});
