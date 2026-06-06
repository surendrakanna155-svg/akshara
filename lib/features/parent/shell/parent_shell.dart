import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../theme/theme_extensions.dart';

/// Parent mobile shell with bottom navigation (Home · Attendance · Fees).
class ParentShell extends StatelessWidget {
  const ParentShell({
    super.key,
    required this.child,
  });

  final Widget child;

  static const _destinations = <_ParentNavDestination>[
    _ParentNavDestination(
      route: RouteNames.parentDashboard,
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _ParentNavDestination(
      route: RouteNames.parentAttendance,
      label: 'Academics',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
    ),
    _ParentNavDestination(
      route: RouteNames.parentFees,
      label: 'Fees',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
    ),
  ];

  int _selectedIndex(String location) {
    if (location.startsWith(RouteNames.parentAttendance)) {
      return 1;
    }
    if (location.startsWith(RouteNames.parentFees)) {
      return 2;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(path);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        height: context.akshara.bottomNavHeight,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          final destination = _destinations[index];
          if (destination.route != path) {
            context.go(destination.route);
          }
        },
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _ParentNavDestination {
  const _ParentNavDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
