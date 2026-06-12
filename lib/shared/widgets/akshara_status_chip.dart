import 'package:flutter/material.dart';

import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Semantic chip sizes aligned with design system usage.
enum AksharaStatusChipSize {
  /// `labelMedium`, padding 12×4 — hero / detail contexts.
  standard,

  /// `labelSmall`, padding 8×2 — list rows and timelines.
  compact,
}

/// Tone-backed or custom-colored status chip.
class AksharaStatusChip extends StatelessWidget {
  const AksharaStatusChip({
    super.key,
    required this.label,
    this.tone,
    this.background,
    this.foreground,
    this.size = AksharaStatusChipSize.compact,
    this.fontWeight,
    this.semanticLabel,
  }) : assert(
          tone != null || (background != null && foreground != null),
          'Provide tone or both background and foreground colors',
        );

  final String label;
  final KpiAccent? tone;
  final Color? background;
  final Color? foreground;
  final AksharaStatusChipSize size;
  final FontWeight? fontWeight;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final (bg, fg) = _resolveColors(context);

    final padding = switch (size) {
      AksharaStatusChipSize.standard => const EdgeInsets.symmetric(
          horizontal: AksharaSpacing.s3,
          vertical: AksharaSpacing.s1,
        ),
      AksharaStatusChipSize.compact => const EdgeInsets.symmetric(
          horizontal: AksharaSpacing.s2,
          vertical: 2,
        ),
    };

    final resolvedWeight = fontWeight ??
        (size == AksharaStatusChipSize.compact
            ? FontWeight.w600
            : FontWeight.normal);
    final textStyle = switch (size) {
      AksharaStatusChipSize.standard => text.labelMedium,
      AksharaStatusChipSize.compact => text.labelSmall,
    };

    final chip = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AksharaRadius.chip,
      ),
      child: Text(
        label,
        style: textStyle.copyWith(
          color: fg,
          fontWeight: resolvedWeight,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (semanticLabel == null) return chip;

    return Semantics(label: semanticLabel, child: chip);
  }

  (Color background, Color foreground) _resolveColors(BuildContext context) {
    if (background != null && foreground != null) {
      return (background!, foreground!);
    }

    final resolved = tone!.resolve(context);
    return (resolved.container, resolved.foreground);
  }
}
