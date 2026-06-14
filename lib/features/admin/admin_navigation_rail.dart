import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../theme/breakpoints.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../copilot/copilot_navigation.dart';
import '../copilot/settings/ai_access_preferences_provider.dart';
import '../copilot/widgets/copilot_ai_quick_actions.dart';
import 'admin_navigation_provider.dart';
import 'models/admin_nav_models.dart';

/// Side navigation for the web ERP shell — expanded rail, collapsed rail, or drawer.
class AdminNavigationRail extends ConsumerWidget {
  const AdminNavigationRail({
    super.key,
    required this.currentLocation,
    this.expanded = true,
    this.inDrawer = false,
    this.onDestinationSelected,
  });

  final String currentLocation;
  final bool expanded;
  final bool inDrawer;
  final VoidCallback? onDestinationSelected;

  int _selectedIndex(List<AdminNavDestination> destinations) {
    for (var i = 0; i < destinations.length; i++) {
      final route = destinations[i].route;
      if (currentLocation == route ||
          currentLocation.startsWith('$route/') ||
          (route == RouteNames.admissionsDashboard &&
              currentLocation.startsWith(RouteNames.admissions))) {
        return i;
      }
    }
    return 0;
  }

  void _navigate(BuildContext context, AdminNavDestination destination) {
    if (destination.route != currentLocation) {
      context.go(destination.route);
    }
    onDestinationSelected?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(adminNavDestinationsProvider);
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;
    final selectedIndex = _selectedIndex(destinations);
    final width = MediaQuery.sizeOf(context).width;
    final breakpoint = AksharaBreakpoints.fromWidth(width);
    final prefs = ref.watch(aiAccessPreferencesProvider);
    final showSidebarAi = shouldShowAdminSidebarAiEntry(
      prefs: prefs,
      breakpoint: breakpoint,
    );

    if (inDrawer) {
      return Material(
        color: colors.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s6),
                child: Text(
                  'Akshara ERP',
                  style: text.titleMedium.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final destination = destinations[index];
                    final selected = index == selectedIndex;
                    return ListTile(
                      key: QaTestKeys.erpNavModule(destination.module.name),
                      leading: Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      title: Text(
                        destination.label,
                        style: text.labelLarge.copyWith(
                          color: selected
                              ? colors.primary
                              : colors.onSurface,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      selected: selected,
                      selectedTileColor: colors.primaryContainer.withValues(
                        alpha: 0.35,
                      ),
                      onTap: () => _navigate(context, destination),
                    );
                  },
                ),
              ),
              if (showSidebarAi) _AdminSidebarAiTile(onNavigate: onDestinationSelected),
            ],
          ),
        ),
      );
    }

    return Material(
      color: colors.surfaceContainerLow,
      child: NavigationRail(
        extended: expanded,
        minWidth: ext.navRailCollapsedWidth,
        minExtendedWidth: ext.navRailExpandedWidth,
        selectedIndex: selectedIndex,
        labelType: NavigationRailLabelType.none,
        leading: expanded
            ? Padding(
                padding: const EdgeInsets.fromLTRB(
                  AksharaSpacing.s4,
                  AksharaSpacing.s6,
                  AksharaSpacing.s4,
                  AksharaSpacing.s4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Akshara ERP',
                    style: text.titleSmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            : const SizedBox(height: AksharaSpacing.s6),
        trailing: showSidebarAi
            ? Padding(
                padding: const EdgeInsets.only(bottom: AksharaSpacing.s4),
                child: _AdminSidebarAiTile(
                  compact: !expanded,
                  onNavigate: onDestinationSelected,
                ),
              )
            : null,
        onDestinationSelected: (index) =>
            _navigate(context, destinations[index]),
        destinations: [
          for (final destination in destinations)
            NavigationRailDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: Text(destination.label),
            ),
        ],
      ),
    );
  }
}

class _AdminSidebarAiTile extends ConsumerWidget {
  const _AdminSidebarAiTile({
    this.compact = false,
    this.onNavigate,
  });

  final bool compact;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: true,
      label: 'AI Assistant sidebar entry',
      child: Material(
        color: colors.surfaceContainerHighest,
        child: InkWell(
          key: QaTestKeys.copilotSidebarAiEntry,
          onTap: () {
            openAiAssistantFromDock(context, ref);
            onNavigate?.call();
          },
          onLongPress: () =>
              handleCopilotAiEntryLongPress(context, ref, Offset.zero),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AksharaSpacing.s2 : AksharaSpacing.s4,
              vertical: AksharaSpacing.s3,
            ),
            child: compact
                ? Icon(Icons.psychology_outlined, color: colors.primary)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.psychology_outlined, color: colors.primary),
                      const SizedBox(width: AksharaSpacing.s3),
                      Text(
                        'AI Assistant',
                        style: text.labelLarge.copyWith(color: colors.primary),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
