import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/notifications/notification_ui_keys.dart';
import '../core/providers/router_provider.dart';
import '../core/security/app_lock/app_lock_controller.dart'
    show appLockArmsOnBackground, appLockObscuresOnState;
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
  /// P1-SEC-1 (audit P1-1): when App Lock is enabled and the app leaves the
  /// foreground, we paint an opaque privacy scrim so the OS app-switcher /
  /// recents snapshot captures the scrim, not student PII. Independent of the
  /// biometric re-lock timer — it covers immediately on background and lifts on
  /// resume (a quick switch under the grace window auto-lifts without a prompt).
  bool _obscured = false;

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
      // P1-SEC-1 (audit P1-1): engage the privacy scrim before the OS snapshot.
      if (appLockObscuresOnState(state) &&
          ref.read(appLockControllerProvider).enabled) {
        if (!_obscured && mounted) setState(() => _obscured = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      // REL-4: on foreground, drain any writes queued while backgrounded/offline
      // (a killed-then-relaunched session may have undrained outbox entries).
      ref.read(syncEngineProvider).flushIfOnline();
      // P1-SEC-1: re-lock if the background outlasted the grace window.
      ref.read(appLockControllerProvider.notifier).onResume(DateTime.now());
      // P1-SEC-1 (audit P1-1): lift the privacy scrim now that we are foreground
      // (if the away-time crossed the grace window, onResume already set the
      // biometric lock, so content stays covered by the lock overlay instead).
      if (_obscured && mounted) setState(() => _obscured = false);
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
        // P1-SEC-1 (audit P2-2): the Android back button is NOT intercepted here
        // and does not need to be. This builder-level Stack sits above GoRouter's
        // Navigator but is a descendant of NEITHER a Navigator nor a Router, so
        // PopScope / BackButtonListener cannot register (they throw). That is
        // harmless: the lock overlay is driven by `locked` STATE, not the route
        // stack, so a back press while locked only navigates the HIDDEN route
        // beneath the overlay (still fully covered) or backgrounds the app (which
        // re-locks / re-scrims on resume). No content is ever revealed.
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
            // Privacy scrim (audit P1-1): shown while backgrounded so the OS
            // snapshot never captures PII. The biometric lock overlay, when
            // present, sits above it and supersedes it.
            if (_obscured && !locked)
              const Positioned.fill(child: _AppLockPrivacyScrim()),
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

/// P1-SEC-1 (audit P1-1) — the opaque, branded privacy scrim painted over the
/// app while it is backgrounded and App Lock is on, so the OS app-switcher /
/// recents preview shows this instead of the underlying content. Non-
/// interactive; lifted on resume. (Screenshot suppression while foreground is a
/// native `FLAG_SECURE`/iOS-blur follow-up — tracked separately.)
class _AppLockPrivacyScrim extends StatelessWidget {
  const _AppLockPrivacyScrim();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AbsorbPointer(
      child: Material(
        key: const Key('app-lock-privacy-scrim'),
        color: scheme.surface,
        child: Center(
          child: Icon(Icons.lock_outline, size: 48, color: scheme.primary),
        ),
      ),
    );
  }
}
