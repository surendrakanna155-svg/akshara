import 'package:flutter/material.dart';

import '../../core/errors/api_failure.dart';
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
    this.errorCode,
    this.failure,
  });

  /// Builds a user-friendly error from a standardized [ApiFailure].
  factory AksharaErrorState.fromFailure(
    ApiFailure failure, {
    Key? key,
    VoidCallback? onRetry,
    IconData? icon,
    String retryLabel = 'Try again',
  }) {
    return AksharaErrorState(
      key: key,
      message: failure.displayMessage,
      errorCode: failure.displayCode,
      onRetry: failure.isRetryable ? onRetry : null,
      icon: icon ?? _iconForFailure(failure.type),
      retryLabel: retryLabel,
      failure: failure,
    );
  }

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String retryLabel;

  /// Optional machine-readable error code (e.g. `NETWORK`, `FORBIDDEN`).
  final String? errorCode;

  /// Source failure when created via [AksharaErrorState.fromFailure].
  final ApiFailure? failure;

  static IconData _iconForFailure(ApiFailureType type) => switch (type) {
        ApiFailureType.network || ApiFailureType.timeout => Icons.wifi_off,
        ApiFailureType.unauthorized => Icons.lock_clock_outlined,
        ApiFailureType.forbidden => Icons.lock_outline,
        ApiFailureType.server => Icons.cloud_off_outlined,
        ApiFailureType.notConnected => Icons.link_off,
        ApiFailureType.unknown => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    final semanticLabel = errorCode != null
        ? 'Error $errorCode: $message'
        : 'Error: $message';

    return Semantics(
      container: true,
      label: semanticLabel,
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
              if (errorCode != null) ...[
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  'Error code: $errorCode',
                  style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
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
