import '../../interfaces/startup_onboarding_repository.dart';
import '../../repository_query.dart';
import '../../../../features/onboarding/ai_school_builder_models.dart';
import '../../../../features/onboarding/unified_onboarding_models.dart';
import '../api_exception.dart';
import 'api_startup_onboarding_repository.dart';
import '../../mock/mock_startup_onboarding_repository.dart';

class HybridStartupOnboardingRepository implements StartupOnboardingRepository {
  HybridStartupOnboardingRepository({
    required ApiStartupOnboardingRepository api,
    MockStartupOnboardingRepository? mock,
  })  : _api = api,
        _mock = mock ?? MockStartupOnboardingRepository();

  final ApiStartupOnboardingRepository _api;
  final MockStartupOnboardingRepository _mock;

  @override
  Future<UnifiedOnboardingState> load({required RepositoryQuery query}) async {
    try {
      return await _api.load(query: query);
    } on ApiNotConnectedException {
      return _mock.load(query: query);
    }
  }

  @override
  Future<UnifiedOnboardingState> save({
    required RepositoryQuery query,
    required UnifiedOnboardingState state,
  }) async {
    try {
      return await _api.save(query: query, state: state);
    } on ApiNotConnectedException {
      return _mock.save(query: query, state: state);
    }
  }

  @override
  Future<StartupOnboardingGoLiveResult> goLive({required RepositoryQuery query}) async {
    try {
      return await _api.goLive(query: query);
    } on ApiNotConnectedException {
      return _mock.goLive(query: query);
    }
  }

  @override
  Future<StartupOnboardingPrefillResult> aiPrefill({
    required RepositoryQuery query,
    required SchoolBrief brief,
    required UnifiedOnboardingState current,
  }) async {
    try {
      return await _api.aiPrefill(query: query, brief: brief, current: current);
    } on ApiNotConnectedException {
      return _mock.aiPrefill(query: query, brief: brief, current: current);
    }
  }
}
