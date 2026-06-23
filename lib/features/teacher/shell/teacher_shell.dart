import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/school_completion/school_branding_theme_provider.dart';
import '../../../router/route_names.dart';
import '../../../shared/navigation/persona_nav.dart';
import '../../auth/qa_visual_switcher.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/stitch_palettes.dart';

/// Teacher mobile shell with bottom navigation (Home · Classes · Teach · Messages).
class TeacherShell extends ConsumerWidget {
  const TeacherShell({
    super.key,
    required this.child,
  });

  final Widget child;

  /// ≤4 primary tabs + a shared "More" tab (Timetable, Leave, Parent Concerns,
  /// Settings).
  static const navSpec = PersonaNavSpec(
    primary: [
      PersonaNavDestination(
        route: RouteNames.teacherDashboard,
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      PersonaNavDestination(
        route: RouteNames.teacherAttendance,
        label: 'Classes',
        icon: Icons.class_outlined,
        selectedIcon: Icons.class_,
        matchPrefixes: [RouteNames.teacherClassTeacherDashboard],
      ),
      PersonaNavDestination(
        route: RouteNames.teacherHomework,
        label: 'Teach',
        icon: Icons.edit_note_outlined,
        selectedIcon: Icons.edit_note,
        matchPrefixes: [RouteNames.teacherExams],
      ),
      PersonaNavDestination(
        route: RouteNames.teacherMessages,
        label: 'Messages',
        icon: Icons.chat_bubble_outline,
        selectedIcon: Icons.chat_bubble,
      ),
    ],
    more: [
      MoreNavDestination(
        route: RouteNames.teacherTimetable,
        label: 'Timetable',
        icon: Icons.calendar_view_week_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.teacherLeave,
        label: 'Leave',
        icon: Icons.event_busy_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.teacherParentCommunication,
        label: 'Parent Concerns',
        icon: Icons.forum_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.teacherProfile,
        label: 'Profile',
        icon: Icons.person_outline,
      ),
      MoreNavDestination(
        route: RouteNames.teacherSettings,
        label: 'Settings',
        icon: Icons.settings_outlined,
      ),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whiteLabel = ref.watch(schoolBrandingThemeProvider);

    return Theme(
      data: AksharaAppTheme.stitch(
        StitchPersonaPalette.classroomCommand,
        whiteLabel: whiteLabel,
      ),
      child: Scaffold(
      body: Column(
        children: [
          const QaPersonaSwitcherBar(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: const PersonaBottomNav(spec: navSpec),
    ),
    );
  }
}
