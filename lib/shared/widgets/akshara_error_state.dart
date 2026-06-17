import 'package:flutter/material.dart';

import '../../core/errors/api_failure.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import 'akshara_empty_illustration.dart';
import 'akshara_motion.dart';

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
    this.compact = false,
  });

  /// Builds a user-friendly error from a standardized [ApiFailure].
  factory AksharaErrorState.fromFailure(
    ApiFailure failure, {
    Key? key,
    VoidCallback? onRetry,
    IconData? icon,
    String retryLabel = 'Try again',
    bool compact = false,
  }) {
    return AksharaErrorState(
      key: key,
      message: failure.displayMessage,
      errorCode: failure.displayCode,
      onRetry: failure.isRetryable ? onRetry : null,
      icon: icon ?? _iconForFailure(failure.type),
      retryLabel: retryLabel,
      failure: failure,
      compact: compact,
    );
  }

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String retryLabel;
  final String? errorCode;
  final ApiFailure? failure;
  final bool compact;

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

    final content = AksharaEmptyContent(
      compact: compact,
      title: compact ? null : 'Something went wrong',
      message: message,
      actionLabel: onRetry != null ? retryLabel : null,
      onAction: onRetry,
      illustration: AksharaEmptyIllustration(
        icon: icon,
        tone: AksharaEmptyTone.error,
        size: compact
            ? AksharaEmptyIllustrationSize.standard
            : AksharaEmptyIllustrationSize.prominent,
      ),
    );

    return AksharaMotionAppear(
      child: Semantics(
      container: true,
      label: semanticLabel,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? AksharaSpacing.s4 : AksharaSpacing.s6),
          child: compact
              ? content
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: AksharaEmptyPanel(
                    tone: AksharaEmptyTone.error,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        content,
                        if (errorCode != null) ...[
                          const SizedBox(height: AksharaSpacing.s2),
                          Text(
                            'Error code: $errorCode',
                            style: text.bodySmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
      ),
    );
  }
}
