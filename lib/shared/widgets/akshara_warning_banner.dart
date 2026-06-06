import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Warning feedback banner (PA-02 · 56px height).
class AksharaWarningBanner extends StatelessWidget {
  const AksharaWarningBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.height = 56,
    this.borderRadius,
    this.compactMessage = false,
    this.horizontalPaddingOnly = false,
    this.semanticLabel,
    this.alwaysShowAction = false,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double height;
  final BorderRadius? borderRadius;
  final bool compactMessage;
  final bool horizontalPaddingOnly;
  final String? semanticLabel;
  final bool alwaysShowAction;

  @override
  Widget build(BuildContext context) {
    final ext = context.akshara;
    final text = context.aksharaText;
    final colors = context.colors;

    final messageStyle = compactMessage
        ? text.bodySmall.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w500,
          )
        : text.bodyMedium.copyWith(color: colors.onSurface);

    final padding = horizontalPaddingOnly
        ? const EdgeInsets.symmetric(horizontal: AksharaSpacing.s4)
        : const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4,
            vertical: AksharaSpacing.s3,
          );

    final showAction = alwaysShowAction
        ? actionLabel != null
        : actionLabel != null && onAction != null;

    final resolvedRadius = borderRadius ?? AksharaRadius.chip;

    final banner = Material(
      color: ext.warningContainer,
      borderRadius: resolvedRadius,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: ext.warning,
                size: 20,
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Text(
                  message,
                  style: messageStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showAction)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AksharaSpacing.s2,
                    ),
                    minimumSize: const Size(
                      AksharaSpacing.minTouchTarget,
                      AksharaSpacing.minTouchTarget,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );

    if (semanticLabel == null) return banner;

    return Semantics(
      container: true,
      label: semanticLabel,
      child: banner,
    );
  }
}
