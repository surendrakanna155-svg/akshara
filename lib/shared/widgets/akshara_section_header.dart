import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Trailing link style for [AksharaSectionHeader].
enum AksharaSectionHeaderTrailingStyle {
  /// PA-01 dashboard sections — zero padding, 32px row height.
  dashboard,

  /// TA/ST section links — horizontal padding, expanded tap target.
  compact,
}

/// Section title row with optional trailing text action.
class AksharaSectionHeader extends StatelessWidget {
  const AksharaSectionHeader({
    super.key,
    required this.title,
    this.trailingLabel,
    this.onTrailingTap,
    this.fixedHeight = true,
    this.spacingBelow = 0,
    this.trailingStyle = AksharaSectionHeaderTrailingStyle.dashboard,
  });

  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  /// When true, gives the header row a 32px MINIMUM height (PA-01 dashboard
  /// sections).
  ///
  /// A11y-P1: this used to be a hard `SizedBox(height: 32)` around a 14px title
  /// whose line box is 20px. Above roughly 1.6× system font scale the text no
  /// longer fitted and was clipped — on every section title of every dashboard
  /// (243 of 297 call sites take the `fixedHeight: true` default). It is now a
  /// minimum constraint, so at the default 1.0× scale the row is still exactly
  /// 32px (pixel-identical) and only a large system font makes it grow.
  final bool fixedHeight;

  /// Optional gap rendered below the header row.
  final double spacingBelow;

  /// Trailing action tap target style (dashboard vs compact section links).
  final AksharaSectionHeaderTrailingStyle trailingStyle;

  static const double _dashboardHeaderMinHeight = 32;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    final row = Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: text.titleSmall.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (trailingLabel != null)
          TextButton(
            onPressed: onTrailingTap,
            // A11y-P1 tap target: this was 48×32 with an explicit
            // `MaterialTapTargetSize.shrinkWrap`, which cancelled the 48dp
            // floor the app theme guarantees globally
            // (`materialTapTargetSize: padded`). "See all" is the only way to
            // reach several list screens, including 3 on the parent dashboard.
            // Both styles now take the full 48×48 target; the override is gone.
            style: TextButton.styleFrom(
              padding: trailingStyle == AksharaSectionHeaderTrailingStyle.compact
                  ? const EdgeInsets.symmetric(horizontal: AksharaSpacing.s2)
                  : EdgeInsets.zero,
              minimumSize: const Size(
                AksharaSpacing.minTouchTarget,
                AksharaSpacing.minTouchTarget,
              ),
            ),
            child: Text(
              trailingLabel!,
              style: text.labelLarge.copyWith(color: colors.primary),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fixedHeight)
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: _dashboardHeaderMinHeight,
            ),
            child: row,
          )
        else
          row,
        if (spacingBelow > 0) SizedBox(height: spacingBelow),
      ],
    );
  }
}
