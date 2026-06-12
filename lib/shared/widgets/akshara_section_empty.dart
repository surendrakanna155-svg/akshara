import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Compact empty state for dashboard subsections (not full-screen).
class AksharaSectionEmpty extends StatelessWidget {
  const AksharaSectionEmpty({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: message,
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AksharaSpacing.s2),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4,
            vertical: AksharaSpacing.s3,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.onSurfaceVariant),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Text(
                  message,
                  style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact error row for subsection failures.
class AksharaSectionError extends StatelessWidget {
  const AksharaSectionError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AksharaSectionEmpty(
      message: message,
      icon: Icons.error_outline,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

/// Truncates long labels for narrow KPI tiles and chips.
String truncateStressLabel(String value, {int maxChars = 14}) {
  final trimmed = value.trim();
  if (trimmed.length <= maxChars) return trimmed;
  return '${trimmed.substring(0, maxChars - 1)}…';
}
