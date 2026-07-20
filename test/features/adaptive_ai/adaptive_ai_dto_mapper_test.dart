import 'package:akshara_erp/core/repositories/api/adaptive_ai/dto/adaptive_ai_dto.dart';
import 'package:akshara_erp/features/adaptive_ai/adaptive_ai_models.dart';
import 'package:akshara_erp/core/repositories/api/adaptive_ai/mapper/adaptive_ai_mapper.dart';
import 'package:akshara_erp/core/repositories/mock/mock_adaptive_ai_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = AdaptiveAiMapper();
  const query = RepositoryQuery.demo;

  group('Adaptive AI DTO ↔ backend contract', () {
    test('parses a recommendations envelope (item + pre-staged action + factorBreakdown)', () {
      final env = {
        'data': {
          'persona': 'principal',
          'items': [
            {
              'itemKey': 'risk:student:s1',
              'type': 'exception',
              'title': 'At-risk student in 6-B',
              'detail': 'Risk score 88/100.',
              'score': 82,
              'reason': 'critical severity',
              'action': {
                'label': 'Review student risk',
                'deepLink': '/intelligence/risk/students/s1',
                'payload': {'studentId': 's1'},
                'requiresConfirmation': true,
              },
              'factorBreakdown': {
                'urgency': 2.4,
                'impact': 3.0,
                'ageBoost': 1.1,
                'learnedWeight': 1.0,
              },
            },
          ],
          'counts': {'total': 1, 'critical': 1},
          'degraded': false,
        },
      };
      final feed = mapper.toFeed(AdaptiveFeedDto.fromEnvelopeData(parseAdaptiveEnvelope(env)));
      expect(feed.persona, 'principal');
      expect(feed.items.single.itemKey, 'risk:student:s1');
      expect(feed.items.single.score, 82);
      expect(feed.items.single.isCritical, isTrue);
      expect(feed.items.single.action!.deepLink, '/intelligence/risk/students/s1');
      expect(feed.items.single.action!.requiresConfirmation, isTrue);
      expect(feed.criticalCount, 1);
      final breakdown = feed.items.single.factorBreakdown;
      expect(breakdown, isNotNull);
      expect(breakdown!.urgency, 2.4);
      expect(breakdown.impact, 3.0);
      expect(breakdown.ageBoost, 1.1);
      expect(breakdown.learnedWeight, 1.0);
    });

    test('a priority-feed item has no action and no factorBreakdown when the envelope omits one', () {
      final env = {
        'data': {
          'persona': 'finance',
          'items': [
            {'itemKey': 'fee:collection', 'type': 'follow_up', 'title': 'x', 'detail': 'y', 'score': 61, 'reason': 'elevated priority'},
          ],
          'counts': {'total': 1, 'critical': 0},
          'degraded': true,
        },
      };
      final feed = mapper.toFeed(AdaptiveFeedDto.fromEnvelopeData(parseAdaptiveEnvelope(env)));
      expect(feed.items.single.action, isNull);
      expect(feed.items.single.factorBreakdown, isNull);
      expect(feed.degraded, isTrue);
    });

    test('parses quick actions (tier + resolver)', () {
      final env = {
        'data': {
          'persona': 'principal',
          'items': [
            {
              'id': 'principal_today_priorities',
              'label': "Today's priorities",
              'tier': 't1',
              'requiresEntity': null,
              'resolver': {'kind': 'endpoint', 'target': '/intelligence/priorities?persona=principal'},
            },
            {
              'id': 'teacher_explain_score_drop',
              'label': 'Explain score drop',
              'tier': 't3',
              'requiresEntity': 'student',
              'resolver': {'kind': 'copilot', 'target': 'academic', 'prompt': 'Explain the drop.'},
            },
          ],
        },
      };
      final actions =
          parseQuickActions(parseAdaptiveEnvelope(env)).map(mapper.toQuickAction).toList();
      expect(actions, hasLength(2));
      expect(actions.first.isDeterministic, isTrue);
      expect(actions.last.tier, 't3');
      expect(actions.last.resolver.isCopilot, isTrue);
      expect(actions.last.resolver.prompt, 'Explain the drop.');
      expect(actions.last.requiresEntity, 'student');
    });

    test('parses grouped universal search results, including the page offset', () {
      final env = {
        'data': {
          'query': 'ram',
          'groups': [
            {
              'category': 'students',
              'label': 'Students',
              'total': 5,
              'offset': 2,
              'results': [
                {'category': 'students', 'id': 's1', 'title': 'Ramesh Kumar', 'subtitle': 'Class 6-B', 'deepLink': '/students/s1'},
                {'category': 'students', 'id': 's2', 'title': 'Ramesh Iyer', 'subtitle': 'Class 8-A', 'deepLink': '/students/s2'},
              ],
            },
          ],
        },
      };
      final result =
          mapper.toSearchResultSet(UniversalSearchResultDto.fromEnvelopeData(parseAdaptiveEnvelope(env)));
      expect(result.query, 'ram');
      expect(result.groups.single.category, 'students');
      expect(result.groups.single.results, hasLength(2));
      expect(result.groups.single.results.first.deepLink, '/students/s1');
      expect(result.groups.single.total, 5);
      expect(result.groups.single.offset, 2);
    });

    test('a group with no offset in the envelope defaults to 0 (first page)', () {
      final env = {
        'data': {
          'query': 'ram',
          'groups': [
            {
              'category': 'students',
              'label': 'Students',
              'total': 2,
              'results': [
                {'category': 'students', 'id': 's1', 'title': 'Ramesh Kumar', 'subtitle': 'Class 6-B', 'deepLink': '/students/s1'},
              ],
            },
          ],
        },
      };
      final result =
          mapper.toSearchResultSet(UniversalSearchResultDto.fromEnvelopeData(parseAdaptiveEnvelope(env)));
      expect(result.groups.single.offset, 0);
    });

    test('malformed / empty envelope degrades to an empty feed, not a crash', () {
      final feed = mapper.toFeed(AdaptiveFeedDto.fromEnvelopeData(parseAdaptiveEnvelope(const {})));
      expect(feed.items, isEmpty);
    });
  });

  group('MockAdaptiveAiRepository', () {
    test('serves a persona feed and honours dismiss feedback', () async {
      final repo = MockAdaptiveAiRepository();
      final before = await repo.getRecommendations(query: query, persona: 'principal');
      expect(before.items, isNotEmpty);
      expect(before.items.first.action, isNotNull); // recommendations carry actions

      final key = before.items.first.itemKey;
      await repo.sendRecommendationFeedback(
        query: query,
        itemKey: key,
        itemType: before.items.first.type,
        action: AdaptiveFeedbackAction.dismiss,
      );
      final after = await repo.getRecommendations(query: query, persona: 'principal');
      expect(after.items.any((i) => i.itemKey == key), isFalse);
    });

    test('priority feed items carry no action; quick actions are persona-scoped', () async {
      final repo = MockAdaptiveAiRepository();
      final feed = await repo.getPriorityFeed(query: query, persona: 'principal');
      expect(feed.items.every((i) => i.action == null), isTrue);

      final parentActions = await repo.getQuickActions(query: query, persona: 'parent');
      expect(parentActions.every((a) => a.id.startsWith('parent_')), isTrue);
    });

    test('seeded items carry a plausible factorBreakdown (parity with the live envelope)', () async {
      final repo = MockAdaptiveAiRepository();
      final feed = await repo.getRecommendations(query: query, persona: 'principal');
      expect(feed.items, isNotEmpty);
      expect(feed.items.every((i) => i.factorBreakdown != null), isTrue);
    });

    test('search requires ≥2 chars', () async {
      final repo = MockAdaptiveAiRepository();
      expect((await repo.universalSearch(query: query, term: 'r')).isEmpty, isTrue);
      expect((await repo.universalSearch(query: query, term: 'ram')).isEmpty, isFalse);
    });

    test('search respects offset by slicing the seeded results', () async {
      final repo = MockAdaptiveAiRepository();
      final first = await repo.universalSearch(query: query, term: 'ram', limit: 1);
      expect(first.groups.single.results, hasLength(1));
      expect(first.groups.single.offset, 0);
      expect(first.groups.single.total, 2);

      final second = await repo.universalSearch(query: query, term: 'ram', limit: 1, offset: 1);
      expect(second.groups.single.results, hasLength(1));
      expect(second.groups.single.offset, 1);
      // Distinct from the first page — offset actually advanced the window.
      expect(second.groups.single.results.single.id, isNot(first.groups.single.results.single.id));

      // Past the end of the seeded set — the category drops out entirely,
      // mirroring the live handler (no empty groups).
      final exhausted = await repo.universalSearch(query: query, term: 'ram', offset: 2);
      expect(exhausted.isEmpty, isTrue);
    });
  });
}
