import '../../features/onboarding/unified_onboarding_models.dart';

/// Tenant-backed onboarding state — single record per tenant (upsert on save).
final class TenantOnboardingStore {
  TenantOnboardingStore._();

  static final TenantOnboardingStore instance = TenantOnboardingStore._();

  final Map<String, UnifiedOnboardingState> _byTenant = {};

  UnifiedOnboardingState load(String tenantId) =>
      _byTenant[tenantId] ?? UnifiedOnboardingState.initial();

  UnifiedOnboardingState save(
    String tenantId,
    UnifiedOnboardingState state,
  ) {
    final saved = state.copyWith(
      lastSavedAt: DateTime.now(),
      isHydrated: true,
    );
    _byTenant[tenantId] = saved;
    return saved;
  }

  UnifiedOnboardingState goLive(String tenantId) {
    final current = load(tenantId);
    final errors = UnifiedOnboardingValidation.validateForGoLive(current);
    if (errors.isNotEmpty) {
      return save(
        tenantId,
        current.copyWith(goLiveValidationErrors: errors),
      );
    }
    return save(
      tenantId,
      current.copyWith(
        isLive: true,
        currentStep: UnifiedOnboardingStep.goLive,
        goLiveValidationErrors: const [],
      ),
    );
  }

  void reset(String tenantId) => _byTenant.remove(tenantId);
}
