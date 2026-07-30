import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/layout/bottom_chrome_scope.dart';
import 'copilot_floating_dock.dart';

/// Wraps app shells with the global floating AI dock overlay.
///
/// The dock is a *sibling* of the shell, not a descendant, so it cannot see the
/// shell's `Scaffold.bottomNavigationBar`. [BottomChromeScope] is hosted here —
/// the nearest common ancestor of both — so the nav bar can publish its real
/// height and the dock can sit clear of it instead of inferring the inset from
/// a width tier. Every shell this host wraps, present and future, inherits that
/// without a per-shell patch.
class CopilotDockHost extends ConsumerWidget {
  const CopilotDockHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomChromeScope(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          const CopilotFloatingDock(),
        ],
      ),
    );
  }
}
