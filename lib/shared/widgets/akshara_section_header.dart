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

  /// When true, wraps content in a 32px-tall row (PA-01 dashboard sections).
  final bool fixedHeight;

  /// Optional gap rendered below the header row.
  final double spacingBelow;

  /// Trailing action tap target style (dashboard vs compact section links).
  final AksharaSectionHeaderTrailingStyle trailingStyle;

  static const double _dashboardHeaderHeight = 32;

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
            style: TextButton.styleFrom(
              padding: trailingStyle == AksharaSectionHeaderTrailingStyle.compact
                  ? const EdgeInsets.symmetric(horizontal: AksharaSpacing.s2)
                  : EdgeInsets.zero,
              minimumSize: Size(
                AksharaSpacing.minTouchTarget,
                trailingStyle == AksharaSectionHeaderTrailingStyle.compact
                    ? AksharaSpacing.minTouchTarget
                    : 32,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          SizedBox(height: _dashboardHeaderHeight, child: row)
        else
          row,
        if (spacingBelow > 0) SizedBox(height: spacingBelow),
      ],
    );
  }
}
