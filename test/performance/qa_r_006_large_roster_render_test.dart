// QA-R-006 — Large-roster render-at-scale (deterministic widget benchmark).
//
// This is the Flutter (client) half of QA-R-006 verify-at-scale. It extends the
// QA-X-024 lazy-render proof (test/performance/qa_x_024_large_list_lazy_render_test.dart)
// from a trivial one-line row to a ROSTER / MARKS-ENTRY-representative row — the
// real shape a teacher sees when marking a 5000-pupil school: avatar + name +
// roll no + a class/section chip + an editable marks field + a status pill. The
// app renders these long rosters via lazy builders (e.g.
// lib/features/teacher/attendance/teacher_attendance_screen.dart uses
// `ListView.separated(itemCount:, itemBuilder:)`), so the reliability property is
// LAZINESS: a builder list inside a sized viewport must NOT materialize all N
// rows up front — it instantiates only a viewport-sized window (+ a small
// cache-extent buffer), so build cost is O(viewport), not O(n).
//
// We assert, for N = 5000 rows in a fixed viewport:
//   • laziness — itemBuilder runs only ~viewport+buffer times, NOT 5000;
//   • the last row is NOT built up front;
//   • recycling — after a deep scroll only a window is mounted and the original
//     top rows are disposed (bounded memory);
//   • a build budget — pumping the heavier roster row stays within a frame-time
//     budget we define here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QA-R-006 large-roster lazy rendering (5000 rows)', () {
    const itemCount = 5000;

    // A fixed, sized viewport so the on-screen row count is deterministic
    // regardless of host screen size. 600px / 96px-rows ≈ 6 visible rows.
    const viewportHeight = 600.0;
    const rowHeight = 96.0;
    const viewportWidth = 600.0;
    const visibleRows = viewportHeight ~/ rowHeight; // 6

    // Generous ceiling: visible rows + Flutter's default 250px cache extent on
    // both edges (~3 rows each at 96px) + slop. An O(n) list would be 5000 here
    // and blow straight past the ceiling.
    const lazyCeiling = visibleRows + 30; // 36 << 5000

    // Build budget: the windowed roster build must not do O(n) work. The
    // DETERMINISTIC proof of that is the `built.length < lazyCeiling` assertion
    // below — wall-clock is only a coarse secondary tripwire. We therefore keep
    // the time ceiling deliberately generous so a noisy/contended CI box (the
    // full suite runs thousands of tests concurrently) never flakes it, while an
    // O(n) materialization of 5000 rich rows — which takes SECONDS, not tens of
    // ms — still trips it. The tight ~250ms wall-clock target lives in
    // docs/PERFORMANCE_TARGETS.md (T8) / the live benchmark lane, not as a hard,
    // contention-sensitive unit gate.
    const buildBudgetMs = 2000;

    /// A roster / marks-entry-representative row: the shape a teacher actually
    /// sees per pupil. Mirrors the app's `ListView.separated(itemCount,
    /// itemBuilder)` usage and reports each `itemBuilder` invocation through
    /// [onBuildItem].
    Widget buildRoster({
      required void Function(int index) onBuildItem,
    }) {
      Widget rosterRow(BuildContext context, int index) {
        onBuildItem(index);
        return SizedBox(
          height: rowHeight,
          child: Padding(
            key: ValueKey(index),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Avatar.
                CircleAvatar(
                  radius: 18,
                  child: Text('${index % 100}'),
                ),
                const SizedBox(width: 12),
                // Name + roll no.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Student #$index',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        'Roll ${index + 1} · Grade ${(index % 12) + 1}-'
                        '${String.fromCharCode(65 + (index % 4))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Class/section chip.
                Chip(
                  label: Text('Sec ${String.fromCharCode(65 + (index % 4))}'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                // Editable marks field (the marks-entry surface).
                SizedBox(
                  width: 56,
                  child: Text(
                    '${index % 100}/100',
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                // Status pill (present/absent/leave).
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: index % 3 == 0
                        ? Colors.green.shade100
                        : index % 3 == 1
                            ? Colors.red.shade100
                            : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    index % 3 == 0
                        ? 'Present'
                        : index % 3 == 1
                            ? 'Absent'
                            : 'Leave',
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: viewportHeight,
              width: viewportWidth,
              child: ListView.separated(
                itemCount: itemCount,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: rosterRow,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'a $itemCount-pupil roster materializes only a viewport-sized window, '
      'not all rows, and within the build budget',
      (tester) async {
        final built = <int>{};
        final sw = Stopwatch()..start();
        await tester.pumpWidget(buildRoster(onBuildItem: built.add));
        await tester.pump();
        sw.stop();

        // Build budget: the initial windowed build is fast (no O(n) work).
        expect(
          sw.elapsedMilliseconds,
          lessThan(buildBudgetMs),
          reason: 'pumping the windowed roster took ${sw.elapsedMilliseconds}ms '
              '(budget < ${buildBudgetMs}ms) — an O(n) materialization of '
              '$itemCount rich rows would dwarf this.',
        );

        // Hard proof of laziness: itemBuilder ran for far fewer than itemCount.
        expect(
          built.length,
          lessThan(lazyCeiling),
          reason: 'itemBuilder ran ${built.length} times for $itemCount rows — '
              'expected a viewport-sized window (< $lazyCeiling), proving no '
              'O(n) full materialization.',
        );

        // The element tree only holds the windowed rows too.
        expect(find.byType(CircleAvatar).evaluate().length, lessThan(itemCount));

        // The first row is present; the last pupil is NOT built up front.
        expect(find.byKey(const ValueKey(0)), findsOneWidget);
        expect(find.byKey(const ValueKey(itemCount - 1)), findsNothing);
        expect(built.contains(itemCount - 1), isFalse);
      },
    );

    testWidgets(
      'scrolling the roster reuses the window — distinct builds stay sub-linear '
      'and far-off pupils are recycled, not retained',
      (tester) async {
        final built = <int>{};
        await tester.pumpWidget(buildRoster(onBuildItem: built.add));
        await tester.pump();
        final initialWindow = Set<int>.from(built);

        // Scroll deep into the roster (≈ 2000 rows down). A lazy list builds the
        // newly-revealed window and disposes rows scrolled far off-screen.
        await tester.drag(find.byType(Scrollable), const Offset(0, -150000));
        await tester.pump();

        // We are now deep in the roster — high-index pupils are built.
        expect(
          built.any((i) => i > 1000),
          isTrue,
          reason: 'scrolling should reveal/build high-index pupils lazily',
        );

        // Even after scrolling through thousands of pupils, only a viewport
        // window is mounted at any instant: rows from the initial top window
        // have been recycled out of the tree (bounded memory).
        final mountedNow = find.byType(CircleAvatar).evaluate().length;
        expect(mountedNow, lessThan(lazyCeiling));
        expect(
          find.byKey(ValueKey(initialWindow.first)),
          findsNothing,
          reason: 'the original top-of-roster row should be recycled after a '
              'deep scroll, not retained.',
        );
      },
    );

    testWidgets(
      'total distinct rows built across a full deep scroll stays far below '
      '$itemCount (windowed, not O(n))',
      (tester) async {
        final built = <int>{};
        await tester.pumpWidget(buildRoster(onBuildItem: built.add));
        await tester.pump();

        // Several large drags to traverse much of the roster.
        for (var i = 0; i < 5; i++) {
          await tester.drag(find.byType(Scrollable), const Offset(0, -60000));
          await tester.pump();
        }

        // Even after traversing thousands of rows, the DISTINCT build count is a
        // function of how far we scrolled (a sliding window), never all 5000 at
        // once — and the mounted set stays bounded.
        expect(find.byType(CircleAvatar).evaluate().length, lessThan(lazyCeiling));
        expect(
          built.length,
          lessThan(itemCount),
          reason: 'distinct rows ever built (${built.length}) must remain below '
              '$itemCount — the list never fully materializes.',
        );
      },
    );
  });
}
