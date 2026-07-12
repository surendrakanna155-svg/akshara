import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/notifications/notification_ui_keys.dart';
import '../core/providers/router_provider.dart';
import '../core/security/app_lock/app_lock_controller.dart' show appLockArmsOnBackground;
import '../core/security/app_lock/app_lock_overlay.dart';
import '../core/security/app_lock/app_lock_providers.dart';
import '../features/auth/auth_provider.dart';
import '../core/reliability/drafts/draft_autosave.dart';
import '../core/reliability/reliability_providers.dart';
import '../core/reliability/sync_center/sync_banner.dart';
import '../features/school_completion/school_branding_theme_provider.dart';
import '../router/route_names.dart';
import '../theme/app_theme.dart';
import '../theme/theme_mode_provider.dart';

/// Root widget: Material 3 theme + GoRouter via Riverpod.
///
/// Also the app's single [WidgetsBindingObserver] (Data Reliability Platform
/// §5): when the app is backgrounded / locked / killed it flushes every active
/// form's draft so a half-typed form is never lost. A global, unobtrusive
/// [SyncBanner] is injected below every screen — it stays hidden unless the
/// device is offline or writes are waiting/conflicted.
class AksharaApp extends ConsumerStatefulWidget {
  const AksharaApp({super.key});

  @override
  ConsumerState<AksharaApp> createState() => _AksharaAppState();
}

class _AksharaAppState extends ConsumerState<AksharaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // Persist every in-progress form immediately (covers phone-lock,
      // app-switch and kill). Fire-and-forget — never block the lifecycle.
      unawaited(ref.read(draftFlushRegistryProvider).flushAll());
      // P1-SEC-1 (audit F1): arm the App Lock timer ONLY on a TRUE background
      // (`paused`/`detached`) — `inactive`/`hidden` also fire during the resume
      // handshake and would reset the timer, defeating re-lock. Pure predicate
      // so this decision is unit-tested.
      if (appLockArmsOnBackground(state)) {
        ref.read(appLockControllerProvider.notifier).onBackground(DateTime.now());
      }
    } else if (state == AppLifecycleState.resumed) {
      // REL-4: on foreground, drain any writes queued while backgrounded/offline
      // (a killed-then-relaunched session may have undrained outbox entries).
      ref.read(syncEngineProvider).flushIfOnline();
      // P1-SEC-1: re-lock if the background outlasted the grace window.
      ref.read(appLockControllerProvider.notifier).onResume(DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final whiteLabel = ref.watch(schoolBrandingThemeProvider);
    final appTitle = ref.watch(schoolDisplayNameProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: appTitle.isNotEmpty ? appTitle : AppConstants.appTitle,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AksharaAppTheme.light(whiteLabel: whiteLabel),
      darkTheme: AksharaAppTheme.dark(whiteLabel: whiteLabel),
      themeMode: themeMode,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        // P1-SEC-1: when App Lock is engaged, cover the ENTIRE app (content +
        // sync banner) with the biometric lock overlay so nothing behind it is
        // visible or interactable until a successful unlock.
        final locked = ref.watch(
          appLockControllerProvider.select((s) => s.locked),
        );
        return Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: child ?? const SizedBox.shrink()),
                SyncBanner(
                  onOpenSyncCenter: () =>
                      ref.read(goRouterProvider).push(RouteNames.syncCenter),
                ),
              ],
            ),
            if (locked)
              Positioned.fill(
                child: AppLockOverlay(
                  // Recovery from a biometric-removed lock-out: sign out (clears
                  // the session) AND disable App Lock, so the router redirects to
                  // a clean login. Safe — logout destroys the protected session.
                  onSignOut: () async {
                    await ref.read(authProvider.notifier).logout();
                    await ref
                        .read(appLockControllerProvider.notifier)
                        .setEnabled(false);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
