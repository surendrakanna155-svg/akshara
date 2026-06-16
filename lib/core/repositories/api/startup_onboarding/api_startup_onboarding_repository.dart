import '../../interfaces/startup_onboarding_repository.dart';
import '../../repository_query.dart';
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
}
