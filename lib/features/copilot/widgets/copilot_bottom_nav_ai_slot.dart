import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/breakpoints.dart';
import '../settings/ai_access_preferences_provider.dart';
import '../widgets/copilot_ai_entry_button.dart';
import '../widgets/copilot_ai_quick_actions.dart';

/// Diameter of the raised bottom-nav AI button.
const double _kBottomNavAiFabDiameter = 56;

/// Center slot for mobile bottom navigation when AI access mode is bottom-nav center.
///
/// UXR-G2 (P0): the AI affordance used to sit at `top: -22`, i.e. it dipped
/// ~34px down into the 80px [NavigationBar] and — being painted last in the
/// shell's [Stack] — was hit-tested *in front of* the centre primary
/// destination (parent Fees / teacher Teach / student Schedule). Tapping that
/// tab hit the AI button instead, so a primary navigation destination was
/// unreachable and its icon was painted over.
///
/// The button is now docked so its bottom edge rests on the bar's top edge
/// (`top: -diameter`): it stays a prominent, always-available centre affordance
/// (Goal B) but its hit region no longer overlaps the destination row, so every
/// primary tab's full icon/label tap zone is free and routes correctly (Goal A).
/// The persona-nav ≤4-primary + More contract and 48dp targets are untouched —
/// the AI is not a nav destination, just a raised sibling in the [Stack].
class CopilotBottomNavAiSlot extends ConsumerWidget {
  const CopilotBottomNavAiSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final breakpoint = AksharaBreakpoints.fromWidth(width);
    final prefs = ref.watch(aiAccessPreferencesProvider);
    if (!shouldShowBottomNavAiEntry(prefs: prefs, breakpoint: breakpoint)) {
      return const SizedBox.shrink();
    }

    // Raise the button clear of the bar. Its bottom edge sits on the bar's top
    // edge, so the button occupies only the space *above* the destinations and
    // can never intercept a nav-tab tap.
    return const Positioned(
      left: 0,
      right: 0,
      top: -_kBottomNavAiFabDiameter,
      child: Center(
        child: CopilotAiEntryButton(
          size: _kBottomNavAiFabDiameter,
          fabStyle: true,
          onTap: handleCopilotAiEntryTap,
          onLongPress: handleCopilotAiEntryLongPress,
        ),
      ),
    );
  }
}
