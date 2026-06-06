import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../router/teacher_navigation.dart';
import '../../../theme/theme_extensions.dart';

/// Teacher mobile shell with bottom navigation (Home · Classes · Teach · Messages).
class TeacherShell extends StatelessWidget {
  const TeacherShell({
    super.key,
    required this.child,
  });

  final Widget child;

  static const _destinations = <_TeacherNavDestination>[
    _TeacherNavDestination(
      route: RouteNames.teacherDashboard,
      actionId: 'home',
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _TeacherNavDestination(
      actionId: 'mark_attendance',
      label: 'Classes',
      icon: Icons.class_outlined,
      selectedIcon: Icons.class_,
    ),
    _TeacherNavDestination(
      actionId: 'create_homework',
      label: 'Teach',
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note,
    ),
    _TeacherNavDestination(
      actionId: 'messages',
      label: 'Messages',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
    ),
  ];

  int _selectedIndex(String location) {
    if (location.startsWith(RouteNames.teacherDashboard)) {
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
          if (destination.route != null &&
              destination.route != path) {
            context.go(destination.route!);
            return;
          }
          if (destination.actionId != 'home') {
            handleTeacherNavigation(context, destination.actionId);
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

class _TeacherNavDestination {
  const _TeacherNavDestination({
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
