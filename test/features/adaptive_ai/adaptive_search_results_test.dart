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
  _FakeAdaptiveAiRepository(this._result, {this.fullResults = const {}});
  final UniversalSearchResult _result;

  /// category -> the FULL ordered match list (a superset of `_result`'s first
  /// page). Used to synthesize subsequent "Show more" pages by offset; tests
  /// that don't exercise pagination can omit this and every offset just
  /// returns the fixed [_result] (matching the old, simpler fake behavior).
  final Map<String, List<SearchResultItem>> fullResults;

  @override
  Future<UniversalSearchResult> universalSearch({
    required RepositoryQuery query,
    required String term,
    int? limit,
    int? offset,
  }) async {
    if (term.trim().length < 2) return UniversalSearchResult.empty(term);
    final start = offset ?? 0;
    if (start == 0) return _result;
    final take = limit ?? 6;
    final groups = <SearchGroup>[];
    for (final group in _result.groups) {
      final full = fullResults[group.category] ?? group.results;
      if (start >= full.length) continue;
      final end = (start + take).clamp(start, full.length);
      groups.add(SearchGroup(
        category: group.category,
        label: group.label,
        total: group.total,
        offset: start,
        results: full.sublist(start, end),
      ));
    }
    return UniversalSearchResult(query: term, groups: groups);
  }

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

/// The full 3-student match set behind [_pagedFirstPage] — total (3) exceeds
/// what the first page shows (2), so "Show more" should render and paging
/// through it should surface the 3rd student.
const _pagedStudentsFull = [
  SearchResultItem(category: 'students', id: 's1', title: 'Ramesh Kumar', subtitle: 'Class 6-B', deepLink: '/students/s1'),
  SearchResultItem(category: 'students', id: 's2', title: 'Ramesh Iyer', subtitle: 'Class 8-A', deepLink: '/students/s2'),
  SearchResultItem(category: 'students', id: 's3', title: 'Ramesh Babu', subtitle: 'Class 7-C', deepLink: '/students/s3'),
];

const _pagedFirstPage = UniversalSearchResult(
  query: 'ram',
  groups: [
    SearchGroup(
      category: 'students',
      label: 'Students',
      total: 3,
      offset: 0,
      results: [
        SearchResultItem(category: 'students', id: 's1', title: 'Ramesh Kumar', subtitle: 'Class 6-B', deepLink: '/students/s1'),
        SearchResultItem(category: 'students', id: 's2', title: 'Ramesh Iyer', subtitle: 'Class 8-A', deepLink: '/students/s2'),
      ],
    ),
  ],
);

const _newCategoryGroups = UniversalSearchResult(
  query: 'fee',
  groups: [
    SearchGroup(
      category: 'finance',
      label: 'Invoices',
      total: 1,
      results: [
        SearchResultItem(category: 'finance', id: 'inv-1', title: 'Invoice #2024-101', subtitle: '₹12,000 due', deepLink: '/finance/invoices/inv-1'),
      ],
    ),
    SearchGroup(
      category: 'communications',
      label: 'Communications',
      total: 1,
      results: [
        SearchResultItem(category: 'communications', id: 'b-1', title: 'Fee reminder broadcast', subtitle: 'Sent to Class 6', deepLink: '/communications/broadcasts/b-1'),
      ],
    ),
    SearchGroup(
      category: 'classes',
      label: 'Classes',
      total: 1,
      results: [
        SearchResultItem(category: 'classes', id: '6-B', title: 'Class 6-B', subtitle: '42 students', deepLink: '/academics/classes/6-B'),
      ],
    ),
  ],
);

Future<void> _pump(WidgetTester tester, {required String query, required void Function(SearchResultItem) onSelect, UniversalSearchResult result = _twoStudents, Map<String, List<SearchResultItem>> fullResults = const {}}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adaptiveAiRepositoryProvider.overrideWithValue(_FakeAdaptiveAiRepository(result, fullResults: fullResults)),
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

    test('finance / communications / classes route to the closest existing screen', () {
      expect(adaptiveSearchRoute('finance', 'inv-1'), RouteNames.financeFeeAssignment);
      expect(adaptiveSearchRoute('communications', 'b-1'), RouteNames.communicationBroadcastAdmin);
      expect(adaptiveSearchRoute('classes', '6-B'), RouteNames.sisAcademicAssignment);
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

    testWidgets('new categories (finance/communications/classes) render with their icons', (tester) async {
      await _pump(tester, query: 'fee', onSelect: (_) {}, result: _newCategoryGroups);
      expect(find.text('Invoices (1)'), findsOneWidget);
      expect(find.text('Communications (1)'), findsOneWidget);
      expect(find.text('Classes (1)'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    });

    group('pagination ("Show more")', () {
      testWidgets('is absent when the group already shows everything (total == shown)', (tester) async {
        await _pump(tester, query: 'ram', onSelect: (_) {}); // _twoStudents: total 2, shown 2
        expect(find.text('Show more'), findsNothing);
      });

      testWidgets('appears when total exceeds the shown count', (tester) async {
        await _pump(tester, query: 'ram', onSelect: (_) {}, result: _pagedFirstPage);
        expect(find.text('Show more'), findsOneWidget);
        expect(find.text('Ramesh Babu'), findsNothing); // page 2 not loaded yet
      });

      testWidgets('tapping loads and appends the next page for that category', (tester) async {
        await _pump(
          tester,
          query: 'ram',
          onSelect: (_) {},
          result: _pagedFirstPage,
          fullResults: const {'students': _pagedStudentsFull},
        );
        expect(find.text('Show more'), findsOneWidget);

        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();

        expect(find.text('Ramesh Babu'), findsOneWidget); // appended, not replaced
        expect(find.text('Ramesh Kumar'), findsOneWidget);
        expect(find.text('Ramesh Iyer'), findsOneWidget);
        // Fully loaded (3 of 3) — the button retires.
        expect(find.text('Show more'), findsNothing);
      });
    });
  });
}
