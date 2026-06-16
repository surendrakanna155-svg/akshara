import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/tenant/tenant_provider.dart';
import 'unified_onboarding_models.dart';

final unifiedOnboardingProvider =
    NotifierProvider<UnifiedOnboardingNotifier, UnifiedOnboardingState>(
  UnifiedOnboardingNotifier.new,
);

class UnifiedOnboardingNotifier extends Notifier<UnifiedOnboardingState> {
  RepositoryQuery get _query => ref.read(repositoryQueryProvider);

  @override
  UnifiedOnboardingState build() {
    Future.microtask(_hydrateFromRepository);
    return UnifiedOnboardingState.initial().copyWith(isLoading: true);
  }

  Future<void> _hydrateFromRepository() async {
    try {
      final loaded = await ref.read(startupOnboardingRepositoryProvider).load(
            query: _query,
          );
      state = loaded.copyWith(isLoading: false, isHydrated: true);
    } catch (_) {
      state = UnifiedOnboardingState.initial().copyWith(
        isLoading: false,
        isHydrated: true,
      );
    }
  }

  void setStep(UnifiedOnboardingStep step) => _persist(state.copyWith(currentStep: step));

  void updateSchoolName(String name) => _persist(state.copyWith(schoolName: name));

  void updateBoard(String board) => _persist(state.copyWith(board: board));

  void updateCurriculum(String curriculum) =>
      _persist(state.copyWith(curriculum: curriculum, board: state.board.isEmpty ? curriculum : state.board));

  void updateAddress(String address) => _persist(state.copyWith(address: address));

  void updateContactPhone(String phone) => _persist(state.copyWith(contactPhone: phone));

  void updateContactEmail(String email) => _persist(state.copyWith(contactEmail: email));

  void updateAcademicYear(String year) => _persist(state.copyWith(academicYear: year));

  void updateClasses(String raw) {
    final classes = _splitCsv(raw);
    _persist(state.copyWith(classes: classes));
  }

  void updateSections(String raw) {
    final sections = _splitCsv(raw);
    _persist(state.copyWith(sections: sections));
  }

  void updateFeeModel(String model) => _persist(state.copyWith(feeModel: model));

  void updateFeeCategories(String raw) {
    final categories = _splitCsv(raw);
    _persist(state.copyWith(feeCategories: categories));
  }

  void updateLogoUrl(String url) => _persist(state.copyWith(logoUrl: url));

  void updateThemePrimary(String color) => _persist(state.copyWith(themePrimary: color));

  void updateThemeSecondary(String color) => _persist(state.copyWith(themeSecondary: color));

  void updateDefaultLanguage(String code) =>
      _persist(state.copyWith(defaultLanguage: code));

  void toggleModule(String moduleId, bool enabled) {
    final modules = List<String>.from(state.modulesEnabled);
    if (enabled) {
      if (!modules.contains(moduleId)) modules.add(moduleId);
    } else {
      modules.remove(moduleId);
    }
    _persist(state.copyWith(modulesEnabled: modules));
  }

  void nextStep() {
    final next = _advanceWithDefaults(state.currentStep);
    final steps = UnifiedOnboardingStep.values;
    final index = steps.indexOf(state.currentStep);
    if (index < steps.length - 1) {
      _persist(next.copyWith(currentStep: steps[index + 1]));
    }
  }

  void previousStep() {
    final steps = UnifiedOnboardingStep.values;
    final index = steps.indexOf(state.currentStep);
    if (index > 0) {
      _persist(state.copyWith(currentStep: steps[index - 1]));
    }
  }

  Future<bool> goLive() async {
    await ref.read(startupOnboardingRepositoryProvider).save(
          query: _query,
          state: state,
        );
    final result = await ref.read(startupOnboardingRepositoryProvider).goLive(
          query: _query,
        );
    state = result.state.copyWith(
      isLoading: false,
      isHydrated: true,
      provisionSummary: result.state.provisionSummary,
    );
    return result.succeeded;
  }

  UnifiedOnboardingState _advanceWithDefaults(UnifiedOnboardingStep step) {
    return switch (step) {
      UnifiedOnboardingStep.curriculum => state.board.isEmpty
          ? state.copyWith(board: state.curriculum)
          : state,
      UnifiedOnboardingStep.fees => state.feeModel.isEmpty
          ? state.copyWith(
              feeModel: 'term_wise',
              feeCategories: const ['Tuition', 'Transport', 'Activity'],
            )
          : state,
      UnifiedOnboardingStep.branding => state.copyWith(
              brandingPreferences: const {'compactNav': 'true'},
            ),
      _ => state,
    };
  }

  void _persist(UnifiedOnboardingState next) {
    state = next.copyWith(isLoading: true, goLiveValidationErrors: const []);
    ref.read(startupOnboardingRepositoryProvider).save(query: _query, state: next).then(
      (saved) {
        state = saved.copyWith(isLoading: false, isHydrated: true);
      },
      onError: (_) {
        state = next.copyWith(isLoading: false, isHydrated: true);
      },
    );
  }

  List<String> _splitCsv(String raw) {
    return raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }
}
