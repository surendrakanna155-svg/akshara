import 'package:akshara_erp/core/repositories/api/copilot/api_copilot_repository.dart';
import 'package:akshara_erp/core/repositories/api/copilot/remote/copilot_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/copilot/remote/copilot_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_copilot_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/copilot/copilot_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/copilot/copilot_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';

const kQuery = RepositoryQuery.demo;
final _fixtures = CopilotFixtureBuilder();

void main() {
  group('Copilot API integration', () {
    late MockCopilotRepository mockRepo;
    late ApiCopilotRepository apiRepo;
    late Map<String, dynamic> Function(String path, String method) responseFor;

    setUp(() async {
      mockRepo = MockCopilotRepository();
      final assistants = await mockRepo.getAssistants(query: kQuery);
      final suggestions = await mockRepo.getSuggestions(
        query: kQuery,
        assistantType: CopilotAssistantType.finance,
      );
      final sessions = await mockRepo.getSessions(query: kQuery);
      final sessionDetail = await mockRepo.getSession(
        query: kQuery,
        sessionId: 'copilot_session_1',
      );

      final postMock = MockCopilotRepository();
      final sendResult = await postMock.sendMessage(
        query: kQuery,
        sessionId: 'copilot_session_1',
        content: 'Summarize collections',
      );
      final createdSession = await postMock.createSession(
        query: kQuery,
        assistantType: CopilotAssistantType.admissions,
        title: 'New admissions chat',
      );

      responseFor = (path, method) {
        if (path == CopilotApiPaths.assistants && method == 'GET') {
          return _fixtures.assistantsEnvelope(assistants);
        }
        if (path.startsWith(CopilotApiPaths.suggestions) && method == 'GET') {
          return _fixtures.suggestionsEnvelope(suggestions);
        }
        if (path == CopilotApiPaths.sessions && method == 'GET') {
          return _fixtures.sessionsEnvelope(sessions);
        }
        if (path == CopilotApiPaths.sessions && method == 'POST') {
          return _fixtures.envelope(_fixtures.sessionItem(createdSession));
        }
        if (path == CopilotApiPaths.session('copilot_session_1') && method == 'GET') {
          return _fixtures.sessionDetailEnvelope(sessionDetail);
        }
        if (path == CopilotApiPaths.messages('copilot_session_1') && method == 'POST') {
          return _fixtures.sendMessageEnvelope(sendResult);
        }
        throw UnsupportedError('Unhandled path: $method $path');
      };

      final dio = createFakeDio((options) {
        return responseFor(options.path, options.method);
      });

      apiRepo = ApiCopilotRepository(
        remote: CopilotRemoteDataSource(dio),
      );
    });

    test('getAssistants returns mapped assistants', () async {
      final mockData = await mockRepo.getAssistants(query: kQuery);
      final apiData = await apiRepo.getAssistants(query: kQuery);
      expect(apiData.length, mockData.length);
      expect(apiData.first.type, mockData.first.type);
    });

    test('getSuggestions returns mapped prompts', () async {
      final mockData = await mockRepo.getSuggestions(
        query: kQuery,
        assistantType: CopilotAssistantType.finance,
      );
      final apiData = await apiRepo.getSuggestions(
        query: kQuery,
        assistantType: CopilotAssistantType.finance,
      );
      expect(apiData.prompts, mockData.prompts);
    });

    test('getSessions returns mapped sessions', () async {
      final mockData = await mockRepo.getSessions(query: kQuery);
      final apiData = await apiRepo.getSessions(query: kQuery);
      expect(apiData.length, mockData.length);
      expect(apiData.first.id, mockData.first.id);
    });

    test('getSession returns mapped messages', () async {
      final mockData = await mockRepo.getSession(
        query: kQuery,
        sessionId: 'copilot_session_1',
      );
      final apiData = await apiRepo.getSession(
        query: kQuery,
        sessionId: 'copilot_session_1',
      );
      expect(apiData.messages.length, mockData.messages.length);
    });

    test('sendMessage returns mapped assistant reply', () async {
      final mockData = await mockRepo.sendMessage(
        query: kQuery,
        sessionId: 'copilot_session_1',
        content: 'Summarize collections',
      );
      final apiData = await apiRepo.sendMessage(
        query: kQuery,
        sessionId: 'copilot_session_1',
        content: 'Summarize collections',
      );
      expect(apiData.stub, mockData.stub);
      expect(apiData.assistantMessage.role, 'assistant');
    });
  });
}
