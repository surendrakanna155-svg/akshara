import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/school_build_scope.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../core/workspace/workspace_providers.dart';
import '../../features/copilot/widgets/copilot_bottom_nav_ai_slot.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../layout/bottom_chrome_scope.dart';
import '../widgets/workspace_switcher.dart' show WorkspaceSwitcher;

/// A primary bottom-nav tab for a persona shell.
///
/// [matchPrefixes] lists extra route prefixes (beyond [route]) that should also
/// light up this tab — e.g. the teacher "Teach" tab covers both homework and
/// exams. Keeping the mapping on the destination removes the per-shell
/// `_selectedIndex` ladders that used to drift out of sync with the tab list.
class PersonaNavDestination {
  const PersonaNavDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.matchPrefixes = const <String>[],
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final List<String> matchPrefixes;

  bool matches(String location) {
    if (location.startsWith(route)) return true;
    for (final prefix in matchPrefixes) {
      if (location.startsWith(prefix)) return true;
    }
    return false;
  }
}

/// A secondary destination, reachable from the "More" sheet rather than a
/// primary tab. This is what un-buries screens that previously had no visible
/// entry point (e.g. the parent's Notices / Leave / Transport / PTM).
class MoreNavDestination {
  const MoreNavDestination({
    required this.route,
    required this.label,
    required this.icon,
  });

  final String route;
  final String label;
  final IconData icon;
}

/// The full navigation contract for a persona shell: at most 4 primary tabs
/// (the 5th slot is always the shared "More" tab) plus the overflow
/// destinations the "More" sheet exposes. Keep [primary] at 4 or fewer so the
/// 5th slot stays "More" — enforced by `persona_nav_test.dart`.
class PersonaNavSpec {
  const PersonaNavSpec({
    required this.primary,
    required this.more,
  });

  final List<PersonaNavDestination> primary;
  final List<MoreNavDestination> more;
}

/// Shared bottom navigation used by the teacher / student / parent shells.
/// Renders the primary tabs + a trailing "More" tab (which opens [MoreNavSheet])
/// and keeps the floating AI slot. Single source of truth for the bottom-nav
/// chrome so the three shells can't drift apart again.
class PersonaBottomNav extends ConsumerWidget {
  const PersonaBottomNav({super.key, required this.spec});

  final PersonaNavSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(location);

    // Publish the bar's real height so a sibling overlay (the floating AI dock)
    // sits clear of it at EVERY width. These shells have no tablet branch —
    // they paint this bar on tablets too — which is why an overlay that guessed
    // "phones only" from a breakpoint landed inside the bar on a tablet.
    return BottomChromeReporter(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          NavigationBar(
            height: context.akshara.bottomNavHeight,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              if (index == spec.primary.length) {
                _openMoreSheet(context, location);
                return;
              }
              final destination = spec.primary[index];
              if (!location.startsWith(destination.route)) {
                context.go(destination.route);
              }
            },
            destinations: [
              for (final d in spec.primary)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
              const NavigationDestination(
                key: QaTestKeys.moreNavTab,
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'More',
              ),
            ],
          ),
          const CopilotBottomNavAiSlot(),
        ],
      ),
    );
  }

  /// Index of the highlighted tab. A location that belongs to a "More"
  /// destination lights up the More tab (last slot) instead of falling through
  /// to Home — the bug the old per-shell ladders had with hidden routes.
  int _selectedIndex(String location) {
    for (var i = 0; i < spec.primary.length; i++) {
      if (spec.primary[i].matches(location)) return i;
    }
    for (final m in spec.more) {
      if (location.startsWith(m.route)) return spec.primary.length;
    }
    return 0;
  }

  void _openMoreSheet(BuildContext context, String location) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) =>
          MoreNavSheet(spec: spec, currentLocation: location),
    );
  }
}

/// Widest a "More" tile is allowed to get. Chosen so the phone layout is
/// unchanged — 3 columns at every phone width (350dp of content at 390dp,
/// 388dp at 428dp) — while wider surfaces add columns instead of inflating the
/// tile. See [MoreNavSheet].
const double _moreTileMaxExtent = 140;

/// Premium "More" overflow sheet. Surfaces the workspace switcher (for multi-hat
/// users — discoverability decision in UX Batch 2) above a grid of the persona's
/// secondary destinations.
class MoreNavSheet extends ConsumerWidget {
  const MoreNavSheet({
    super.key,
    required this.spec,
    required this.currentLocation,
  });

  final PersonaNavSpec spec;
  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;
    final hasMultipleWorkspaces =
        ref.watch(userWorkspacesProvider).length > 1;

    return SafeArea(
      child: SingleChildScrollView(
        key: QaTestKeys.moreNavSheet,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AksharaSpacing.s5,
            AksharaSpacing.s2,
            AksharaSpacing.s5,
            AksharaSpacing.s5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More',
                style: text.titleLarge.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              // Auto-hides itself for single-workspace users; gate the trailing
              // divider on the same condition so there's no empty gap.
              const WorkspaceSwitcher(),
              if (hasMultipleWorkspaces) ...[
                const SizedBox(height: AksharaSpacing.s4),
                Divider(
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                  height: 1,
                ),
                const SizedBox(height: AksharaSpacing.s4),
              ],
              // Tile-sized, not column-counted. A fixed `crossAxisCount: 3`
              // reads correctly on a phone but has no tablet behaviour: on a
              // tablet the sheet widens to its 640dp cap, which stretched each
              // tile to ~192dp wide and ~209dp tall around a 44dp icon — three
              // columns of near-empty slabs with the label stranded under a
              // large gap. Capping the tile EXTENT keeps a phone-sized,
              // phone-proportioned tile and simply lays out more per row as the
              // surface grows: 3 columns at 390/428dp (byte-identical to the
              // old grid), 4 on a tablet.
              GridView.extent(
                maxCrossAxisExtent: _moreTileMaxExtent,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AksharaSpacing.s3,
                crossAxisSpacing: AksharaSpacing.s3,
                childAspectRatio: 0.92,
                children: [
                  // Hide-first: drop scope-hidden destinations so the More sheet
                  // never advertises a screen its route guard would bounce to
                  // Access Denied (e.g. parent PTM, gated OFF via SchoolBuildScope
                  // until its backend ships). Same predicate the routes and the
                  // primary/sub-nav filters use (route_guards / HostelSubNav /
                  // adminNavDestinationsProvider) — the tile and the route agree.
                  for (final d in spec.more)
                    if (!SchoolBuildScope.isRouteHidden(d.route))
                      _MoreTile(
                        destination: d,
                        selected: currentLocation.startsWith(d.route),
                        onTap: () {
                          Navigator.of(context).pop();
                          if (!currentLocation.startsWith(d.route)) {
                            context.go(d.route);
                          }
                        },
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final MoreNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Material(
      key: QaTestKeys.moreNavSheetItem(destination.label),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AksharaRadius.card,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AksharaSpacing.s3,
            horizontal: AksharaSpacing.s2,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.5)
                : colors.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: AksharaRadius.card,
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.4)
                  : colors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: AksharaRadius.chip,
                ),
                child: Icon(
                  destination.icon,
                  size: 22,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                destination.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
