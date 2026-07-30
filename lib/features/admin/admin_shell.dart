import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/school_completion/school_branding_theme_provider.dart';
import '../../router/route_guards.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../theme/persona_accents.dart';
import '../../theme/theme_mode_provider.dart';
import '../auth/qa_visual_switcher.dart';
import 'admin_bottom_nav.dart';
import 'admin_navigation_rail.dart';

/// Responsive desktop/tablet/mobile shell for the web ERP admin portal.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final whiteLabel = ref.watch(schoolBrandingThemeProvider);

    final themeMode = ref.watch(themeModeProvider);
    final brightness = resolveEffectiveBrightness(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final personaTheme = AksharaAppTheme.persona(
      brightness: brightness,
      accent: AksharaPersonaAccent.admin,
      whiteLabel: whiteLabel,
    );

    return Theme(
      data: personaTheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const QaPersonaSwitcherBar(),
          Expanded(
            child: LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint =
            AksharaBreakpoints.fromWidth(constraints.maxWidth);

        return switch (breakpoint) {
          LayoutBreakpoint.mobile => Scaffold(
              key: _scaffoldKey,
              drawer: Drawer(
                width: 280,
                child: AdminNavigationRail(
                  currentLocation: location,
                  expanded: true,
                  inDrawer: true,
                  onDestinationSelected: () =>
                      _scaffoldKey.currentState?.closeDrawer(),
                ),
              ),
              body: _AdminShellBody(
                onMenuTap: _openDrawer,
                child: ErpRouteGuard(child: widget.child),
              ),
              bottomNavigationBar: AdminBottomNav(
                currentLocation: location,
                onMore: _openDrawer,
              ),
            ),
          LayoutBreakpoint.tablet => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminNavigationRail(
                  currentLocation: location,
                  expanded: false,
                ),
                Expanded(child: ErpRouteGuard(child: widget.child)),
              ],
            ),
          LayoutBreakpoint.desktop => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminNavigationRail(
                  currentLocation: location,
                  expanded: true,
                ),
                Expanded(child: ErpRouteGuard(child: widget.child)),
              ],
            ),
        };
      },
            ),
          ),
        ],
      ),
    );
  }
}

/// Injects drawer menu handler into admin content scaffolds on mobile.
class _AdminShellBody extends InheritedWidget {
  const _AdminShellBody({
    required this.onMenuTap,
    required super.child,
  });

  final VoidCallback onMenuTap;

  static VoidCallback? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AdminShellBody>()
        ?.onMenuTap;
  }

  @override
  bool updateShouldNotify(_AdminShellBody oldWidget) =>
      onMenuTap != oldWidget.onMenuTap;
}

/// Drawer menu callback injected by [AdminShell] on mobile layouts.
VoidCallback? adminShellMenuTap(BuildContext context) {
  return _AdminShellBody.maybeOf(context);
}
