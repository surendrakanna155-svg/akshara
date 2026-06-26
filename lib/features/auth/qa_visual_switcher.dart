import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/environment_provider.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'auth_provider.dart';

/// Clears session and returns to [QaLoginScreen] (visual QA / emulator builds).
Future<void> switchQaPersona(BuildContext context, WidgetRef ref) async {
  await ref.read(authProvider.notifier).logout();
  if (!context.mounted) {
    return;
  }
  context.go(RouteNames.qaLogin);
}

/// Compact strip for QA builds — switch persona without hunting for logout.
class QaPersonaSwitcherBar extends ConsumerWidget {
  const QaPersonaSwitcherBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isQaLoginEnabledProvider)) {
      return const SizedBox.shrink();
    }

    return Material(
      key: QaTestKeys.qaPersonaSwitcherBar,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.85),
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => switchQaPersona(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s4,
              vertical: AksharaSpacing.s2,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: AksharaSpacing.s2),
                Expanded(
                  child: Text(
                    'QA visual test — tap to switch persona',
                    style: context.aksharaText.labelMedium.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
