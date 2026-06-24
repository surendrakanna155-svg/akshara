import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/widgets/akshara_navigation.dart';
import '../../theme/breakpoints.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../copilot/copilot_navigation.dart';
import '../copilot/settings/ai_access_preferences_provider.dart';
import '../copilot/widgets/copilot_ai_quick_actions.dart';
import '../entitlements/plan_badge.dart';
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
    final ext = context.akshara;
    final selectedIndex = _selectedIndex(destinations);
    final width = MediaQuery.sizeOf(context).width;
    final breakpoint = AksharaBreakpoints.fromWidth(width);
    final prefs = ref.watch(aiAccessPreferencesProvider);
    final showSidebarAi = shouldShowAdminSidebarAiEntry(
      prefs: prefs,
      breakpoint: breakpoint,
    );

    if (inDrawer) {
      return Material(
        color: colors.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AksharaNavBrandHeader(),
              const Align(
                alignment: Alignment.centerLeft,
                child: PlanBadge(),
              ),
              Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.65)),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final destination = destinations[index];
                    return AksharaNavRailTile(
                      key: QaTestKeys.erpNavModule(destination.module.name),
                      label: destination.label,
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      selected: index == selectedIndex,
                      onTap: () => _navigate(context, destination),
                    );
                  },
                ),
              ),
              if (showSidebarAi) _AdminSidebarAiTile(onNavigate: onDestinationSelected),
            ],
          ),
        ),
      );
    }

    final railWidth =
        expanded ? ext.navRailExpandedWidth : ext.navRailCollapsedWidth;

    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            width: railWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AksharaNavBrandHeader(
                  compact: !expanded,
                  padding: expanded
                      ? const EdgeInsets.fromLTRB(
                          AksharaSpacing.s4,
                          AksharaSpacing.s6,
                          AksharaSpacing.s4,
                          AksharaSpacing.s4,
                        )
                      : const EdgeInsets.only(top: AksharaSpacing.s6),
                ),
                if (expanded)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: PlanBadge(),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s1),
                    itemCount: destinations.length,
                    itemBuilder: (context, index) {
                      final destination = destinations[index];
                      return AksharaNavRailTile(
                        key: QaTestKeys.erpNavModule(destination.module.name),
                        label: destination.label,
                        icon: destination.icon,
                        selectedIcon: destination.selectedIcon,
                        selected: index == selectedIndex,
                        expanded: expanded,
                        onTap: () => _navigate(context, destination),
                      );
                    },
                  ),
                ),
                if (showSidebarAi)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AksharaSpacing.s4),
                    child: _AdminSidebarAiTile(
                      compact: !expanded,
                      onNavigate: onDestinationSelected,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSidebarAiTile extends ConsumerWidget {
  const _AdminSidebarAiTile({
    this.compact = false,
    this.onNavigate,
  });

  final bool compact;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: true,
      label: 'AI Assistant sidebar entry',
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AksharaSpacing.s2 : AksharaSpacing.s3,
        ),
        child: Material(
          color: colors.primaryContainer.withValues(alpha: 0.35),
          borderRadius: AksharaRadius.chip,
          child: InkWell(
            key: QaTestKeys.copilotSidebarAiEntry,
            onTap: () {
              openAiAssistantFromDock(context, ref);
              onNavigate?.call();
            },
            onLongPress: () =>
                handleCopilotAiEntryLongPress(context, ref, Offset.zero),
            borderRadius: AksharaRadius.chip,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AksharaRadius.chip,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.25),
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? AksharaSpacing.s2 : AksharaSpacing.s3,
                vertical: AksharaSpacing.s3,
              ),
              child: compact
                  ? Icon(Icons.psychology_outlined, color: colors.primary)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.psychology_outlined, color: colors.primary),
                        const SizedBox(width: AksharaSpacing.s3),
                        Text(
                          'AI Assistant',
                          style: text.labelLarge.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
