import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/copilot/widgets/copilot_bottom_nav_ai_slot.dart';
import '../../../features/school_completion/school_branding_theme_provider.dart';
import '../../../router/route_names.dart';
import '../../auth/qa_visual_switcher.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/stitch_palettes.dart';
import '../../../theme/theme_extensions.dart';

/// Student mobile shell with bottom navigation (Home · Learn · Schedule · Results).
class StudentShell extends ConsumerWidget {
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
      route: RouteNames.studentHomework,
      actionId: 'homework_list',
      label: 'Learn',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
    ),
    _StudentNavDestination(
      route: RouteNames.studentTimetable,
      actionId: 'full_schedule',
      label: 'Schedule',
      icon: Icons.calendar_view_week_outlined,
      selectedIcon: Icons.calendar_view_week,
    ),
    _StudentNavDestination(
      route: RouteNames.studentExams,
      actionId: 'exam_results',
      label: 'Results',
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events,
    ),
  ];

  int _selectedIndex(String location) {
    if (location.startsWith(RouteNames.studentHomework)) {
      return 1;
    }
    if (location.startsWith(RouteNames.studentTimetable)) {
      return 2;
    }
    if (location.startsWith(RouteNames.studentExams) ||
        location.startsWith(RouteNames.studentAttendance)) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(path);
    final whiteLabel = ref.watch(schoolBrandingThemeProvider);

    return Theme(
      data: AksharaAppTheme.stitch(
        StitchPersonaPalette.studentPulse,
        whiteLabel: whiteLabel,
      ),
      child: Scaffold(
      body: Column(
        children: [
          const QaPersonaSwitcherBar(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          NavigationBar(
            height: context.akshara.bottomNavHeight,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              final destination = _destinations[index];
              if (destination.route != null && destination.route != path) {
                context.go(destination.route!);
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
          const CopilotBottomNavAiSlot(),
        ],
      ),
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
