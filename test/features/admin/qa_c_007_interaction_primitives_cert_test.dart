import 'package:akshara_erp/core/repositories/paginated_result.dart';
import 'package:akshara_erp/features/admin/admin_filter_bar.dart';
import 'package:akshara_erp/features/admin/global_search/global_search_registry.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW7 · QA-C-007 — Interaction primitives *behaviour* certification (Batch 2):
/// dropdown / search / filter / sort / pagination.
///
/// Sits ON TOP of the focused primitive tests this row is asked to build on:
///   • test/features/admin/admin_filter_bar_test.dart   (AdminFilterBar inline vs
///     collapsed presentation; sheet option fires the callback)
///   • test/core/repositories/pagination_test.dart       (PaginatedResult.fromItems
///     page slices + hasMore; fromDto metadata)
///   • test/features/admin/global_search_registry_test.dart  (RBAC/capability
///     filtering of search results)
///
/// Rather than re-test those, this proves the three primitives ACT on a list:
///   1. FILTER — selecting a filter chip both fires the callback AND narrows the
///      rendered list to the matching rows.
///   2. SEARCH — a real query returns matches; a nonsense query returns empty.
///   3. PAGINATION — loading the next page APPENDS to the accumulated list (it
///      grows; it does not replace), and the final page reports hasMore == false.
void _useWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// A minimal filterable list driven by [AdminFilterBar]: index 0 = All,
/// 1 = Active, 2 = Inactive. Selecting a chip narrows the rows shown.
class _FilterableList extends StatefulWidget {
  const _FilterableList({required this.onFilterFired});

  final ValueChanged<int> onFilterFired;

  @override
  State<_FilterableList> createState() => _FilterableListState();
}

class _FilterableListState extends State<_FilterableList> {
  static const _filters = ['All', 'Active', 'Inactive'];
  static const _rows = [
    ('Ravi (active)', true),
    ('Anita (active)', true),
    ('Old Account (inactive)', false),
  ];

  int _selected = 0;

  Iterable<(String, bool)> get _visible => switch (_selected) {
        1 => _rows.where((r) => r.$2),
        2 => _rows.where((r) => !r.$2),
        _ => _rows,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AdminFilterBar(
          filters: _filters,
          selectedIndex: _selected,
          onFilterSelected: (i) {
            widget.onFilterFired(i);
            setState(() => _selected = i);
          },
        ),
        for (final (label, _) in _visible) Text(label),
      ],
    );
  }
}

void main() {
  group('QA-C-007 · FILTER primitive', () {
    testWidgets('selecting a filter fires the callback and narrows the list',
        (tester) async {
      _useWidth(tester, 1200); // desktop → inline chips are directly tappable
      int? fired;
      await tester.pumpWidget(
        MaterialApp(
          theme: AksharaAppTheme.light(),
          home: Scaffold(
            body: _FilterableList(onFilterFired: (i) => fired = i),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially "All" → all three rows are visible.
      expect(find.text('Ravi (active)'), findsOneWidget);
      expect(find.text('Old Account (inactive)'), findsOneWidget);

      // Select "Active" (index 1) → callback fires AND the inactive row drops.
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      expect(fired, 1);
      expect(find.text('Ravi (active)'), findsOneWidget);
      expect(find.text('Anita (active)'), findsOneWidget);
      expect(find.text('Old Account (inactive)'), findsNothing);
    });
  });

  group('QA-C-007 · SEARCH primitive', () {
    test('a real query returns matches; a nonsense query returns empty', () {
      // Match: "defaulter" resolves to the finance defaulters destination.
      final matches = GlobalSearchRegistry.search('defaulter');
      expect(matches, isNotEmpty);
      expect(
        matches.any((e) => e.route == RouteNames.financeDefaulters),
        isTrue,
      );

      // Empty: a string that no label/keyword contains returns nothing.
      final empty = GlobalSearchRegistry.search('zzqqxx-no-such-destination');
      expect(empty, isEmpty);
    });
  });

  group('QA-C-007 · PAGINATION primitive', () {
    test('loading the next page APPENDS (grows the list, never replaces)', () {
      const source = ['a', 'b', 'c', 'd', 'e'];
      const pageSize = 2;

      // Simulate an infinite-scroll loader that accumulates pages.
      final accumulated = <String>[];

      final page1 = PaginatedResult.fromItems(source, page: 1, pageSize: pageSize);
      accumulated.addAll(page1.items);
      expect(accumulated, ['a', 'b']);
      expect(page1.hasMore, isTrue);

      // Page 2 must APPEND to the already-loaded page 1, not replace it.
      final page2 = PaginatedResult.fromItems(source, page: 2, pageSize: pageSize);
      accumulated.addAll(page2.items);
      expect(accumulated, ['a', 'b', 'c', 'd']); // grew; page 1 still present
      expect(page2.hasMore, isTrue);

      // Final page tops up the rest and reports there is nothing more to load.
      final page3 = PaginatedResult.fromItems(source, page: 3, pageSize: pageSize);
      accumulated.addAll(page3.items);
      expect(accumulated, ['a', 'b', 'c', 'd', 'e']);
      expect(page3.hasMore, isFalse);
      // No duplication / no loss across the appends.
      expect(accumulated.length, source.length);
    });
  });
}
