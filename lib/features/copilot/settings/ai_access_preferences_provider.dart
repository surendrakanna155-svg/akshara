import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/environment_provider.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../../../core/security/erp_role.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../theme/breakpoints.dart';
import 'ai_access_mode.dart';
import 'ai_access_preferences.dart';
import 'ai_access_preferences_storage.dart';

final aiAccessPreferencesStorageProvider = Provider<AiAccessPreferencesStorage?>((ref) {
  if (!ref.exists(sharedPreferencesProvider)) return null;
  return AiAccessPreferencesStorage(ref.watch(sharedPreferencesProvider));
});

final aiAccessPreferencesProvider =
    NotifierProvider<AiAccessPreferencesNotifier, AiAccessPreferences>(
  AiAccessPreferencesNotifier.new,
);

class AiAccessPreferencesNotifier extends Notifier<AiAccessPreferences> {
  @override
  AiAccessPreferences build() {
    ref.listen(authProvider, (previous, next) {
      state = _readForUser(next.claims?.userId);
    });
    return _readForUser(ref.read(authProvider).claims?.userId);
  }

  AiAccessPreferences _readForUser(String? userId) {
    final role = ref.read(authProvider).claims?.erpRole;
    final roleDefault = _defaultForRole(role);
    final qaDefault = ref.read(environmentProvider).enableQaLogin
        ? roleDefault.copyWith(floatingBubbleEnabled: true)
        : roleDefault;
    if (userId == null) return qaDefault;
    final storage = ref.read(aiAccessPreferencesStorageProvider);
    if (storage == null) return qaDefault;
    final stored = storage.readSync(userId);
    if (stored.mode == AiAccessMode.auto && roleDefault.mode != AiAccessMode.auto) {
      return stored.copyWith(mode: roleDefault.mode);
    }
    if (ref.read(environmentProvider).enableQaLogin && !stored.floatingBubbleEnabled) {
      return stored.copyWith(floatingBubbleEnabled: true);
    }
    return stored;
  }

  AiAccessPreferences _defaultForRole(ErpRole? role) {
    return switch (role) {
      ErpRole.parent || ErpRole.teacher || ErpRole.student => const AiAccessPreferences(
          mode: AiAccessMode.bottomNavCenter,
        ),
      ErpRole.principal || ErpRole.management => const AiAccessPreferences(
          mode: AiAccessMode.sidebarEntry,
        ),
      ErpRole.financeAdmin || ErpRole.admissionsCounselor => const AiAccessPreferences(
          mode: AiAccessMode.appBarAction,
        ),
      ErpRole.transportManager ||
      ErpRole.hostelManager ||
      ErpRole.librarian ||
      ErpRole.inventoryManager =>
        const AiAccessPreferences(mode: AiAccessMode.sidebarEntry),
      _ => const AiAccessPreferences(mode: AiAccessMode.auto),
    };
  }

  Future<void> setMode(AiAccessMode mode) async {
    final userId = ref.read(authProvider).claims?.userId;
    if (userId == null) return;
    final next = state.copyWith(mode: mode);
    state = next;
    await ref.read(aiAccessPreferencesStorageProvider)?.write(userId, next);
  }

  Future<void> setFloatingBubbleEnabled(bool enabled) async {
    final userId = ref.read(authProvider).claims?.userId;
    if (userId == null) return;
    final next = state.copyWith(floatingBubbleEnabled: enabled);
    state = next;
    await ref.read(aiAccessPreferencesStorageProvider)?.write(userId, next);
  }
}

AiAccessMode effectiveAiAccessMode(AiAccessPreferences prefs, LayoutBreakpoint breakpoint) {
  return resolveEffectiveAiAccessMode(prefs.mode, breakpoint);
}

bool shouldShowFloatingAiDock({
  required AiAccessPreferences prefs,
  required LayoutBreakpoint breakpoint,
}) {
  if (prefs.floatingBubbleEnabled) return true;
  return effectiveAiAccessMode(prefs, breakpoint) == AiAccessMode.floatingBubble;
}

bool shouldShowBottomNavAiEntry({
  required AiAccessPreferences prefs,
  required LayoutBreakpoint breakpoint,
}) {
  return effectiveAiAccessMode(prefs, breakpoint) == AiAccessMode.bottomNavCenter;
}

bool shouldShowSidebarAiEntry({
  required AiAccessPreferences prefs,
  required LayoutBreakpoint breakpoint,
}) {
  return effectiveAiAccessMode(prefs, breakpoint) == AiAccessMode.sidebarEntry;
}

bool shouldShowAppBarAiAction({
  required AiAccessPreferences prefs,
  required LayoutBreakpoint breakpoint,
}) {
  return effectiveAiAccessMode(prefs, breakpoint) == AiAccessMode.appBarAction;
}

/// ERP admin mobile has no bottom nav — map center mode to sidebar/drawer slot.
bool shouldShowAdminSidebarAiEntry({
  required AiAccessPreferences prefs,
  required LayoutBreakpoint breakpoint,
}) {
  final effective = effectiveAiAccessMode(prefs, breakpoint);
  if (effective == AiAccessMode.sidebarEntry) return true;
  if (breakpoint == LayoutBreakpoint.mobile &&
      effective == AiAccessMode.bottomNavCenter) {
    return true;
  }
  return false;
}
