import '../../interfaces/startup_onboarding_repository.dart';
import '../../repository_query.dart';
import '../../../../features/onboarding/ai_school_builder_models.dart';
import '../../../../features/onboarding/unified_onboarding_models.dart';
import 'mapper/startup_onboarding_mapper.dart';
import 'remote/startup_onboarding_remote_datasource.dart';

class ApiStartupOnboardingRepository implements StartupOnboardingRepository {
  ApiStartupOnboardingRepository({
    required StartupOnboardingRemoteDataSource remote,
    StartupOnboardingMapper mapper = const StartupOnboardingMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final StartupOnboardingRemoteDataSource _remote;
  final StartupOnboardingMapper _mapper;

  @override
  Future<UnifiedOnboardingState> load({required RepositoryQuery query}) async {
    final json = await _remote.fetchStartupOnboarding(query: query);
    return _mapper.fromJson(json).copyWith(isHydrated: true);
  }

  @override
  Future<UnifiedOnboardingState> save({
    required RepositoryQuery query,
    required UnifiedOnboardingState state,
  }) async {
    final json = await _remote.saveStartupOnboarding(
      query: query,
      payload: _mapper.toPayload(state),
    );
    return _mapper.fromJson(json).copyWith(isHydrated: true);
  }

  @override
  Future<StartupOnboardingGoLiveResult> goLive({required RepositoryQuery query}) async {
    final json = await _remote.goLiveStartupOnboarding(query: query);
    final state = _mapper.fromJson(json).copyWith(isHydrated: true);
    return StartupOnboardingGoLiveResult(
      state: state,
      validationErrors: state.goLiveValidationErrors,
    );
  }

  @override
  Future<StartupOnboardingPrefillResult> aiPrefill({
    required RepositoryQuery query,
    required SchoolBrief brief,
    required UnifiedOnboardingState current,
  }) async {
    final json = await _remote.aiPrefillStartupOnboarding(
      query: query,
      brief: brief.toJson(),
    );
    final proposal = (json['proposal'] as Map<String, dynamic>?) ?? const {};
    return StartupOnboardingPrefillResult(
      state: _mapper.applyProposal(current, proposal).copyWith(isHydrated: true),
      meta: SchoolBlueprintResult.fromJson(json),
    );
  }
}
