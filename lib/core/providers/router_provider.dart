import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/legal/legal_gate_provider.dart';
import '../../core/config/environment_provider.dart';
import '../../router/app_router.dart';
import 'router_refresh_notifier.dart';

/// Application-wide [GoRouter] instance.
///
/// Redirects refresh when [authProvider] or the legal gate changes via
/// [routerRefreshNotifierProvider] without recreating the router.
final goRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(routerRefreshNotifierProvider);
  // Keep the legal gate in sync with the auth lifecycle (load on login, etc.).
  ref.watch(legalGateSyncProvider);

  return createAppRouter(
    refreshListenable: ref.read(routerRefreshNotifierProvider),
    readAuth: () => ref.read(authProvider),
    readQaLoginEnabled: () => ref.read(isQaLoginEnabledProvider),
    readLegalBlocked: () => ref.read(legalGateBlockedProvider),
  );
});
