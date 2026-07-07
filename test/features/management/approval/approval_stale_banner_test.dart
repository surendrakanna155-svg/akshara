import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/management/approval/approval_center_provider.dart';
import 'package:akshara_erp/features/management/approval/widgets/approval_stale_banner.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// PRI-5 — the stale-approval escalation banner. The feature shipped in the
// leadership wave (surfacing the previously-inert >48h stale pending count +
// deep-linking into the stale-filtered queue); these close the verified
// test-coverage gap on: it shows only when something is stale, and its action
// toggles the stale filter. Read/filter only — no state mutation, so the
// money/approval maker-checker SoD is never touched.

Future<void> _pump(WidgetTester tester, {required int staleCount}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        approvalCenterStalePendingCountProvider.overrideWithValue(staleCount),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(body: ApprovalStaleBanner()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PRI-5 ApprovalStaleBanner', () {
    testWidgets('surfaces the >48h stale pending count', (tester) async {
      await _pump(tester, staleCount: 3);

      expect(find.byKey(QaTestKeys.approvalStaleBanner), findsOneWidget);
      expect(
        find.textContaining('3 pending approvals have waited more than 48'),
        findsOneWidget,
      );
    });

    testWidgets('stays hidden when nothing is stale', (tester) async {
      await _pump(tester, staleCount: 0);

      expect(find.byKey(QaTestKeys.approvalStaleBanner), findsNothing);
    });

    testWidgets('the action toggles the stale filter (Review stale → Show all)',
        (tester) async {
      await _pump(tester, staleCount: 2);

      // Not filtering yet → the action offers to review the stale items.
      expect(find.text('Review stale'), findsOneWidget);

      await tester.tap(find.text('Review stale'));
      await tester.pumpAndSettle();

      // Filter toggled on (banner still visible — count unchanged) → the action
      // now offers to clear it.
      expect(find.text('Show all'), findsOneWidget);
    });
  });
}
