import 'package:flutter/material.dart';

import '../../../theme/premium_tokens.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'akshara_line_art.dart';

/// A headline stat for a workspace landing hero.
class AksharaWorkspaceStat {
  const AksharaWorkspaceStat({required this.value, required this.label});

  final String value;
  final String label;
}

/// Branded workspace landing hero — establishes "you are in workspace X" with
/// personality: the workspace name on the brand gradient, a relevant line-art
/// motif, and 2–3 headline stats. Module cards are laid out by the caller below
/// this hero. Reused by every workspace (Front Office, Finance, Teacher, …).
class AksharaWorkspaceLanding extends StatelessWidget {
  const AksharaWorkspaceLanding({
    super.key,
    required this.workspaceName,
    required this.motif,
    this.eyebrow = 'WORKSPACE',
    this.stats = const [],
  });

  final String workspaceName;
  final AksharaMotif motif;
  final String eyebrow;
  final List<AksharaWorkspaceStat> stats;

  @override
  Widget build(BuildContext context) {
    final premium = context.premiumOrNull ?? AksharaPremiumTokens.light();
    final text = context.aksharaText;
    const onBrand = Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: premium.brandGradient,
        borderRadius: BorderRadius.circular(AksharaRadius.xxl),
        boxShadow: premium.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AksharaRadius.xxl),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              bottom: -22,
              child: AksharaLineArt(
                motif: motif,
                size: 176,
                color: Colors.white,
                opacity: 0.20,
                strokeWidth: 2.2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    eyebrow,
                    style: text.labelSmall.copyWith(
                      color: onBrand.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(
                    workspaceName,
                    style: text.headlineSmall.copyWith(
                      color: onBrand,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: AksharaSpacing.s4),
                    // Wrap (not Row) so stats flow to a second line on narrow
                    // phones instead of overflowing; they sit on one line on
                    // tablet/desktop widths.
                    Wrap(
                      spacing: AksharaSpacing.s6,
                      runSpacing: AksharaSpacing.s3,
                      children: [
                        for (final stat in stats) _Stat(stat: stat),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.stat});

  final AksharaWorkspaceStat stat;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    const onBrand = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.value,
          style: text.titleLarge.copyWith(
            color: onBrand,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          stat.label,
          style: text.bodySmall.copyWith(
            color: onBrand.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
