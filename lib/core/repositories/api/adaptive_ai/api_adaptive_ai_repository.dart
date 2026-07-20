// Adaptive AI (P3-AI-2 / W2) — API repository: remote datasource + mapper.

import '../../../../features/adaptive_ai/adaptive_ai_models.dart';
import '../../interfaces/adaptive_ai_repository.dart';
import '../../repository_query.dart';
import 'mapper/adaptive_ai_mapper.dart';
import 'remote/adaptive_ai_remote_datasource.dart';

class ApiAdaptiveAiRepository implements AdaptiveAiRepository {
  ApiAdaptiveAiRepository({
    required AdaptiveAiRemoteDataSource remote,
    AdaptiveAiMapper mapper = const AdaptiveAiMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final AdaptiveAiRemoteDataSource _remote;
  final AdaptiveAiMapper _mapper;

  @override
  Future<AdaptiveFeed> getPriorityFeed({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  }) async {
    final dto = await _remote.fetchPriorityFeed(query: query, persona: persona, limit: limit);
    return _mapper.toFeed(dto);
  }

  @override
  Future<AdaptiveFeed> getRecommendations({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  }) async {
    final dto = await _remote.fetchRecommendations(query: query, persona: persona, limit: limit);
    return _mapper.toFeed(dto);
  }

  @override
  Future<void> sendRecommendationFeedback({
    required RepositoryQuery query,
    required String itemKey,
    required String itemType,
    required AdaptiveFeedbackAction action,
  }) {
    return _remote.sendFeedback(
      query: query,
      itemKey: itemKey,
      itemType: itemType,
      action: action.name,
    );
  }

  @override
  Future<List<AdaptiveQuickAction>> getQuickActions({
    required RepositoryQuery query,
    required String persona,
  }) async {
    final dtos = await _remote.fetchQuickActions(query: query, persona: persona);
    return dtos.map(_mapper.toQuickAction).toList();
  }

  @override
  Future<UniversalSearchResult> universalSearch({
    required RepositoryQuery query,
    required String term,
    int? limit,
    int? offset,
  }) async {
    final dto = await _remote.search(query: query, term: term, limit: limit, offset: offset);
    return _mapper.toSearchResultSet(dto);
  }
}
