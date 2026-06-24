import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';
import '../../core/providers/shared_preferences_provider.dart';
import '../../features/admin/models/admin_nav_models.dart';
import '../entitlements/entitlement_provider.dart';
import '../entitlements/entitlement_resolver.dart';
import '../network/dio_provider.dart';
import '../repositories/repository_config.dart';
import '../repositories/api/school_config/school_config_api_repository.dart';
import 'school_capability_registry.dart';
import 'school_configuration_models.dart';
import 'school_configuration_storage.dart';
import 'tenant_school_configuration_store.dart';

final schoolConfigurationStorageProvider =
    Provider<SchoolConfigurationStorage?>((ref) {
  if (!ref.exists(sharedPreferencesProvider)) return null;
  return SchoolConfigurationStorage(ref.watch(sharedPreferencesProvider));
});

/// Tenant-authoritative repository — null until [schoolConfigApiEnabledProvider]
/// is on (live release), keeping SharedPreferences as the offline path.
final schoolConfigApiRepositoryProvider =
    Provider<SchoolConfigApiRepository?>((ref) {
  if (!ref.watch(schoolConfigApiEnabledProvider)) return null;
  return SchoolConfigApiRepository(ref.watch(dioProvider));
});

final schoolConfigurationProvider =
    NotifierProvider<SchoolConfigurationNotifier, SchoolConfiguration>(
  SchoolConfigurationNotifier.new,
);

class SchoolConfigurationNotifier extends Notifier<SchoolConfiguration> {
  @override
  SchoolConfiguration build() {
    final tenantId = ref.watch(tenantContextProvider).tenantId;
    final tenantConfig =
        TenantSchoolConfigurationStore.instance.read(tenantId);

    // Synchronous seed: in-memory store, then the SharedPreferences cache,
    // then the safe default. The tenant-authoritative backend (when enabled)
    // refreshes this asynchronously below so the first frame never blocks.
    final storage = ref.read(schoolConfigurationStorageProvider);
    final seed = tenantConfig ??
        storage?.readSync() ??
        SchoolConfiguration.demoDefault();

    final api = ref.read(schoolConfigApiRepositoryProvider);
    if (api != null) {
      _refreshFromBackend(api, tenantId);
    }
    return seed;
  }

  /// Pulls the tenant-authoritative configuration and reconciles local caches.
  /// Failures are swallowed — the locally-seeded value already stands in.
  Future<void> _refreshFromBackend(
    SchoolConfigApiRepository api,
    String tenantId,
  ) async {
    try {
      final remote = await api.fetch();
      if (remote == null) return;
      TenantSchoolConfigurationStore.instance.write(
        tenantId: tenantId,
        config: remote,
        actorLabel: 'Backend sync',
      );
      await ref.read(schoolConfigurationStorageProvider)?.write(remote);
      state = remote;
    } on Object {
      // Offline / not-configured: keep the locally-seeded configuration.
    }
  }

  Future<void> apply(SchoolConfiguration config) async {
    final tenantId = ref.read(tenantContextProvider).tenantId;
    final next = TenantSchoolConfigurationStore.instance.write(
      tenantId: tenantId,
      config: config,
      actorLabel: ref.read(authProvider).displayName ?? 'Admin',
    );
    state = next;
    // Local offline cache always written; backend is the source of truth when
    // enabled but must not block the optimistic update (hybrid local fallback).
    await ref.read(schoolConfigurationStorageProvider)?.write(next);
    final api = ref.read(schoolConfigApiRepositoryProvider);
    if (api != null) {
      try {
        final persisted = await api.save(next);
        TenantSchoolConfigurationStore.instance.write(
          tenantId: tenantId,
          config: persisted,
          actorLabel: 'Backend sync',
        );
        await ref.read(schoolConfigurationStorageProvider)?.write(persisted);
        state = persisted;
      } on Object {
        // Save will retry on next apply; local cache already reflects intent.
      }
    }
  }

  Future<void> resetToDemoDefault() async {
    await apply(SchoolConfiguration.demoDefault());
  }
}

/// The school's own (unbounded) capability toggles — the personalization layer.
final localSchoolCapabilitiesProvider = Provider<SchoolCapabilities>((ref) {
  return ref.watch(schoolConfigurationProvider).capabilities;
});

/// Effective capabilities = local school config ∩ plan ceiling (B2 entitlements).
///
/// This is the single seam where plan entitlements bound the existing gating
/// engine: every consumer of [schoolCapabilitiesProvider] (admin modules, KPIs,
/// copilot topics, module ids) now respects the plan. When the entitlement API
/// is disabled the ceiling is unrestricted, so the result equals the raw local
/// configuration (pre-B2 behaviour preserved).
final schoolCapabilitiesProvider = Provider<SchoolCapabilities>((ref) {
  final local = ref.watch(localSchoolCapabilitiesProvider);
  final ceiling = ref.watch(planCapabilityCeilingProvider);
  return EntitlementResolver.intersect(local, ceiling);
});

final enabledSchoolModuleIdsProvider = Provider<List<String>>((ref) {
  return SchoolCapabilityRegistry.enabledModuleIds(
    ref.watch(schoolCapabilitiesProvider),
  );
});

final schoolAdminModuleEnabledProvider =
    Provider.family<bool, AdminModule>((ref, module) {
  return SchoolCapabilityRegistry.isAdminModuleEnabled(
    module,
    ref.watch(schoolCapabilitiesProvider),
  );
});
