import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Semantic tone for empty / status illustrations.
enum AksharaEmptyTone {
  neutral,
  info,
  error,
  warning,
}

/// Illustration footprint for empty states.
enum AksharaEmptyIllustrationSize {
  compact,
  standard,
  prominent,
}

/// Shared icon badge for empty, error, and chart placeholder states.
class AksharaEmptyIllustration extends StatelessWidget {
  const AksharaEmptyIllustration({
    super.key,
    required this.icon,
    this.tone = AksharaEmptyTone.neutral,
    this.size = AksharaEmptyIllustrationSize.standard,
  });

  final IconData icon;
  final AksharaEmptyTone tone;
  final AksharaEmptyIllustrationSize size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ext = context.akshara;
    final palette = _palette(colors, ext, tone);

    final dimension = switch (size) {
      AksharaEmptyIllustrationSize.compact => 32.0,
      AksharaEmptyIllustrationSize.standard => 56.0,
      AksharaEmptyIllustrationSize.prominent => 72.0,
    };
    final iconSize = switch (size) {
      AksharaEmptyIllustrationSize.compact => 18.0,
      AksharaEmptyIllustrationSize.standard => 28.0,
      AksharaEmptyIllustrationSize.prominent => 34.0,
    };

    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.container,
        border: Border.all(
          color: palette.border.withValues(alpha: 0.75),
        ),
        boxShadow: size == AksharaEmptyIllustrationSize.compact
            ? null
            : [
                BoxShadow(
                  color: palette.foreground.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Icon(icon, size: iconSize, color: palette.foreground),
    );
  }

  static ({Color container, Color foreground, Color border}) _palette(
    ColorScheme colors,
    AksharaThemeExtension ext,
    AksharaEmptyTone tone,
  ) {
    return switch (tone) {
      AksharaEmptyTone.neutral => (
          container: colors.surfaceContainerLow,
          foreground: colors.onSurfaceVariant,
          border: colors.outlineVariant,
        ),
      AksharaEmptyTone.info => (
          container: colors.primaryContainer.withValues(alpha: 0.55),
          foreground: colors.primary,
          border: colors.primary.withValues(alpha: 0.25),
        ),
      AksharaEmptyTone.error => (
          container: colors.errorContainer.withValues(alpha: 0.65),
          foreground: colors.error,
          border: colors.error.withValues(alpha: 0.25),
        ),
      AksharaEmptyTone.warning => (
          container: ext.warningContainer.withValues(alpha: 0.65),
          foreground: ext.warning,
          border: ext.warning.withValues(alpha: 0.25),
        ),
    };
  }
}

/// Title, message, and optional CTA column for empty zones.
class AksharaEmptyContent extends StatelessWidget {
  const AksharaEmptyContent({
    super.key,
    required this.illustration,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.align = TextAlign.center,
  });

  final Widget illustration;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    final titleStyle = compact ? text.titleSmall : text.titleMedium;
    final messageStyle = compact ? text.bodyMedium : text.bodyLarge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        illustration,
        SizedBox(height: compact ? AksharaSpacing.s2 : AksharaSpacing.s4),
        if (title != null) ...[
          Text(
            title!,
            style: titleStyle.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: align,
          ),
          const SizedBox(height: AksharaSpacing.s1),
        ],
        Text(
          message,
          style: messageStyle.copyWith(color: colors.onSurfaceVariant),
          textAlign: align,
          maxLines: compact ? 2 : 4,
          overflow: TextOverflow.ellipsis,
        ),
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: compact ? AksharaSpacing.s2 : AksharaSpacing.s4),
          if (compact)
            TextButton(onPressed: onAction, child: Text(actionLabel!))
          else
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

/// Soft surface panel for full-page empty and error states.
class AksharaEmptyPanel extends StatelessWidget {
  const AksharaEmptyPanel({
    super.key,
    required this.child,
    this.tone = AksharaEmptyTone.neutral,
  });

  final Widget child;
  final AksharaEmptyTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ext = context.akshara;
    final tint = switch (tone) {
      AksharaEmptyTone.neutral => colors.surfaceContainerLow,
      AksharaEmptyTone.info => colors.primaryContainer,
      AksharaEmptyTone.error => colors.errorContainer,
      AksharaEmptyTone.warning => ext.warningContainer,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AksharaRadius.xl),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AksharaSpacing.s6,
          vertical: AksharaSpacing.s5,
        ),
        child: child,
      ),
    );
  }
}
