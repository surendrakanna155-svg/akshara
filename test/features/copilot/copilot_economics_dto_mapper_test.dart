import 'package:akshara_erp/core/repositories/api/copilot/dto/copilot_dto.dart';
import 'package:akshara_erp/core/repositories/api/copilot/mapper/copilot_mapper.dart';
import 'package:akshara_erp/core/repositories/mock/mock_copilot_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/copilot/copilot_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = CopilotMapper();
  const query = RepositoryQuery.demo;

  group('AI economics DTO ↔ backend contract (N10 cost panel)', () {
    test('parses a realistic /copilot/economics envelope', () {
      final env = {
        'data': {
          'monthStart': '2026-07-01T00:00:00.000Z',
          'spendMicros': 640000000,
          'spendCapMicros': 1000000000,
          'spendWarnRatio': 0.8,
          'atSpendWarn': false,
          'atSpendCap': false,
          'modelCalls': 812,
          'fallbacks': 46,
          'callsByOutcome': {
            'ok': 780,
            'refused': 32,
            'fallback_no_key': 20,
            'fallback_error': 26,
          },
          'callsBySurface': {
            'copilot_chat': 540,
            'quick_action': 180,
            'suggestions': 92,
          },
          'cacheEntries': 340,
          'cacheHits': 2210,
          'tokensSaved': 1875000,
          'cacheHitRatio': 0.73,
        },
      };

      final economics =
          mapper.toEconomics(AiEconomicsDto.fromJson(parseCopilotEnvelope(env)));

      expect(economics.monthStart, '2026-07-01T00:00:00.000Z');
      expect(economics.spendMicros, 640000000);
      expect(economics.spendCapMicros, 1000000000);
      expect(economics.spendWarnRatio, 0.8);
      expect(economics.atSpendWarn, isFalse);
      expect(economics.atSpendCap, isFalse);
      expect(economics.modelCalls, 812);
      expect(economics.fallbacks, 46);
      expect(economics.callsByOutcome['ok'], 780);
      expect(economics.callsBySurface['copilot_chat'], 540);
      expect(economics.cacheEntries, 340);
      expect(economics.cacheHits, 2210);
      expect(economics.tokensSaved, 1875000);
      expect(economics.cacheHitRatio, 0.73);
      expect(economics.spendRatio, closeTo(0.64, 0.0001));
    });

    test('atSpendWarn / atSpendCap flip the flags at the warn/cap thresholds', () {
      final env = {
        'data': {
          'monthStart': '2026-07-01T00:00:00.000Z',
          'spendMicros': 1000000000,
          'spendCapMicros': 1000000000,
          'spendWarnRatio': 0.8,
          'atSpendWarn': true,
          'atSpendCap': true,
          'modelCalls': 900,
          'fallbacks': 5,
          'callsByOutcome': <String, int>{},
          'callsBySurface': <String, int>{},
          'cacheEntries': 0,
          'cacheHits': 0,
          'tokensSaved': 0,
          'cacheHitRatio': 0,
        },
      };

      final economics =
          mapper.toEconomics(AiEconomicsDto.fromJson(parseCopilotEnvelope(env)));
      expect(economics.atSpendWarn, isTrue);
      expect(economics.atSpendCap, isTrue);
      expect(economics.spendRatio, 1.0);
    });

    test('uncapped spend (spendCapMicros = 0) has a zero spendRatio, not a crash', () {
      final env = {
        'data': {
          'monthStart': '2026-07-01T00:00:00.000Z',
          'spendMicros': 250000000,
          'spendCapMicros': 0,
          'spendWarnRatio': 0.8,
          'atSpendWarn': false,
          'atSpendCap': false,
          'modelCalls': 100,
          'fallbacks': 0,
          'callsByOutcome': <String, int>{},
          'callsBySurface': <String, int>{},
          'cacheEntries': 0,
          'cacheHits': 0,
          'tokensSaved': 0,
          'cacheHitRatio': 0,
        },
      };

      final economics =
          mapper.toEconomics(AiEconomicsDto.fromJson(parseCopilotEnvelope(env)));
      expect(economics.spendCapMicros, 0);
      expect(economics.spendRatio, 0);
    });

    test('malformed / empty envelope degrades to a zeroed DTO, not a crash', () {
      final dto = AiEconomicsDto.fromJson(parseCopilotEnvelope(const {}));
      expect(dto.monthStart, '');
      expect(dto.spendMicros, 0);
      expect(dto.callsByOutcome, isEmpty);
      expect(dto.callsBySurface, isEmpty);

      final economics = mapper.toEconomics(dto);
      expect(economics.spendRatio, 0);
    });
  });

  group('AiEconomics.empty (Hybrid fail-soft degraded state)', () {
    test('is a safe zeroed value', () {
      const economics = AiEconomics.empty();
      expect(economics.spendMicros, 0);
      expect(economics.spendCapMicros, 0);
      expect(economics.atSpendWarn, isFalse);
      expect(economics.atSpendCap, isFalse);
      expect(economics.spendRatio, 0);
      expect(economics.callsByOutcome, isEmpty);
      expect(economics.callsBySurface, isEmpty);
    });
  });

  group('MockCopilotRepository.getEconomics', () {
    test('serves deterministic sample data consistent with the domain model', () async {
      final repo = MockCopilotRepository();
      final economics = await repo.getEconomics(query: query);

      expect(economics.spendCapMicros, greaterThan(0));
      expect(economics.spendMicros, lessThan(economics.spendCapMicros));
      expect(economics.atSpendWarn, isFalse);
      expect(economics.atSpendCap, isFalse);
      expect(economics.modelCalls, greaterThan(0));
      expect(economics.fallbacks, greaterThan(0));
      expect(economics.callsBySurface, isNotEmpty);
      expect(economics.cacheHitRatio, greaterThan(0));
      expect(economics.tokensSaved, greaterThan(0));
    });
  });
}
