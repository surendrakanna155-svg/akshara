import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/breakpoints.dart';
import '../settings/ai_access_preferences_provider.dart';

/// Diameter of the raised centre AI button in the bottom nav.
///
/// Public so a screen reserves exactly the band the button occupies, rather
/// than a magic number that later drifts from the button's real size.
const double kBottomNavAiFabDiameter = 56;

/// Publishes, to everything below a persona/admin shell, how much vertical
/// space a fixed bottom action bar must reserve so the raised centre AI button
/// cannot cover it.
///
/// Why this exists: `CopilotBottomNavAiSlot` is positioned `top: -diameter`, so
/// it occupies the 56dp band directly ABOVE the navigation bar, horizontally
/// centred. That placement is deliberate (UXR-G2) — it keeps the button clear
/// of every nav destination's tap target. But a screen with its OWN fixed
/// bottom action bar paints into that same band, and the AI button, painted
/// later in the shell's Stack, lands on top of it. Observed on Mark Attendance
/// covering part of the "Save draft / N unmarked" submit row: not cosmetic, a
/// real mistap hazard on the app's most-used data-entry flow.
///
/// The resolution is that those screens reserve the band — the AI button does
/// NOT move or hide. A scope is used rather than reading the AI preference
/// directly at each screen because the preference alone cannot distinguish
/// "inside a shell, button is drawn" from "pushed full-screen above the shell,
/// no bottom nav at all". Padding the second case would add dead space for a
/// button that is not there.
///
/// The shell resolves the height once (it is the widget that owns both the body
/// and the nav, and has a `WidgetRef`), so consumers need only a BuildContext.
class BottomNavAiScope extends InheritedWidget {
  const BottomNavAiScope({
    super.key,
    required this.reservedHeight,
    required super.child,
  });

  /// Height to reserve. Zero when no raised AI button is drawn for this
  /// user/breakpoint, so the padding costs nothing when it is not needed.
  final double reservedHeight;

  /// Space a fixed bottom action bar should add beneath itself. Returns 0
  /// outside a shell — a full-screen route has no bottom nav and therefore
  /// nothing to avoid.
  static double reservedHeightOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BottomNavAiScope>()
          ?.reservedHeight ??
      0;

  /// Resolves the height for the current user preference and breakpoint.
  /// Called by the shell; not intended for screens.
  static double resolveHeight(BuildContext context, WidgetRef ref) {
    final breakpoint =
        AksharaBreakpoints.fromWidth(MediaQuery.sizeOf(context).width);
    final prefs = ref.watch(aiAccessPreferencesProvider);
    return shouldShowBottomNavAiEntry(prefs: prefs, breakpoint: breakpoint)
        ? kBottomNavAiFabDiameter
        : 0;
  }

  @override
  bool updateShouldNotify(BottomNavAiScope oldWidget) =>
      oldWidget.reservedHeight != reservedHeight;
}
