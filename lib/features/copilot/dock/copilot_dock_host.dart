import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'copilot_floating_dock.dart';

/// Wraps app shells with the global floating AI dock overlay.
class CopilotDockHost extends ConsumerWidget {
  const CopilotDockHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        const CopilotFloatingDock(),
      ],
    );
  }
}
