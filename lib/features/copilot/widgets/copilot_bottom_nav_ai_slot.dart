import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/breakpoints.dart';
import '../settings/ai_access_preferences_provider.dart';
import '../widgets/copilot_ai_entry_button.dart';
import '../widgets/copilot_ai_quick_actions.dart';

/// Center slot for mobile bottom navigation when AI access mode is bottom-nav center.
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

    return const Positioned(
      left: 0,
      right: 0,
      top: -22,
      child: Center(
        child: CopilotAiEntryButton(
          fabStyle: true,
          onTap: handleCopilotAiEntryTap,
          onLongPress: handleCopilotAiEntryLongPress,
        ),
      ),
    );
  }
}
