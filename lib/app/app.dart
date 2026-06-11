import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/providers/router_provider.dart';
import '../features/school_completion/school_branding_theme_provider.dart';
import '../theme/app_theme.dart';

/// Root widget: Material 3 theme + GoRouter via Riverpod.
class AksharaApp extends ConsumerWidget {
  const AksharaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final whiteLabel = ref.watch(schoolBrandingThemeProvider);
    final appTitle = ref.watch(schoolDisplayNameProvider);

    return MaterialApp.router(
      title: appTitle.isNotEmpty ? appTitle : AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AksharaAppTheme.light(whiteLabel: whiteLabel),
      darkTheme: AksharaAppTheme.dark(whiteLabel: whiteLabel),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
