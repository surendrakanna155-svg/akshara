import 'package:flutter/material.dart';

import '../../../theme/premium_tokens.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'akshara_line_art.dart';

/// Illustration-led empty state — a bold line-art motif, a human title, one
/// supporting line, and a single primary action. The primary use of the
/// line-art language. Mobile-first, centered.
class AksharaPremiumEmptyState extends StatelessWidget {
  const AksharaPremiumEmptyState({
    super.key,
    required this.motif,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final AksharaMotif motif;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final premium = context.premiumOrNull ?? AksharaPremiumTokens.light();
    final text = context.aksharaText;
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AksharaSpacing.s5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: premium.heroGradient,
                ),
                shape: BoxShape.circle,
              ),
              child: AksharaLineArt(
                motif: motif,
                size: 88,
                color: premium.brandStart,
                opacity: 0.85,
                strokeWidth: 2.2,
              ),
            ),
            const SizedBox(height: AksharaSpacing.s5),
            Text(
              title,
              style: text.titleMedium.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                message!,
                style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AksharaSpacing.s5),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
