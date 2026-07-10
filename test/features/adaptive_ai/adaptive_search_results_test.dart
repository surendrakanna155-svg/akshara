import 'package:akshara_erp/core/repositories/interfaces/adaptive_ai_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/adaptive_ai/adaptive_ai_models.dart';
import 'package:akshara_erp/features/adaptive_ai/adaptive_ai_providers.dart';
import 'package:akshara_erp/features/adaptive_ai/widgets/adaptive_search_results.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdaptiveAiRepository implements AdaptiveAiRepository {
  _FakeAdaptiveAiRepository(this._result);
  final UniversalSearchResult _result;

  @override
  Future<UniversalSearchResult> universalSearch({
    required RepositoryQuery query,
    required String term,
    int? limit,
  }) async =>
      term.trim().length < 2 ? UniversalSearchResult.empty(term) : _result;

  @override
  Future<AdaptiveFeed> getPriorityFeed({required RepositoryQuery query, required String persona, int? limit}) async =>
      AdaptiveFeed.empty(persona);
  @override
  Future<AdaptiveFeed> getRecommendations({required RepositoryQuery query, required String persona, int? limit}) async =>
      AdaptiveFeed.empty(persona);
  @override
  Future<void> sendRecommendationFeedback({required RepositoryQuery query, required String itemKey, required String itemType, required AdaptiveFeedbackAction action}) async {}
  @override
  Future<List<AdaptiveQuickAction>> getQuickActions({required RepositoryQuery query, required String persona}) async => const [];
}

const _twoStudents = UniversalSearchResult(
  query: 'ram',
  groups: [
    SearchGroup(
      category: 'students',
      label: 'Students',
      total: 2,
      results: [
        SearchResultItem(category: 'students', id: 's1', title: 'Ramesh Kumar', subtitle: 'Class 6-B', deepLink: '/students/s1'),
        SearchResultItem(category: 'students', id: 's2', title: 'Ramesh Iyer', subtitle: 'Class 8-A', deepLink: '/students/s2'),
      ],
    ),
  ],
);

Future<void> _pump(WidgetTester tester, {required String query, required void Function(SearchResultItem) onSelect, UniversalSearchResult result = _twoStudents}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adaptiveAiRepositoryProvider.overrideWithValue(_FakeAdaptiveAiRepository(result)),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: AdaptiveSearchResults(query: query, onSelect: onSelect))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('adaptiveSearchRoute maps categories to record routes', () {
    test('students / staff / admissions / unknown', () {
      expect(adaptiveSearchRoute('students', 's1'), RouteNames.sisStudentDetail('s1'));
      expect(adaptiveSearchRoute('staff', 'e1'), RouteNames.hrEmployeeDetail('e1'));
      expect(adaptiveSearchRoute('admissions', 'l1'), RouteNames.admissionsLeadDetail('l1'));
      expect(adaptiveSearchRoute('unknown', 'x'), isNull);
    });
  });

  group('AdaptiveSearchResults', () {
    testWidgets('renders grouped records with a count and disambiguating subtitle', (tester) async {
      await _pump(tester, query: 'ram', onSelect: (_) {});
      expect(find.text('Students (2)'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Ramesh Iyer'), findsOneWidget);
      expect(find.text('Class 6-B'), findsOneWidget); // non-unique names disambiguated
    });

    testWidgets('selecting a record invokes onSelect with the item', (tester) async {
      SearchResultItem? selected;
      await _pump(tester, query: 'ram', onSelect: (i) => selected = i);
      await tester.tap(find.text('Ramesh Iyer'));
      await tester.pumpAndSettle();
      expect(selected?.id, 's2');
    });

    testWidgets('self-hides for a short query (< 2 chars)', (tester) async {
      await _pump(tester, query: 'r', onSelect: (_) {});
      expect(find.text('Students (2)'), findsNothing);
    });

    testWidgets('self-hides when there are no matches', (tester) async {
      await _pump(tester, query: 'zzz', onSelect: (_) {}, result: const UniversalSearchResult.empty('zzz'));
      expect(find.textContaining('Students'), findsNothing);
    });
  });
}
