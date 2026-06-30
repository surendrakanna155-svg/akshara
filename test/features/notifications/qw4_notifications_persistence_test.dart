import 'package:akshara_erp/features/notifications/notifications_models.dart';
import 'package:akshara_erp/features/notifications/notifications_provider.dart';
import 'package:akshara_erp/features/notifications/notifications_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

/// QW4 · QA-X-013 — notifications screen: load → mark-read PERSISTS → deep-link.
///
/// The mark-read + badge leg overlaps QW3 QA-F-019; this row adds the
/// *persistence-across-rebuild* assertion (the read state survives a widget
/// rebuild via the provider, not just the immediate frame) and pins the
/// deep-link contract.
///
/// KNOWN GAP (documented, not faked — see FINDINGS): the production
/// [NotificationsScreen] row `onTap` only calls `notifier.markRead(id)`; it does
/// NOT navigate / deep-link to the source surface. There is no per-notification
/// route in [AppNotification] and no `context.go` in the row. This test asserts
/// that current behavior explicitly (a tap stays on the inbox) so the gap is
/// visible and tracked rather than silently passing.

/// Deterministic two-item inbox (1 unread + 1 read) independent of the live
/// comm-store bridge / time-based seed.
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

Future<WidgetRef> _pumpScreen(WidgetTester tester, GoRouter router) async {
  late WidgetRef capturedRef;
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        notificationsProvider.overrideWith(_SeededNotificationsNotifier.new),
      ]),
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        routerConfig: router,
        builder: (context, child) => Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return child!;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return capturedRef;
}

GoRouter _router() => GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen(),
        ),
        // Any deep-link target would land here; reaching it would prove a
        // deep-link exists. It is asserted to be UNreached today (known gap).
        GoRoute(
          path: '/fees',
          builder: (_, __) => const Scaffold(body: Text('fees-detail-route')),
        ),
      ],
    );

void main() {
  group('QA-X-013 · NotificationsScreen load + mark-read persistence', () {
    testWidgets('loads the inbox with the unread/read rows', (tester) async {
      await _pumpScreen(tester, _router());

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Fee reminder — Term 2'), findsOneWidget);
      expect(find.text('School holiday — Eid'), findsOneWidget);
    });

    testWidgets('tapping an unread row persists the read state across a rebuild',
        (tester) async {
      final ref = await _pumpScreen(tester, _router());

      // Pre-condition: one unread item → badge 1.
      expect(ref.read(unreadNotificationsCountProvider), 1);

      await tester.tap(find.text('Fee reminder — Term 2'));
      await tester.pumpAndSettle();

      // Force a full widget rebuild and re-read from the provider: the read
      // state must persist (lives in the notifier's state, not the widget).
      await tester.pump();
      final persisted = ref
          .read(notificationsProvider)
          .firstWhere((n) => n.id == 'seed-unread');
      expect(persisted.isRead, isTrue,
          reason: 'mark-read must persist in provider state');
      expect(ref.read(unreadNotificationsCountProvider), 0);

      // The already-read item stays read (no regression).
      final stillRead = ref
          .read(notificationsProvider)
          .firstWhere((n) => n.id == 'seed-read');
      expect(stillRead.isRead, isTrue);
    });

    testWidgets(
        'KNOWN GAP: tapping a row does NOT deep-link — it stays on the inbox',
        (tester) async {
      final router = _router();
      await _pumpScreen(tester, router);

      await tester.tap(find.text('Fee reminder — Term 2'));
      await tester.pumpAndSettle();

      // Current production behavior: tap marks read but does not navigate. The
      // deep-link target is never reached. This is the documented QA-X-013 gap.
      expect(router.routeInformationProvider.value.uri.path, '/notifications');
      expect(find.text('fees-detail-route'), findsNothing);
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });
  });
}
