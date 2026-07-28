import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/school_completion/school_branding_theme_provider.dart';
import '../../../router/route_names.dart';
import '../../../shared/navigation/persona_nav.dart';
import '../../auth/qa_visual_switcher.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/persona_accents.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../../theme/theme_mode_provider.dart';
import '../../copilot/widgets/bottom_nav_ai_scope.dart';

/// Parent mobile shell with bottom navigation
/// (Home · Academics · Fees · Messages · More).
class ParentShell extends ConsumerWidget {
  const ParentShell({
    super.key,
    required this.child,
  });

  final Widget child;

  /// ≤4 primary tabs + a "More" tab. Secondary screens that previously had no
  /// visible entry point (Leave, Notices, Events, PTM, Transport, Profile) now
  /// live in the "More" sheet instead of being silently folded into Home.
  static const navSpec = PersonaNavSpec(
    primary: [
      PersonaNavDestination(
        route: RouteNames.parentDashboard,
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      PersonaNavDestination(
        route: RouteNames.parentAttendance,
        label: 'Academics',
        icon: Icons.school_outlined,
        selectedIcon: Icons.school,
        matchPrefixes: [
          RouteNames.parentTimetable,
          RouteNames.parentHomework,
          RouteNames.parentExams,
        ],
      ),
      PersonaNavDestination(
        route: RouteNames.parentFees,
        label: 'Fees',
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments,
        matchPrefixes: [
          RouteNames.parentPayment,
          RouteNames.parentReceipts,
        ],
      ),
      PersonaNavDestination(
        route: RouteNames.parentMessages,
        label: 'Messages',
        icon: Icons.chat_bubble_outline,
        selectedIcon: Icons.chat_bubble,
      ),
    ],
    more: [
      MoreNavDestination(
        route: RouteNames.parentActionInbox,
        label: 'Action Needed',
        icon: Icons.checklist_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.parentFamily,
        label: 'My Children',
        icon: Icons.family_restroom_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.parentInsights,
        label: 'Insights',
        icon: Icons.auto_awesome_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.parentLeave,
        label: 'Leave',
        icon: Icons.event_busy_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.parentNotices,
        label: 'Notices',
        icon: Icons.campaign_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.parentEvents,
        label: 'Events',
        icon: Icons.celebration_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.parentPtm,
        label: 'PTM',
        icon: Icons.groups_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.parentTransport,
        label: 'Transport',
        icon: Icons.directions_bus_outlined,
      ),
      MoreNavDestination(
        route: RouteNames.parentProfile,
        label: 'Profile',
        icon: Icons.person_outline,
      ),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolName = ref.watch(schoolDisplayNameProvider);

    final whiteLabel = ref.watch(schoolBrandingThemeProvider);

    final themeMode = ref.watch(themeModeProvider);
    final brightness = resolveEffectiveBrightness(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );

    return Theme(
      data: AksharaAppTheme.persona(
        brightness: brightness,
        accent: AksharaPersonaAccent.parent,
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
          if (schoolName.isNotEmpty)
            Material(
              color: context.colors.surface,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.colors.outlineVariant.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AksharaSpacing.s4,
                      vertical: AksharaSpacing.s2,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: context.colors.primaryContainer,
                            borderRadius: AksharaRadius.chip,
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            size: 16,
                            color: context.colors.primary,
                          ),
                        ),
                        const SizedBox(width: AksharaSpacing.s2),
                        Expanded(
                          child: Text(
                            schoolName,
                            style: context.aksharaText.labelLarge.copyWith(
                              color: context.colors.onSurface,
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
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: const PersonaBottomNav(spec: navSpec),
    ),
    ),
    );
  }
}
