import 'package:akshara_erp/core/repositories/interfaces/adaptive_ai_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/adaptive_ai/adaptive_ai_models.dart';
import 'package:akshara_erp/features/copilot/widgets/copilot_ai_quick_actions.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/auth_test_overrides.dart';

class _FakeQuickActionsRepo implements AdaptiveAiRepository {
  _FakeQuickActionsRepo(this._actions);
  final List<AdaptiveQuickAction> _actions;

  @override
  Future<List<AdaptiveQuickAction>> getQuickActions({required RepositoryQuery query, required String persona}) async =>
      _actions;

  @override
  Future<AdaptiveFeed> getPriorityFeed({required RepositoryQuery query, required String persona, int? limit}) async =>
      AdaptiveFeed.empty(persona);
  @override
  Future<AdaptiveFeed> getRecommendations({required RepositoryQuery query, required String persona, int? limit}) async =>
      AdaptiveFeed.empty(persona);
  @override
  Future<void> sendRecommendationFeedback({required RepositoryQuery query, required String itemKey, required String itemType, required AdaptiveFeedbackAction action}) async {}
  @override
  Future<UniversalSearchResult> universalSearch({required RepositoryQuery query, required String term, int? limit}) async =>
      UniversalSearchResult.empty(term);
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('quick-actions menu is driven by the backend catalog + open-full sentinel', (tester) async {
    final repo = _FakeQuickActionsRepo(const [
      AdaptiveQuickAction(
        id: 'principal_today_priorities',
        label: "Today's priorities",
        tier: 't1',
        resolver: QuickActionResolver(kind: 'endpoint', target: '/intelligence/priorities'),
      ),
      AdaptiveQuickAction(
        id: 'explain_score_drop',
        label: 'Explain score drop',
        tier: 't3',
        resolver: QuickActionResolver(kind: 'copilot', target: 'academic', prompt: 'Explain the drop.'),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...authStorageTestOverrides(prefs),
          adaptiveAiRepositoryProvider.overrideWithValue(repo),
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: ElevatedButton(
                  onPressed: () => showCopilotQuickActionsMenu(context, ref, Offset.zero),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Backend actions render (no hardcoded client enum) + the open-full sentinel.
    expect(find.text("Today's priorities"), findsOneWidget);
    expect(find.text('Explain score drop'), findsOneWidget);
    expect(find.text('Open full copilot'), findsOneWidget);
    // The removed client stub reply dialog no longer exists as a concept here.
    expect(find.text('Continue in assistant'), findsNothing);
  });
}
