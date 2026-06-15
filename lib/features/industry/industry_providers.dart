import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/industry/industry_capability_registry.dart';
import '../../core/industry/industry_context_provider.dart';
import '../../core/industry/industry_type.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';

final industryCanViewProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(
        Permission.viewIndustryFramework,
      );
});

final industryCapabilitiesProvider =
    Provider<List<IndustryCapability>>((ref) {
  return IndustryCapabilityRegistry.all();
});

final activeIndustryCapabilityProvider = Provider<IndustryCapability>((ref) {
  final industry = ref.watch(activeIndustryProvider);
  return IndustryCapabilityRegistry.forIndustry(industry);
});

/// Per-module activation toggles (in-memory MVP state).
final industryModuleActivationProvider =
    StateProvider<Map<String, bool>>((ref) {
  final capability = ref.watch(activeIndustryCapabilityProvider);
  return {
    for (final module in capability.modules) module: true,
  };
});

final industryModuleStatusProvider =
    Provider<List<IndustryModuleActivation>>((ref) {
  final capability = ref.watch(activeIndustryCapabilityProvider);
  final activations = ref.watch(industryModuleActivationProvider);
  return capability.modules
      .map(
        (moduleId) => IndustryModuleActivation(
          moduleId: moduleId,
          label: moduleId,
          isActive: activations[moduleId] ?? false,
        ),
      )
      .toList(growable: false);
});
