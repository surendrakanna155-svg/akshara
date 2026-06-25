import '../../onboarding/startup_onboarding_provision_store.dart';
import '../../../features/onboarding/ai_school_builder_models.dart';
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

  // Canonical grade ladder — mirrors the server's GRADE_LADDER for offline drafts.
  static const _ladder = [
    'Nursery', 'LKG', 'UKG', 'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4',
    'Grade 5', 'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10',
    'Grade 11', 'Grade 12',
  ];

  int _ladderIndex(String? label) {
    if (label == null || label.trim().isEmpty) return -1;
    final norm = label.trim().toLowerCase().replaceFirst('class ', 'grade ');
    final direct = _ladder.indexWhere((g) => g.toLowerCase() == norm);
    if (direct != -1) return direct;
    final num = RegExp(r'^(?:grade\s+)?(\d{1,2})$').firstMatch(norm);
    if (num != null) return _ladder.indexOf('Grade ${num.group(1)}');
    return -1;
  }

  @override
  Future<StartupOnboardingPrefillResult> aiPrefill({
    required RepositoryQuery query,
    required SchoolBrief brief,
    required UnifiedOnboardingState current,
  }) async {
    // Offline deterministic draft — no LLM. Builds a sensible structure from the
    // brief and merges identity fields, mirroring the server's fallback path.
    var lo = _ladderIndex(brief.lowestGrade);
    var hi = _ladderIndex(brief.highestGrade);
    if (lo == -1) lo = 0;
    if (hi == -1) hi = 12;
    if (hi < lo) {
      final t = lo;
      lo = hi;
      hi = t;
    }
    final classes = _ladder.sublist(lo, hi + 1);
    final sectionCount = (brief.sectionsPerGrade ?? 2).clamp(1, 6);
    final sections =
        List<String>.generate(sectionCount, (i) => String.fromCharCode(65 + i));

    final state = current.copyWith(
      schoolName: brief.schoolName.isNotEmpty ? brief.schoolName : current.schoolName,
      board: brief.board.isNotEmpty ? brief.board : current.board,
      address: brief.address.isNotEmpty ? brief.address : current.address,
      contactPhone:
          brief.contactPhone.isNotEmpty ? brief.contactPhone : current.contactPhone,
      contactEmail:
          brief.contactEmail.isNotEmpty ? brief.contactEmail : current.contactEmail,
      classes: classes,
      sections: sections,
      feeModel: current.feeModel.isEmpty ? 'term_wise' : current.feeModel,
      feeCategories: current.feeCategories.isEmpty
          ? const ['Tuition', 'Examination', 'Activity']
          : current.feeCategories,
      defaultLanguage:
          brief.languages.isNotEmpty ? brief.languages.first.toLowerCase() : current.defaultLanguage,
      isHydrated: true,
    );

    return StartupOnboardingPrefillResult(
      state: state,
      meta: const SchoolBlueprintResult(
        source: 'deterministic',
        rationale: 'Offline draft generated from your brief.',
        warnings: <String>[],
      ),
    );
  }
}
