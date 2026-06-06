import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../router/student_navigation.dart';
import '../../../theme/theme_extensions.dart';

/// Student mobile shell with bottom navigation (Home · Learn · Schedule · Results).
class StudentShell extends StatelessWidget {
  const StudentShell({
    super.key,
    required this.child,
  });

  final Widget child;

  static const _destinations = <_StudentNavDestination>[
    _StudentNavDestination(
      route: RouteNames.studentDashboard,
      actionId: 'home',
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _StudentNavDestination(
      actionId: 'homework_list',
      label: 'Learn',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
    ),
    _StudentNavDestination(
      actionId: 'full_schedule',
      label: 'Schedule',
      icon: Icons.calendar_view_week_outlined,
      selectedIcon: Icons.calendar_view_week,
    ),
    _StudentNavDestination(
      actionId: 'exam_results',
      label: 'Results',
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events,
    ),
  ];

  int _selectedIndex(String location) {
    if (location.startsWith(RouteNames.studentDashboard)) {
      return 0;
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
          if (destination.route != null && destination.route != path) {
            context.go(destination.route!);
            return;
          }
          if (destination.actionId != 'home') {
            handleStudentNavigation(context, destination.actionId);
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

class _StudentNavDestination {
  const _StudentNavDestination({
    required this.actionId,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.route,
  });

  final String? route;
  final String actionId;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
