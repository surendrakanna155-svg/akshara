import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';
import '../../core/providers/shared_preferences_provider.dart';
import '../../features/admin/models/admin_nav_models.dart';
import 'school_capability_registry.dart';
import 'school_configuration_models.dart';
import 'school_configuration_storage.dart';
import 'tenant_school_configuration_store.dart';

final schoolConfigurationStorageProvider =
    Provider<SchoolConfigurationStorage?>((ref) {
  if (!ref.exists(sharedPreferencesProvider)) return null;
  return SchoolConfigurationStorage(ref.watch(sharedPreferencesProvider));
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
    if (tenantConfig != null) return tenantConfig;

    final storage = ref.read(schoolConfigurationStorageProvider);
    return storage?.readSync() ?? SchoolConfiguration.demoDefault();
  }

  Future<void> apply(SchoolConfiguration config) async {
    final tenantId = ref.read(tenantContextProvider).tenantId;
    final next = TenantSchoolConfigurationStore.instance.write(
      tenantId: tenantId,
      config: config,
      actorLabel: ref.read(authProvider).displayName ?? 'Admin',
    );
    state = next;
    await ref.read(schoolConfigurationStorageProvider)?.write(next);
  }

  Future<void> resetToDemoDefault() async {
    await apply(SchoolConfiguration.demoDefault());
  }
}

final schoolCapabilitiesProvider = Provider<SchoolCapabilities>((ref) {
  return ref.watch(schoolConfigurationProvider).capabilities;
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
