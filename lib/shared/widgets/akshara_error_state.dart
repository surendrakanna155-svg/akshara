import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Recoverable error placeholder with optional retry action.
class AksharaErrorState extends StatelessWidget {
  const AksharaErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.retryLabel = 'Try again',
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Error: $message',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: colors.error,
              ),
              const SizedBox(height: AksharaSpacing.s3),
              Text(
                message,
                style: text.bodyLarge.copyWith(color: colors.onSurface),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AksharaSpacing.s4),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
