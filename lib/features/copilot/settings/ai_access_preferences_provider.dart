import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/shared_preferences_provider.dart';
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
    if (userId == null) return const AiAccessPreferences();
    final storage = ref.read(aiAccessPreferencesStorageProvider);
    if (storage == null) return const AiAccessPreferences();
    return storage.readSync(userId);
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
