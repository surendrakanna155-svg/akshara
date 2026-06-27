import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/notifications/notification_ui_keys.dart';
import '../core/providers/router_provider.dart';
import '../core/reliability/drafts/draft_autosave.dart';
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: child ?? const SizedBox.shrink()),
            SyncBanner(
              onOpenSyncCenter: () =>
                  ref.read(goRouterProvider).push(RouteNames.syncCenter),
            ),
          ],
        );
      },
    );
  }
}
