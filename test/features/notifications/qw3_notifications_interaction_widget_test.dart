import 'package:akshara_erp/features/notifications/notifications_models.dart';
import 'package:akshara_erp/features/notifications/notifications_provider.dart';
import 'package:akshara_erp/features/notifications/notifications_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-019 — Notifications mark-read on tap + unread badge update.
/// The QW1 test (`notifications_screen_widget_test.dart`) covers render/empty
/// only. This adds the interaction: tapping an unread row marks it read via the
/// provider and the unread badge (`unreadNotificationsCountProvider`) decrements.
///
/// FINDING (documented, not a regression): the production
/// [NotificationsScreen] row `onTap` marks the item read but does NOT navigate /
/// deep-link to the source surface — no deep-link is wired in the screen today.
/// The "deep-link tap" half of the row is therefore asserted as the mark-read +
/// badge contract only; see the agent FINDINGS note (P2, enhancement).

/// Seeds a deterministic two-item inbox (1 unread + 1 read) so the badge math is
/// exact and independent of the live comm-store bridge / time-based seed.
class _SeededNotificationsNotifier extends NotificationsNotifier {
  @override
  List<AppNotification> build() => [
        AppNotification(
          id: 'seed-unread',
          title: 'Fee reminder — Term 2',
          preview: 'Pay online to avoid a late fee.',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          category: NotificationCategory.fee,
        ),
        AppNotification(
          id: 'seed-read',
          title: 'School holiday — Eid',
          preview: 'School closed tomorrow.',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          category: NotificationCategory.announcement,
          isRead: true,
        ),
      ];
}

/// Pumps the screen behind a [Consumer] so the test can read providers
/// (e.g. the unread badge) from the live container after each interaction.
Future<WidgetRef> _pumpWithRef(WidgetTester tester) async {
  late WidgetRef capturedRef;
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        notificationsProvider.overrideWith(_SeededNotificationsNotifier.new),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return const NotificationsScreen();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return capturedRef;
}

void main() {
  group('QA-F-019 · NotificationsScreen interaction', () {
    testWidgets('tapping an unread row marks it read and drops the unread badge',
        (tester) async {
      final capturedRef = await _pumpWithRef(tester);

      // Exactly one item is unread at the start → badge reads 1.
      expect(capturedRef.read(unreadNotificationsCountProvider), 1);
      expect(find.text('Fee reminder — Term 2'), findsOneWidget);

      // Tap the unread row → the screen calls notifier.markRead(id).
      await tester.tap(find.text('Fee reminder — Term 2'));
      await tester.pump();

      // Mark-read provider fired: the item is now read, so the badge is 0.
      expect(capturedRef.read(unreadNotificationsCountProvider), 0);
      final marked = capturedRef
          .read(notificationsProvider)
          .firstWhere((n) => n.id == 'seed-unread');
      expect(marked.isRead, isTrue);
    });

    testWidgets('Mark all read clears the unread badge to zero', (tester) async {
      final capturedRef = await _pumpWithRef(tester);

      expect(capturedRef.read(unreadNotificationsCountProvider), 1);

      await tester.tap(find.text('Mark all read'));
      await tester.pump();

      expect(capturedRef.read(unreadNotificationsCountProvider), 0);
    });
  });
}
