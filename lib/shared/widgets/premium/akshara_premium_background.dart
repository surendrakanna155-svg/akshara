import 'package:flutter/material.dart';

import '../../../theme/premium_tokens.dart';
import 'akshara_line_art.dart';

/// Soft full-screen premium canvas: a gentle brand-tinted gradient with an
/// optional faint line-art motif tucked into a corner. Replaces flat ERP grey
/// backgrounds — the "no large empty white areas" rule. Decorative only.
class AksharaPremiumBackground extends StatelessWidget {
  const AksharaPremiumBackground({
    super.key,
    required this.child,
    this.motif = AksharaMotif.graduationCap,
    this.showMotif = true,
  });

  final Widget child;
  final AksharaMotif motif;
  final bool showMotif;

  @override
  Widget build(BuildContext context) {
    final premium = context.premiumOrNull ?? AksharaPremiumTokens.light();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: premium.canvasGradient,
        ),
      ),
      // The content [child] is the only non-positioned child, so it sizes the
      // Stack (no StackFit.expand → never demands unbounded height from a
      // loose-height Scaffold body). The motif is painted behind it.
      child: Stack(
        children: [
          if (showMotif)
            Positioned(
              right: -60,
              bottom: -50,
              child: AksharaLineArt(
                motif: motif,
                size: 320,
                opacity: premium.lineArtOpacity * 0.8,
                strokeWidth: 2.4,
              ),
            ),
          child,
        ],
      ),
    );
  }
}
