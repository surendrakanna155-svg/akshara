import '../../onboarding/startup_onboarding_provision_store.dart';
import '../../../features/onboarding/unified_onboarding_models.dart';
import '../../onboarding/tenant_onboarding_store.dart';
import '../interfaces/startup_onboarding_repository.dart';
import '../repository_query.dart';

/// In-memory tenant store — used when API mode is off and for unit tests.
class MockStartupOnboardingRepository implements StartupOnboardingRepository {
  @override
  Future<UnifiedOnboardingState> load({required RepositoryQuery query}) async {
    return TenantOnboardingStore.instance
        .load(query.tenantId)
        .copyWith(isHydrated: true);
  }

  @override
  Future<UnifiedOnboardingState> save({
    required RepositoryQuery query,
    required UnifiedOnboardingState state,
  }) async {
    return TenantOnboardingStore.instance.save(query.tenantId, state);
  }

  @override
  Future<StartupOnboardingGoLiveResult> goLive({required RepositoryQuery query}) async {
    final current = TenantOnboardingStore.instance.load(query.tenantId);
    final errors = UnifiedOnboardingValidation.validateForGoLive(current);
    if (errors.isNotEmpty) {
      final blocked = TenantOnboardingStore.instance.save(
        query.tenantId,
        current.copyWith(goLiveValidationErrors: errors),
      );
      return StartupOnboardingGoLiveResult(
        state: blocked,
        validationErrors: errors,
      );
    }
    final live = TenantOnboardingStore.instance.goLive(query.tenantId);
    final provision = StartupOnboardingProvisionStore.instance.save(
      query.tenantId,
      live,
    );
    return StartupOnboardingGoLiveResult(
      state: live.copyWith(provisionSummary: provision),
      validationErrors: const [],
    );
  }
}
