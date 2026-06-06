import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/providers/router_provider.dart';
import '../theme/app_theme.dart';

/// Root widget: Material 3 theme + GoRouter via Riverpod.
class AksharaApp extends ConsumerWidget {
  const AksharaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AksharaAppTheme.light(),
      darkTheme: AksharaAppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
