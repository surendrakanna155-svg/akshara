import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../theme/theme_extensions.dart';
import 'admin_navigation_provider.dart';
import 'models/admin_nav_models.dart';

/// Phone-only bottom navigation for the admin shell — gives the web ERP the
/// same one-handed reach the consumer apps already have (MOBILE_FIRST_AUDIT #3,
/// deferred from UX Batch 2). Shows up to [_maxTabs] of the **active
/// workspace's** modules plus a "More" tab that opens the full module drawer
/// (the owner's "bottom nav + keep drawer reachable" decision). The rail still
/// owns tablet/desktop; this only renders on mobile.
class AdminBottomNav extends ConsumerWidget {
  const AdminBottomNav({
    super.key,
    required this.currentLocation,
    required this.onMore,
  });

  /// Current router path, used to highlight the active module.
  final String currentLocation;

  /// Opens the module drawer (all workspace modules + AI entry).
  final VoidCallback onMore;

  static const int _maxTabs = 4;

  /// Whether [location] belongs to [destination] — mirrors the rail's matching
  /// (exact, nested route, and the admissions dashboard/list special case).
  bool _matches(AdminNavDestination destination, String location) {
    final route = destination.route;
    if (location == route || location.startsWith('$route/')) return true;
    if (destination.route == RouteNames.admissionsDashboard &&
        location.startsWith(RouteNames.admissions)) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(workspaceScopedNavDestinationsProvider);
    if (destinations.isEmpty) return const SizedBox.shrink();

    final visible = destinations.take(_maxTabs).toList();

    // Keep the active module visible even when it lives past the 4th slot.
    final activeIndex =
        destinations.indexWhere((d) => _matches(d, currentLocation));
    if (activeIndex >= _maxTabs) {
      visible[_maxTabs - 1] = destinations[activeIndex];
    }

    final selectedVisible =
        visible.indexWhere((d) => _matches(d, currentLocation));
    final selectedIndex = selectedVisible >= 0 ? selectedVisible : 0;

    return NavigationBar(
      height: context.akshara.bottomNavHeight,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == visible.length) {
          onMore();
          return;
        }
        final destination = visible[index];
        if (!_matches(destination, currentLocation)) {
          context.go(destination.route);
        }
      },
      destinations: [
        for (final d in visible)
          NavigationDestination(
            key: QaTestKeys.adminBottomNavModule(d.module.name),
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
        const NavigationDestination(
          key: QaTestKeys.adminBottomNavMore,
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'More',
        ),
      ],
    );
  }
}
