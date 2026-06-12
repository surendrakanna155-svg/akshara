import 'package:flutter/material.dart';

import '../../../../theme/elevation.dart';
import '../../../../theme/radius.dart';
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
      child: Card(
        elevation: AksharaElevation.level1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AksharaRadius.card),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minCardHeight),
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headline,
                  style: text.headlineSmall.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
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
