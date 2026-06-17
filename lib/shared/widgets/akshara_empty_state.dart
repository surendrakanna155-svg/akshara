import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'akshara_motion.dart';
import 'akshara_empty_illustration.dart';

/// Empty collection placeholder with optional action.
class AksharaEmptyState extends StatelessWidget {
  const AksharaEmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String message;
  final String? title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Inline section empty state vs taller centered layout.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final verticalPadding = compact ? AksharaSpacing.s4 : AksharaSpacing.s6;
    final illustrationSize = compact
        ? AksharaEmptyIllustrationSize.standard
        : AksharaEmptyIllustrationSize.prominent;
    final resolvedTitle = title ?? (compact ? null : 'Nothing here yet');

    final content = AksharaEmptyContent(
      compact: compact,
      title: resolvedTitle,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      illustration: AksharaEmptyIllustration(
        icon: icon,
        tone: AksharaEmptyTone.info,
        size: illustrationSize,
      ),
    );

    return AksharaMotionAppear(
      child: Semantics(
      container: true,
      label: resolvedTitle == null ? message : '$resolvedTitle. $message',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Center(
          child: compact
              ? content
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: AksharaEmptyPanel(
                    tone: AksharaEmptyTone.info,
                    child: content,
                  ),
                ),
        ),
      ),
      ),
    );
  }
}
