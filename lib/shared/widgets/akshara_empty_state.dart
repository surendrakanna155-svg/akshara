import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Empty collection placeholder with optional action.
class AksharaEmptyState extends StatelessWidget {
  const AksharaEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Inline section empty state vs taller centered layout.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final iconSize = compact ? 32.0 : 48.0;
    final verticalPadding = compact ? AksharaSpacing.s4 : AksharaSpacing.s6;

    return Semantics(
      container: true,
      label: message,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              SizedBox(height: compact ? AksharaSpacing.s2 : AksharaSpacing.s3),
              Text(
                message,
                style: (compact ? text.bodyMedium : text.titleSmall).copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AksharaSpacing.s3),
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
