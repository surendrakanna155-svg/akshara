import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/legal/legal_gate_provider.dart';

/// Bridges Riverpod auth + legal-gate state to [GoRouter.refreshListenable] so
/// the redirect re-evaluates when either changes (e.g. when the legal gate
/// resolves to "blocked" after login, or to "satisfied" after acceptance).
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
    _ref.listen(legalGateProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});
