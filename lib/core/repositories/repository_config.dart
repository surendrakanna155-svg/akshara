import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment_provider.dart';

/// Per-module API feature flags — enable independently when endpoints are ready.
final authApiEnabledProvider = Provider<bool>((ref) => false);
final admissionsApiEnabledProvider = Provider<bool>((ref) => false);
final financeApiEnabledProvider = Provider<bool>((ref) => false);
final sisApiEnabledProvider = Provider<bool>((ref) => false);
final managementApiEnabledProvider = Provider<bool>((ref) => false);
final transportApiEnabledProvider = Provider<bool>((ref) => false);
final hrApiEnabledProvider = Provider<bool>((ref) => false);
final hostelApiEnabledProvider = Provider<bool>((ref) => false);
final libraryApiEnabledProvider = Provider<bool>((ref) => false);
final inventoryApiEnabledProvider = Provider<bool>((ref) => false);
final alumniApiEnabledProvider = Provider<bool>((ref) => false);
final controlCenterApiEnabledProvider = Provider<bool>((ref) => false);

/// Returns true when the global API mode and module flag are both enabled.
bool isModuleApiEnabled(Ref ref, Provider<bool> moduleFlagProvider) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return ref.watch(moduleFlagProvider);
}

/// @deprecated Use per-module `*ApiEnabledProvider` flags instead.
final useApiRepositoriesProvider = Provider<bool>((ref) {
  return ref.watch(authApiEnabledProvider) ||
      ref.watch(admissionsApiEnabledProvider) ||
      ref.watch(financeApiEnabledProvider) ||
      ref.watch(sisApiEnabledProvider) ||
      ref.watch(managementApiEnabledProvider) ||
      ref.watch(transportApiEnabledProvider) ||
      ref.watch(hrApiEnabledProvider) ||
      ref.watch(hostelApiEnabledProvider) ||
      ref.watch(libraryApiEnabledProvider) ||
      ref.watch(inventoryApiEnabledProvider) ||
      ref.watch(alumniApiEnabledProvider) ||
      ref.watch(controlCenterApiEnabledProvider);
});
