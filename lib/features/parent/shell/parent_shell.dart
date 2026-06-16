import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/copilot/widgets/copilot_bottom_nav_ai_slot.dart';
import '../../../features/school_completion/school_branding_theme_provider.dart';
import '../../../router/route_names.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';

/// Parent mobile shell with bottom navigation (Home · Attendance · Fees).
class ParentShell extends ConsumerWidget {
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
    if (location.startsWith(RouteNames.parentAttendance) ||
        location.startsWith(RouteNames.parentTimetable) ||
        location.startsWith(RouteNames.parentHomework) ||
        location.startsWith(RouteNames.parentExams)) {
      return 1;
    }
    if (location.startsWith(RouteNames.parentFees) ||
        location.startsWith(RouteNames.parentPayment) ||
        location.startsWith(RouteNames.parentReceipts)) {
      return 2;
    }
    if (location.startsWith(RouteNames.parentLeave)) {
      return 0;
    }
    if (location.startsWith(RouteNames.parentNotices) ||
        location.startsWith(RouteNames.parentEvents) ||
        location.startsWith(RouteNames.parentProfile) ||
        location.startsWith(RouteNames.parentMessages) ||
        location.startsWith(RouteNames.parentTransport) ||
        location.startsWith(RouteNames.parentPtm)) {
      return 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(path);
    final schoolName = ref.watch(schoolDisplayNameProvider);

    return Scaffold(
      body: Column(
        children: [
          if (schoolName.isNotEmpty)
            Material(
              color: context.colors.primaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AksharaSpacing.s4,
                    vertical: AksharaSpacing.s2,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.school, size: 18, color: context.colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          schoolName,
                          style: context.aksharaText.labelLarge.copyWith(
                            color: context.colors.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
          const CopilotBottomNavAiSlot(),
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
