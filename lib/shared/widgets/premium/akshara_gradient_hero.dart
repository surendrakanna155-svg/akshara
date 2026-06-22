import 'package:flutter/material.dart';

import '../../../theme/premium_tokens.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'akshara_line_art.dart';

/// A premium status pill (label + tone dot) for the greeting hero.
class AksharaHeroPill {
  const AksharaHeroPill({required this.label, required this.tone});

  final String label;
  final KpiAccent tone;
}

/// Greeting-hero card — the signature top surface of every premium dashboard.
///
/// Soft brand-tinted gradient + a faint line-art motif + an eyebrow, a big
/// headline, and optional status pills. Mobile-first. Pass a [trailing] for a
/// school logo / avatar.
class AksharaGradientHero extends StatelessWidget {
  const AksharaGradientHero({
    super.key,
    required this.eyebrow,
    required this.headline,
    this.pills = const [],
    this.motif = AksharaMotif.graduationCap,
    this.trailing,
    this.semanticLabel,
  });

  final String eyebrow;
  final String headline;
  final List<AksharaHeroPill> pills;
  final AksharaMotif motif;
  final Widget? trailing;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final premium = context.premiumOrNull ?? AksharaPremiumTokens.light();
    final text = context.aksharaText;
    final onHero = premium.onHero;

    return Semantics(
      container: true,
      label: semanticLabel ?? '$eyebrow. $headline',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: premium.heroGradient,
          ),
          borderRadius: BorderRadius.circular(AksharaRadius.xxl),
          border: Border.all(color: premium.premiumBorder),
          boxShadow: premium.softShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AksharaRadius.xxl),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -14,
                child: AksharaLineArt(
                  motif: motif,
                  size: 168,
                  opacity: premium.heroMotifOpacity,
                  strokeWidth: 2.2,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eyebrow,
                                style: text.bodySmall.copyWith(
                                  color: onHero.withValues(alpha: 0.66),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AksharaSpacing.s1),
                              Text(
                                headline,
                                style: text.headlineSmall.copyWith(
                                  color: onHero,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  height: 1.12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: AksharaSpacing.s3),
                          trailing!,
                        ],
                      ],
                    ),
                    if (pills.isNotEmpty) ...[
                      const SizedBox(height: AksharaSpacing.s4),
                      LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: AksharaSpacing.s2,
                          runSpacing: AksharaSpacing.s2,
                          children: [
                            for (final pill in pills)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth,
                                ),
                                child: _HeroPill(pill: pill),
                              ),
                          ],
                        ),
                      ),
                    ],
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.pill});

  final AksharaHeroPill pill;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final accent = pill.tone.resolve(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AksharaSpacing.s3,
        vertical: AksharaSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: accent.container.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AksharaRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: accent.foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s2),
          Flexible(
            child: Text(
              pill.label,
              style: text.labelMedium.copyWith(
                color: accent.foreground,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
