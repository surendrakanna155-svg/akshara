import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/industry/industry_context_provider.dart';
import '../../core/industry/industry_type.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import 'industry_providers.dart';

void assertManageIndustryFramework(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null ||
      !permissions.has(Permission.manageIndustryFramework)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage industry framework.',
        code: 'RBAC_MANAGE_INDUSTRY_FRAMEWORK',
      ),
    );
  }
}

class SetActiveIndustryNotifier extends AsyncNotifier<IndustryType?> {
  @override
  FutureOr<IndustryType?> build() => null;

  Future<IndustryType?> execute({required IndustryType industry}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageIndustryFramework(ref);
      ref.read(industryOverrideProvider.notifier).state = industry;
      ref.invalidate(activeIndustryCapabilityProvider);
      ref.invalidate(industryModuleStatusProvider);
      return industry;
    });
    return state.valueOrNull;
  }
}

final setActiveIndustryProvider =
    AsyncNotifierProvider<SetActiveIndustryNotifier, IndustryType?>(
  SetActiveIndustryNotifier.new,
);

class ActivateIndustryModuleNotifier extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute({
    required String moduleId,
    required bool isActive,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageIndustryFramework(ref);
      final current = Map<String, bool>.from(
        ref.read(industryModuleActivationProvider),
      );
      current[moduleId] = isActive;
      ref.read(industryModuleActivationProvider.notifier).state = current;
      ref.invalidate(industryModuleStatusProvider);
      return moduleId;
    });
    return state.valueOrNull;
  }
}

final activateIndustryModuleProvider =
    AsyncNotifierProvider<ActivateIndustryModuleNotifier, String?>(
  ActivateIndustryModuleNotifier.new,
);
