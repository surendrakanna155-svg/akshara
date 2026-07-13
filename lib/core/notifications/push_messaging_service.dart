// Firebase Cloud Messaging integration for Akshara ERP.
//
// This is the *device* half of the existing notification pipeline — it does NOT
// replace the Communication Hub. The backend already owns templates, the
// delivery queue, the device-token table and the in-app inbox; this service
// only:
//   • requests the runtime notification permission,
//   • obtains the FCM registration token and registers it with the existing
//     `/parent|/student/device-tokens/register` route (reusing
//     [CommunicationRepository.registerDeviceToken]),
//   • re-registers on token refresh and on login,
//   • surfaces foreground messages as an in-app banner + inbox refresh,
//   • routes notification taps (background / terminated) to the deep link
//     carried in the message `data.route`.
//
// All Firebase calls are best-effort and guarded: a device without Google Play
// services, a denied permission, or a transient backend error must never crash
// or block the app.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_models.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/notifications/notifications_provider.dart';
import '../providers/router_provider.dart';
import '../repositories/repository_providers.dart';
import '../tenant/tenant_provider.dart';
import 'notification_ui_keys.dart';

/// Background / terminated message handler.
///
/// Must be a top-level function annotated with `@pragma('vm:entry-point')` so it
/// survives tree-shaking and can be invoked in a separate isolate. Messages that
/// carry a `notification` block are rendered in the system tray by the OS, so no
/// work is required here; the tap is handled by [FirebaseMessaging.onMessageOpenedApp].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal — the OS displays the tray notification. Kept as an
  // explicit entry point so background delivery is registered with FCM.
}

/// Wires FCM into the running app. Constructed once and started from `main()`
/// after `Firebase.initializeApp` succeeds.
class PushMessagingService {
  PushMessagingService(this._ref);

  final Ref _ref;
  bool _started = false;

  /// Begin listening for tokens and messages. Safe to call more than once.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final messaging = FirebaseMessaging.instance;

    // 1. Runtime permission (Android 13+ POST_NOTIFICATIONS, iOS prompt).
    try {
      await messaging.requestPermission();
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      if (!kReleaseMode) debugPrint('PushMessaging: permission request failed: $error');
    }

    // 2. Token refresh → re-register with the backend.
    messaging.onTokenRefresh.listen(_registerToken);

    // 3. Foreground + tap handlers.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTapped);

    // 4. Cold start from a notification tap (terminated → opened).
    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _onNotificationTapped(initial);
      }
    } catch (error) {
      if (!kReleaseMode) debugPrint('PushMessaging: getInitialMessage failed: $error');
    }

    // 5. Register the current token now (if already logged in) and again
    //    whenever the session transitions into authenticated.
    await _syncToken();
    _ref.listen<AuthState>(authProvider, (previous, next) {
      final loggedInNow =
          next.isAuthenticated && !(previous?.isAuthenticated ?? false);
      if (loggedInNow) {
        _syncToken();
      }
    });
  }

  /// Fetch the active FCM token and register it when authenticated.
  Future<void> _syncToken() async {
    if (!_ref.read(authProvider).isAuthenticated) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (error) {
      if (!kReleaseMode) debugPrint('PushMessaging: getToken failed: $error');
    }
  }

  /// Persist the token via the existing Communication Hub route. Keyed by the
  /// JWT user server-side, so the default route works for parent/student/staff.
  Future<void> _registerToken(String token) async {
    if (!_ref.read(authProvider).isAuthenticated) return;
    try {
      await _ref.read(communicationRepositoryProvider).registerDeviceToken(
            query: _ref.read(repositoryQueryProvider),
            platform: _platformLabel(),
            token: token,
          );
    } catch (error) {
      // Best-effort: a failed registration must not disrupt the session.
      if (!kReleaseMode) debugPrint('PushMessaging: token registration failed: $error');
    }
  }

  /// Test seam for the foreground-message handler (QA-X-011). Exercises the
  /// exact same pure logic FCM drives via `onMessage.listen`, without the FCM
  /// stream/permission plumbing that can't run headless.
  @visibleForTesting
  void handleForegroundMessage(RemoteMessage message) =>
      _onForegroundMessage(message);

  /// Test seam for the notification-tap (background / terminated) handler.
  @visibleForTesting
  void handleNotificationTapped(RemoteMessage message) =>
      _onNotificationTapped(message);

  /// Foreground message: refresh the in-app inbox and show a tappable banner.
  void _onForegroundMessage(RemoteMessage message) {
    // Reuse the existing inbox so the new notification appears immediately.
    try {
      _ref.read(notificationsProvider.notifier).refresh();
    } catch (_) {
      // Inbox refresh is best-effort.
    }

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['body'];
    if (title == null && body == null) return;

    final route = _deepLink(message);
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [title, body].where((s) => s != null && s.isNotEmpty).join('\n'),
        ),
        action: route == null
            ? null
            : SnackBarAction(
                label: 'View',
                onPressed: () => _navigate(route),
              ),
      ),
    );
  }

  /// Notification tap (background / terminated): deep-link into the app.
  void _onNotificationTapped(RemoteMessage message) {
    final route = _deepLink(message);
    if (route != null) {
      _navigate(route);
    }
  }

  void _navigate(String route) {
    try {
      _ref.read(goRouterProvider).go(route);
    } catch (error) {
      if (!kReleaseMode) debugPrint('PushMessaging: navigation to "$route" failed: $error');
    }
  }

  /// Deep-link target from the message data. The backend sends it as `route`;
  /// `deep_link` is accepted as an alias.
  String? _deepLink(RemoteMessage message) {
    final raw = message.data['route'] ?? message.data['deep_link'];
    if (raw is String && raw.startsWith('/')) {
      return raw;
    }
    return null;
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'android';
    }
  }
}

/// App-wide handle to the push service.
final pushMessagingServiceProvider = Provider<PushMessagingService>(
  (ref) => PushMessagingService(ref),
);
