import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
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
        labelType: expanded
            ? NavigationRailLabelType.none
            : NavigationRailLabelType.none,
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
