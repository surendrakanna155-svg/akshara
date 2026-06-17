import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_glass_surface.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';

/// TA-01 greeting row — eyebrow date + headline (72px zone).
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.eyebrow,
    required this.headline,
  });

  final String eyebrow;
  final String headline;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      header: true,
      label: '$eyebrow. $headline',
      child: AksharaGlassHeroBackdrop(
        height: 120,
        child: AksharaGlassCard(
          tintColor: colors.surfaceContainerLowest,
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4,
            vertical: AksharaSpacing.s3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      eyebrow,
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      headline,
                      style: text.displaySmall.copyWith(
                        color: colors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
