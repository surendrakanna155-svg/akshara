// QA-X-024 — Large-list rendering at scale (deterministic widget benchmark).
//
// The app renders long rosters/lists via lazy builders — e.g.
// lib/features/teacher/attendance/teacher_attendance_screen.dart uses
// `ListView.separated(itemCount: ..., itemBuilder: ...)`. The reliability
// property we assert here is LAZINESS: a `ListView.builder`/`.separated`
// inside a sized viewport must NOT materialize all N items up front. It
// instantiates only a viewport-sized window (+ a small cache-extent buffer),
// so build cost is O(viewport), not O(n).
//
// This benchmark mirrors that exact pattern with 5000 items, counts how many
// times `itemBuilder` runs (and how many row widgets are actually in the
// element tree), and asserts the count stays far below the item count. It is
// self-contained: it builds a representative list widget rather than mounting
// a whole screen, but uses the same ListView API the app uses, so it proves
// the no-O(n)-full-materialization property generically.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QA-X-024 large-list lazy rendering', () {
    const itemCount = 5000;

    // A fixed, sized viewport so the number of on-screen rows is deterministic
    // regardless of host screen size. 600px / 60px-rows ≈ 10 visible rows.
    const viewportHeight = 600.0;
    const rowHeight = 60.0;
    const visibleRows = viewportHeight ~/ rowHeight; // 10

    // Generous ceiling: visible rows + Flutter's default 250px cache extent on
    // both edges (~4 rows each) + slop. If the list were O(n) materialized this
    // would be 5000 and blow straight past the ceiling.
    const lazyCeiling = visibleRows + 30; // 40 << 5000

    /// Mirrors the app's `ListView.separated(itemCount, itemBuilder)` usage,
    /// reporting each `itemBuilder` invocation through [onBuildItem].
    Widget buildList({
      required bool separated,
      required void Function(int index) onBuildItem,
    }) {
      Widget row(BuildContext context, int index) {
        onBuildItem(index);
        return SizedBox(
          height: rowHeight,
          child: Center(child: Text('Student #$index', key: ValueKey(index))),
        );
      }

      final list = separated
          ? ListView.separated(
              itemCount: itemCount,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: row,
            )
          : ListView.builder(
              itemCount: itemCount,
              itemBuilder: row,
            );

      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            height: viewportHeight,
            width: 400,
            child: list,
          ),
        ),
      );
    }

    testWidgets(
      'ListView.builder materializes only a viewport-sized window, not all '
      '$itemCount items',
      (tester) async {
        final built = <int>{};
        await tester.pumpWidget(
          buildList(separated: false, onBuildItem: built.add),
        );
        await tester.pump();

        // Hard proof of laziness: itemBuilder ran for far fewer than itemCount.
        expect(
          built.length,
          lessThan(lazyCeiling),
          reason: 'itemBuilder ran ${built.length} times for $itemCount items '
              '— expected a viewport-sized window (< $lazyCeiling), proving no '
              'O(n) full materialization.',
        );

        // The actual element/render tree only holds the windowed rows too.
        expect(find.byType(SizedBox).evaluate().length, lessThan(itemCount));

        // The first rows are present; the last item is NOT built up front.
        expect(find.byKey(const ValueKey(0)), findsOneWidget);
        expect(find.byKey(const ValueKey(itemCount - 1)), findsNothing);
        expect(built.contains(itemCount - 1), isFalse);
      },
    );

    testWidgets(
      'ListView.separated (the attendance-roster pattern) is lazy for '
      '$itemCount items',
      (tester) async {
        final built = <int>{};
        await tester.pumpWidget(
          buildList(separated: true, onBuildItem: built.add),
        );
        await tester.pump();

        expect(
          built.length,
          lessThan(lazyCeiling),
          reason: 'separated itemBuilder ran ${built.length} times for '
              '$itemCount items — expected a bounded window.',
        );
        expect(built.contains(itemCount - 1), isFalse);
      },
    );

    testWidgets(
      'scrolling reuses the window — total distinct builds stay sub-linear and '
      'far-off items are recycled, not retained',
      (tester) async {
        final built = <int>{};
        await tester.pumpWidget(
          buildList(separated: false, onBuildItem: built.add),
        );
        await tester.pump();
        final initialWindow = Set<int>.from(built);

        // Scroll deep into the list (≈ 2000 rows down). A lazy list builds the
        // newly-revealed window and disposes the rows scrolled far off-screen.
        await tester.drag(find.byType(Scrollable), const Offset(0, -120000));
        await tester.pump();

        // We are now somewhere deep in the list — high-index rows are built.
        expect(
          built.any((i) => i > 1000),
          isTrue,
          reason: 'scrolling should reveal/build high-index rows lazily',
        );

        // Even after scrolling through thousands of items, only a viewport
        // window is mounted at any instant: rows from the initial top window
        // have been recycled out of the tree.
        final mountedNow = find.byType(SizedBox).evaluate().length;
        expect(mountedNow, lessThan(lazyCeiling));
        expect(
          find.byKey(ValueKey(initialWindow.first)),
          findsNothing,
          reason: 'the original top-of-list row should be recycled after a '
              'deep scroll, not retained — bounded memory.',
        );
      },
    );
  });
}
