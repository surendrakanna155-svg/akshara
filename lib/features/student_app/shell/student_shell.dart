import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/school_completion/school_branding_theme_provider.dart';
import '../../../router/route_names.dart';
import '../../../shared/navigation/persona_nav.dart';
import '../../auth/qa_visual_switcher.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/persona_accents.dart';
import '../../../theme/theme_mode_provider.dart';
import '../../copilot/widgets/bottom_nav_ai_scope.dart';

/// Student mobile shell with bottom navigation (Home · Learn · Schedule · Results).
class StudentShell extends ConsumerWidget {
  const StudentShell({
    super.key,
    required this.child,
  });

  final Widget child;

  /// ≤4 primary tabs + a shared "More" tab
  /// (Report Card, Progress, Notices, Profile).
  static const navSpec = PersonaNavSpec(
    primary: [
      PersonaNavDestination(
        route: RouteNames.studentDashboard,
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      PersonaNavDestination(
        route: RouteNames.studentHomework,
        label: 'Learn',
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book,
      ),
      PersonaNavDestination(
        route: RouteNames.studentTimetable,
        label: 'Schedule',
        icon: Icons.calendar_view_week_outlined,
        selectedIcon: Icons.calendar_view_week,
      ),
      PersonaNavDestination(
        route: RouteNames.studentExams,
        label: 'Results',
        icon: Icons.emoji_events_outlined,
        selectedIcon: Icons.emoji_events,
        matchPrefixes: [RouteNames.studentAttendance],
      ),
    ],
    more: [
      MoreNavDestination(
        route: RouteNames.studentReportCard,
        label: 'Report Card',
        icon: Icons.assignment_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.studentProgress,
        label: 'Progress',
        icon: Icons.trending_up,
      ),
      MoreNavDestination(
        route: RouteNames.studentNotices,
        label: 'Notices',
        icon: Icons.campaign_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.studentProfile,
        label: 'Profile',
        icon: Icons.person_outline,
      ),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whiteLabel = ref.watch(schoolBrandingThemeProvider);

    final themeMode = ref.watch(themeModeProvider);
    final brightness = resolveEffectiveBrightness(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );

    return Theme(
      data: AksharaAppTheme.persona(
        brightness: brightness,
        accent: AksharaPersonaAccent.student,
        whiteLabel: whiteLabel,
      ),
      // See BottomNavAiScope: lets a screen with a fixed bottom action bar
      // reserve the band the raised centre AI button occupies.
      child: BottomNavAiScope(
        reservedHeight: BottomNavAiScope.resolveHeight(context, ref),
        child: Scaffold(
          body: Column(
            children: [
              const QaPersonaSwitcherBar(),
              Expanded(child: child),
            ],
          ),
          bottomNavigationBar: const PersonaBottomNav(spec: navSpec),
        ),
      ),
    );
  }
}
