import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_glass_surface.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';

/// ST-01 hero greeting card.
class HeroGreetingCard extends StatelessWidget {
  const HeroGreetingCard({
    super.key,
    required this.headline,
    required this.subtitle,
  });

  final String headline;
  final String subtitle;

  static const double minCardHeight = 96;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      header: true,
      label: '$headline $subtitle',
      child: AksharaGlassHeroBackdrop(
        child: AksharaGlassCard(
          tintColor: colors.surfaceContainerLowest,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minCardHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headline,
                  style: text.displaySmall.copyWith(
                    color: colors.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  subtitle,
                  style: text.bodyMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
