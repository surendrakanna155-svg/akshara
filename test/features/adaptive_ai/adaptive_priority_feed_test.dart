import 'package:akshara_erp/core/repositories/interfaces/adaptive_ai_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/adaptive_ai/adaptive_ai_models.dart';
import 'package:akshara_erp/features/adaptive_ai/adaptive_lifecycle.dart';
import 'package:akshara_erp/features/adaptive_ai/widgets/adaptive_priority_feed.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake that returns configurable recommendations and honours dismissals.
class _FakeAdaptiveAiRepository implements AdaptiveAiRepository {
  _FakeAdaptiveAiRepository(this._items);

  final List<AdaptivePriorityItem> _items;
  final Set<String> dismissed = {};
  final List<String> feedbackLog = [];

  /// Living Dashboard: what lifecycle writes reached the repository.
  final List<String> lifecycleLog = [];
  final Map<String, DateTime> snoozedUntilLog = {};
  final Map<String, int?> scoreAtActionLog = {};

  /// When true, every lifecycle write throws — used to prove the UI surfaces
  /// the failure instead of leaving the card silently gone.
  bool lifecycleShouldFail = false;

  @override
  Future<AdaptiveFeed> getRecommendations({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  }) async {
    final visible = _items.where((i) => !dismissed.contains(i.itemKey)).toList();
    return AdaptiveFeed(persona: persona, items: visible);
  }

  @override
  Future<AdaptiveFeed> getPriorityFeed({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  }) =>
      getRecommendations(query: query, persona: persona, limit: limit);

  @override
  Future<void> sendRecommendationFeedback({
    required RepositoryQuery query,
    required String itemKey,
    required String itemType,
    AdaptiveFeedbackAction? action,
    AdaptiveLifecycleWrite? lifecycle,
  }) async {
    if (lifecycleShouldFail && lifecycle != null) {
      throw StateError('lifecycle write failed');
    }
    if (lifecycle != null) {
      lifecycleLog.add('${lifecycle.action.wireState}:$itemKey');
      if (lifecycle.action == AdaptiveLifecycleAction.snooze) {
        snoozedUntilLog[itemKey] = lifecycle.snoozedUntil!;
      }
      scoreAtActionLog[itemKey] = lifecycle.scoreAtAction;
      dismissed.add(itemKey);
      return;
    }
    feedbackLog.add('$action:$itemKey');
    if (action == AdaptiveFeedbackAction.accept) {
      dismissed.remove(itemKey);
    } else if (action != null) {
      dismissed.add(itemKey);
    }
  }

  @override
  Future<List<AdaptiveQuickAction>> getQuickActions({
    required RepositoryQuery query,
    required String persona,
  }) async =>
      const [];

  @override
  Future<UniversalSearchResult> universalSearch({
    required RepositoryQuery query,
    required String term,
    int? limit,
    int? offset,
  }) async =>
      UniversalSearchResult.empty(term);
}

AdaptivePriorityItem _item(
  String key, {
  int score = 60,
  AdaptiveAction? action,
  AdaptiveFactorBreakdown? factorBreakdown,
  String? visibilityReason,
}) {
  return AdaptivePriorityItem(
    itemKey: key,
    type: 'exception',
    title: 'Item $key',
    detail: 'detail for $key',
    score: score,
    reason: 'elevated priority',
    action: action,
    factorBreakdown: factorBreakdown,
    visibilityReason: visibilityReason,
  );
}

extension _ItemVisibility on AdaptivePriorityItem {
  AdaptivePriorityItem copyWithVisibility(String reason) => AdaptivePriorityItem(
        itemKey: itemKey,
        type: type,
        title: title,
        detail: detail,
        score: score,
        reason: this.reason,
        action: action,
        factorBreakdown: factorBreakdown,
        lifecycleState: lifecycleState,
        visibilityReason: reason,
      );
}

