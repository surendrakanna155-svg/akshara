import 'package:akshara_erp/features/notifications/notifications_models.dart';
import 'package:akshara_erp/features/notifications/notifications_provider.dart';
import 'package:akshara_erp/features/notifications/notifications_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW1 · QA-F-018 — Notifications list screen render + empty state.
/// `notifications_screen.dart` was ~0.6% lcov; this pumps the screen with the
/// seeded inbox (rows + filter chips + mark-all-read) and with a forced-empty
/// inbox (the "all caught up" empty state).

/// Notifier that yields an empty inbox without triggering a live refresh.
class _EmptyNotificationsNotifier extends NotificationsNotifier {
  @override
  List<AppNotification> build() => const [];
}

Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const NotificationsScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('QA-F-018 · NotificationsScreen', () {
    testWidgets('renders the seeded inbox with chips + mark-all-read',
        (tester) async {
      await _pump(tester);

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);
      expect(find.text('All'), findsWidgets); // filter chip
      // At least one seeded notification row is visible.
      expect(find.text('Fee reminder — Term 2'), findsOneWidget);
    });

    testWidgets('shows the empty state when the inbox is empty', (tester) async {
      await _pump(
        tester,
        overrides: [
          notificationsProvider.overrideWith(_EmptyNotificationsNotifier.new),
        ],
      );

      expect(find.text("You're all caught up"), findsOneWidget);
      expect(find.text('Fee reminder — Term 2'), findsNothing);
    });
  });
}
