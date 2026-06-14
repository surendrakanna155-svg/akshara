import '../../interfaces/copilot_repository.dart';
import '../../repository_query.dart';
import '../../../../features/copilot/copilot_models.dart';
import '../../../../features/copilot/copilot_screen_context.dart';
import 'mapper/copilot_mapper.dart';
import 'remote/copilot_remote_datasource.dart';

class ApiCopilotRepository implements CopilotRepository {
  ApiCopilotRepository({
    required CopilotRemoteDataSource remote,
    CopilotMapper mapper = const CopilotMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final CopilotRemoteDataSource _remote;
  final CopilotMapper _mapper;

  @override
  Future<List<CopilotAssistant>> getAssistants({required RepositoryQuery query}) async {
    final items = await _remote.fetchAssistants(query: query);
    return _mapper.toAssistants(items);
  }

  @override
  Future<CopilotSuggestions> getSuggestions({
    required RepositoryQuery query,
    required CopilotAssistantType assistantType,
  }) async {
    final dto = await _remote.fetchSuggestions(
      query: query,
      assistantType: assistantType,
    );
    return _mapper.toSuggestions(dto);
  }

  @override
  Future<List<CopilotSession>> getSessions({required RepositoryQuery query}) async {
    final items = await _remote.fetchSessions(query: query);
    return items.map(_mapper.toSession).toList();
  }

  @override
  Future<CopilotSession> createSession({
    required RepositoryQuery query,
    required CopilotAssistantType assistantType,
    String? title,
  }) async {
    final dto = await _remote.createSession(
      query: query,
      assistantType: assistantType,
      title: title,
    );
    return _mapper.toSession(dto);
  }

  @override
  Future<CopilotSessionDetail> getSession({
    required RepositoryQuery query,
    required String sessionId,
  }) async {
    final dto = await _remote.fetchSession(query: query, sessionId: sessionId);
    return _mapper.toSessionDetail(dto);
  }

  @override
  Future<CopilotSendMessageResult> sendMessage({
    required RepositoryQuery query,
    required String sessionId,
    required String content,
    CopilotScreenContext? screenContext,
  }) async {
    final dto = await _remote.sendMessage(
      query: query,
      sessionId: sessionId,
      content: content,
      screenContext: screenContext,
    );
    return _mapper.toSendResult(dto);
  }
}
