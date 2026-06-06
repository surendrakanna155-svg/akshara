import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../router/app_router.dart';
import 'router_refresh_notifier.dart';

/// Application-wide [GoRouter] instance.
///
/// Rebuilds redirects when [authProvider] changes via [routerRefreshNotifierProvider].
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshNotifierProvider);
  final auth = ref.watch(authProvider);

  return createAppRouter(
    refreshListenable: refresh,
    auth: auth,
  );
});