Future<void> _pump(WidgetTester tester, _FakeAdaptiveAiRepository repo, {void Function(AdaptiveAction)? onOpen}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adaptiveAiRepositoryProvider.overrideWithValue(repo),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdaptivePriorityFeedSection(
              persona: 'principal',
              onOpenAction: onOpen == null ? null : (_, a) => onOpen(a),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders items with score + explainable reason', (tester) async {
    final repo = _FakeAdaptiveAiRepository([_item('a', score: 82), _item('b', score: 40)]);
    await _pump(tester, repo);

    expect(find.text('Priorities for you'), findsOneWidget);
    expect(find.text('Item a'), findsOneWidget);
    expect(find.text('Item b'), findsOneWidget);
    expect(find.text('82'), findsOneWidget); // score badge
    expect(find.textContaining('Why:'), findsWidgets); // explainability rail
  });

  testWidgets('self-hides when the feed is empty', (tester) async {
    final repo = _FakeAdaptiveAiRepository(const []);
    await _pump(tester, repo);
    expect(find.text('Priorities for you'), findsNothing);
  });

  testWidgets('putting an item away records a lifecycle row and removes it', (tester) async {
    final repo = _FakeAdaptiveAiRepository([_item('a'), _item('b')]);
    await _pump(tester, repo);
    expect(find.text('Item a'), findsOneWidget);

    // P2-6: the standalone "Dismiss" icon button folded into a compact
    // overflow menu (dense rows) that also carries "Mute this type".
    // Living Dashboard renamed it: the item is put away, not deleted.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Put away for today'));
    await tester.pumpAndSettle();

    // Writes an `acknowledged` lifecycle row (day-scoped, can resurface) rather
    // than the old permanent dismissal.
    expect(repo.lifecycleLog, contains('acknowledged:a'));
    // And carries the severity watermark, without which the backend could never
    // decide that the item later got worse.
    expect(repo.scoreAtActionLog['a'], isNotNull);
    expect(find.text('Item a'), findsNothing);
    expect(find.text('Item b'), findsOneWidget);
  });

  testWidgets('swiping an item away puts it away and promotes the next one', (tester) async {
    final repo = _FakeAdaptiveAiRepository([_item('a'), _item('b')]);
    await _pump(tester, repo);

    await tester.drag(find.text('Item a'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(repo.lifecycleLog, contains('acknowledged:a'));
    expect(find.text('Item a'), findsNothing);
    expect(find.text('Item b'), findsOneWidget);
  });

  testWidgets('snooze records a future wake-up and sends NO learning signal', (tester) async {
    final repo = _FakeAdaptiveAiRepository([_item('a'), _item('b')]);
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remind me later'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In 30 minutes'));
    await tester.pumpAndSettle();

    expect(repo.lifecycleLog, contains('snoozed:a'));
    expect(repo.snoozedUntilLog['a']!.isAfter(DateTime.now().toUtc()), isTrue);
    // "Not now" must never down-weight the whole item type the way a dismissal
    // does — so a snooze carries no accept/dismiss/suppress signal at all.
    expect(repo.feedbackLog, isEmpty);
    expect(find.text('Item a'), findsNothing);
  });

  testWidgets('a failed lifecycle write is surfaced, not swallowed', (tester) async {
    final repo = _FakeAdaptiveAiRepository([_item('a'), _item('b')])
      ..lifecycleShouldFail = true;
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Put away for today'));
    await tester.pumpAndSettle();

    // The card left the screen optimistically, so staying silent would leave
    // the user believing it was put away when the server never recorded it.
    expect(find.textContaining('still on your list'), findsOneWidget);
  });

  testWidgets('an item that came back on its own says why', (tester) async {
    final repo = _FakeAdaptiveAiRepository([
      _item('a').copyWithVisibility('visible_severity_increased'),
    ]);
    await _pump(tester, repo);

    expect(find.text('Back — this got more urgent'), findsOneWidget);
  });

  testWidgets('suppress ("Mute this type") records feedback and removes the item', (tester) async {
    final repo = _FakeAdaptiveAiRepository([_item('a'), _item('b')]);
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mute this type'));
    await tester.pumpAndSettle();

    expect(repo.feedbackLog, contains('AdaptiveFeedbackAction.suppress:a'));
    expect(find.text('Item a'), findsNothing);
    expect(find.text('Item b'), findsOneWidget);
  });

  testWidgets(
      'a recommendation with an action shows an Open button that navigates '
      'AND records an accept (learning signal, fire-and-forget)', (tester) async {
    AdaptiveAction? opened;
    final repo = _FakeAdaptiveAiRepository([
      _item('a', action: const AdaptiveAction(label: 'Open recovery call queue', deepLink: '/finance/recovery/call-queue')),
    ]);
    await _pump(tester, repo, onOpen: (a) => opened = a);

    final button = find.widgetWithText(TextButton, 'Open recovery call queue');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opened?.deepLink, '/finance/recovery/call-queue');
    expect(repo.feedbackLog, contains('AdaptiveFeedbackAction.accept:a'));
  });

  testWidgets('tapping the Why line toggles the factor-breakdown detail', (tester) async {
    final repo = _FakeAdaptiveAiRepository([
      _item(
        'a',
        factorBreakdown: const AdaptiveFactorBreakdown(
          urgency: 2.4,
          impact: 3.0,
          ageBoost: 1.1,
          learnedWeight: 1.0,
        ),
      ),
    ]);
    await _pump(tester, repo);

    const detail = 'urgency ×2.4 · impact ×3.0 · recency ×1.1 · learned ×1.0';
    expect(find.text(detail), findsNothing);

    await tester.tap(find.textContaining('Why:'));
    await tester.pumpAndSettle();
    expect(find.text(detail), findsOneWidget);

    await tester.tap(find.textContaining('Why:'));
    await tester.pumpAndSettle();
    expect(find.text(detail), findsNothing);
  });

  testWidgets('the Why line is not tappable when an item has no factor breakdown', (tester) async {
    final repo = _FakeAdaptiveAiRepository([_item('a')]);
    await _pump(tester, repo);

    // No crash / no-op tap — nothing to expand.
    await tester.tap(find.textContaining('Why:'));
    await tester.pumpAndSettle();
    expect(find.textContaining('urgency'), findsNothing);
  });
}
