import '../../../theme/breakpoints.dart';

/// User-selectable primary AI entry surface (INTEL-05).
enum AiAccessMode {
  floatingBubble('floating_bubble', 'Floating bubble'),
  bottomNavCenter('bottom_nav_center', 'Bottom navigation center'),
  sidebarEntry('sidebar_entry', 'Sidebar entry'),
  appBarAction('app_bar_action', 'App bar AI action'),
  auto('auto', 'Auto (recommended)');

  const AiAccessMode(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static AiAccessMode? fromStorageKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final mode in AiAccessMode.values) {
      if (mode.storageKey == key) return mode;
    }
    return null;
  }
}

AiAccessMode resolveEffectiveAiAccessMode(
  AiAccessMode mode,
  LayoutBreakpoint breakpoint,
) {
  if (mode != AiAccessMode.auto) return mode;
  return switch (breakpoint) {
    LayoutBreakpoint.mobile => AiAccessMode.bottomNavCenter,
    LayoutBreakpoint.tablet || LayoutBreakpoint.desktop => AiAccessMode.sidebarEntry,
  };
}
