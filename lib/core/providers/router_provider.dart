import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../router/app_router.dart';
import 'router_refresh_notifier.dart';

/// Application-wide [GoRouter] instance.
///
/// Redirects refresh when [authProvider] changes via
/// [routerRefreshNotifierProvider] without recreating the router.
final goRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(routerRefreshNotifierProvider);

  return createAppRouter(
    refreshListenable: ref.read(routerRefreshNotifierProvider),
    readAuth: () => ref.read(authProvider),
  );
});
