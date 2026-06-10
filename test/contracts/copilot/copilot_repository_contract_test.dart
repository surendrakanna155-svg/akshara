import 'package:akshara_erp/core/repositories/api/copilot/api_copilot_repository.dart';
import 'package:akshara_erp/core/repositories/api/copilot/dto/copilot_dto.dart';
import 'package:akshara_erp/core/repositories/api/copilot/mapper/copilot_mapper.dart';
import 'package:akshara_erp/core/repositories/api/copilot/remote/copilot_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/copilot_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_copilot_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/copilot/copilot_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'copilot_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
final _fixtures = CopilotFixtureBuilder();
const _mapper = CopilotMapper();

void main() {
  group('Copilot repository contract', () {
    late MockCopilotRepository mockRepo;
    late ApiCopilotRepository apiRepo;

    setUp(() {
      mockRepo = MockCopilotRepository();
      apiRepo = ApiCopilotRepository(
        remote: CopilotRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement CopilotRepository', () {
      expect(mockRepo, isA<CopilotRepository>());
      expect(apiRepo, isA<CopilotRepository>());
    });

    test('assistant DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAssistants(query: kQuery);
      final mapped = _mapper.toAssistants(
        parseCopilotItems(_fixtures.assistantsEnvelope(mockData))
            .map(CopilotAssistantDto.fromJson)
            .toList(),
      );
      expect(mapped.length, mockData.length);
      expect(mapped.first.type, mockData.first.type);
      expect(mapped.first.skills, mockData.first.skills);
    });

    test('suggestions DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSuggestions(
        query: kQuery,
        assistantType: CopilotAssistantType.finance,
      );
      final mapped = _mapper.toSuggestions(
        CopilotSuggestionsDto.fromJson(
          _fixtures.suggestionsEnvelope(mockData)['data'] as Map<String, dynamic>,
        ),
      );
      expect(mapped.prompts, mockData.prompts);
      expect(mapped.assistantType, mockData.assistantType);
    });

    test('session DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSessions(query: kQuery);
      final mapped = _mapper.toSession(
        CopilotSessionDto.fromJson(
          (_fixtures.sessionsEnvelope(mockData)['data'] as Map<String, dynamic>)['items']
              .first as Map<String, dynamic>,
        ),
      );
      expect(mapped.id, mockData.first.id);
      expect(mapped.assistantType, mockData.first.assistantType);
    });

    test('session detail DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSession(
        query: kQuery,
        sessionId: 'copilot_session_1',
      );
      final mapped = _mapper.toSessionDetail(
        CopilotSessionDetailDto.fromJson(
          _fixtures.sessionDetailEnvelope(mockData)['data'] as Map<String, dynamic>,
        ),
      );
      expect(mapped.messages.length, mockData.messages.length);
      expect(mapped.session.title, mockData.session.title);
    });

    test('send message DTO mapping matches mock output', () async {
      final mockData = await mockRepo.sendMessage(
        query: kQuery,
        sessionId: 'copilot_session_1',
        content: 'Summarize collections',
      );
      final mapped = _mapper.toSendResult(
        CopilotSendMessageResultDto.fromJson(
          _fixtures.sendMessageEnvelope(mockData)['data'] as Map<String, dynamic>,
        ),
      );
      expect(mapped.stub, mockData.stub);
      expect(mapped.assistantMessage.content, mockData.assistantMessage.content);
    });
  });
}
