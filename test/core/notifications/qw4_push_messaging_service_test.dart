import 'package:akshara_erp/core/notifications/notification_ui_keys.dart';
import 'package:akshara_erp/core/notifications/push_messaging_service.dart';
import 'package:akshara_erp/core/providers/router_provider.dart';
import 'package:akshara_erp/features/notifications/notifications_models.dart';
import 'package:akshara_erp/features/notifications/notifications_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

/// QW4 · QA-X-011 — feed a FAKE [RemoteMessage] to the foreground + tap handlers
/// and assert the in-app effects.
///
/// SCOPE / INFRA NOTE (see FINDINGS): the *delivery* legs of
/// [PushMessagingService] (`requestPermission`, `getToken`, the
/// `FirebaseMessaging.onMessage` / `onMessageOpenedApp` streams, background
/// isolate registration) are FCM/platform plumbing that cannot run headless;
/// those are exercised on the device/FCM lane alongside QA-X-010/012. This test
/// covers the *pure handler logic* those streams invoke — the part that actually
/// surfaces a banner, refreshes the inbox, and deep-links a tap — via the
/// `@visibleForTesting` seams [PushMessagingService.handleForegroundMessage] and
/// [PushMessagingService.handleNotificationTapped].

/// Records whether the inbox was refreshed by the foreground handler.
class _RefreshSpyNotifier extends NotificationsNotifier {
  int refreshCount = 0;

  @override
  List<AppNotification> build() => const [];

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

/// A small router whose current location reveals where a tap deep-linked to.
GoRouter _recordingRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/fees',
        builder: (_, __) => const Scaffold(body: Text('fees-route')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const Scaffold(body: Text('notifications-route')),
      ),
    ],
  );
}

/// Provider that captures the live [Ref] so the test can build a service bound
/// to the same container the overrides apply to.
final _serviceProbeProvider = Provider<PushMessagingService>(
  (ref) => PushMessagingService(ref),
);

void main() {
  testWidgets(
      'QA-X-011 foreground message surfaces an in-app banner and refreshes inbox',
      (tester) async {
    useMobileViewport(tester);
    final refreshSpy = _RefreshSpyNotifier();

    late PushMessagingService service;
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides([
          notificationsProvider.overrideWith(() => refreshSpy),
        ]),
        child: Consumer(
          builder: (context, ref, _) {
            service = ref.read(_serviceProbeProvider);
            return MaterialApp(
              // The push layer shows its banner via this global key (no context).
              scaffoldMessengerKey: rootScaffoldMessengerKey,
              home: const Scaffold(body: SizedBox.shrink()),
            );
          },
        ),
      ),
    );
    await tester.pump();

    // A foreground push with a notification block + deep link.
    const message = RemoteMessage(
      notification: RemoteNotification(
        title: 'Fee reminder',
        body: '₹4,200 due by 15 Jun',
      ),
      data: {'route': '/fees'},
    );
    service.handleForegroundMessage(message);
    await tester.pump();

    // Inbox refreshed so the new item appears immediately.
    expect(refreshSpy.refreshCount, 1);

    // An in-app SnackBar banner is shown with the title + body and a "View" CTA
    // (because the message carries a deep link).
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Fee reminder'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets(
      'QA-X-011 foreground message with no title/body shows no banner',
      (tester) async {
    useMobileViewport(tester);
    final refreshSpy = _RefreshSpyNotifier();

    late PushMessagingService service;
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides([
          notificationsProvider.overrideWith(() => refreshSpy),
        ]),
        child: Consumer(
          builder: (context, ref, _) {
            service = ref.read(_serviceProbeProvider);
            return MaterialApp(
              scaffoldMessengerKey: rootScaffoldMessengerKey,
              home: const Scaffold(),
            );
          },
        ),
      ),
    );
    await tester.pump();

    // A data-only message with no renderable title/body: still refreshes the
    // inbox but shows no banner (nothing to display).
    const message = RemoteMessage(data: {'silent': 'true'});
    service.handleForegroundMessage(message);
    await tester.pump();

    expect(refreshSpy.refreshCount, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('QA-X-011 notification tap deep-links to the carried route',
      (tester) async {
    useMobileViewport(tester);
    final router = _recordingRouter();

    late PushMessagingService service;
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides([
          goRouterProvider.overrideWithValue(router),
        ]),
        child: Consumer(
          builder: (context, ref, _) {
            service = ref.read(_serviceProbeProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Background/terminated tap routes to the deep link in the message data.
    const message = RemoteMessage(data: {'route': '/fees'});
    service.handleNotificationTapped(message);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/fees');
    expect(find.text('fees-route'), findsOneWidget);
  });

  testWidgets('QA-X-011 notification tap with no route does not navigate',
      (tester) async {
    useMobileViewport(tester);
    final router = _recordingRouter();

    late PushMessagingService service;
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides([
          goRouterProvider.overrideWithValue(router),
        ]),
        child: Consumer(
          builder: (context, ref, _) {
            service = ref.read(_serviceProbeProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No deep link → stays on the initial route (no crash, no navigation).
    const message = RemoteMessage(data: {'noise': 'x'});
    service.handleNotificationTapped(message);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');
  });
}
