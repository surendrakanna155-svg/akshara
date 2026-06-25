import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/notifications/notification_ui_keys.dart';
import '../core/providers/router_provider.dart';
import '../features/school_completion/school_branding_theme_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_mode_provider.dart';

/// Root widget: Material 3 theme + GoRouter via Riverpod.
class AksharaApp extends ConsumerWidget {
  const AksharaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    );
  }
}
