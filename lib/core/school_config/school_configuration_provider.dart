import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/shared_preferences_provider.dart';
import '../../features/admin/models/admin_nav_models.dart';
import 'school_capability_registry.dart';
import 'school_configuration_models.dart';
import 'school_configuration_storage.dart';

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
    final storage = ref.read(schoolConfigurationStorageProvider);
    return storage?.readSync() ?? SchoolConfiguration.demoDefault();
  }

  Future<void> apply(SchoolConfiguration config) async {
    final next = config.copyWith(configuredAt: DateTime.now());
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
