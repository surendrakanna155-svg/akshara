import '../../features/onboarding/unified_onboarding_models.dart';

/// Records domain entities provisioned during startup onboarding go-live (mock/API parity).
final class StartupOnboardingProvisionStore {
  StartupOnboardingProvisionStore._();

  static final StartupOnboardingProvisionStore instance =
      StartupOnboardingProvisionStore._();

  final Map<String, UnifiedOnboardingProvisionSummary> _byTenant = {};

  UnifiedOnboardingProvisionSummary? read(String tenantId) => _byTenant[tenantId];

  UnifiedOnboardingProvisionSummary save(
    String tenantId,
    UnifiedOnboardingState state,
  ) {
    final summary = UnifiedOnboardingProvisionSummary(
      schoolProfileUpdated: state.schoolName.isNotEmpty,
      brandingUpdated: state.themePrimary.isNotEmpty,
      academicYearLabel: state.academicYear,
      classCount: state.classes.length,
      sectionCount: state.classes.length * state.sections.length,
      feeStructureCount: state.feeCategories.isEmpty ? 1 : 1,
      warnings: const [],
      provisioned: true,
    );
    _byTenant[tenantId] = summary;
    return summary;
  }

  void reset(String tenantId) => _byTenant.remove(tenantId);
}
