import 'package:flutter/material.dart';

import '../../../theme/premium_tokens.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'akshara_line_art.dart';

/// The AI suggestion bar — a saturated brand-gradient surface that signals
/// "intelligent product." A spark badge, an eyebrow + message, and a high-
/// contrast action button. First-class chrome on premium dashboards.
class AksharaAiSuggestionBar extends StatelessWidget {
  const AksharaAiSuggestionBar({
    super.key,
    required this.message,
    this.eyebrow = 'AKSHARA SUGGESTS',
    this.actionLabel,
    this.onAction,
    this.semanticLabelPrefix = 'AI suggestion',
  });

  final String message;
  final String eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String semanticLabelPrefix;

  @override
  Widget build(BuildContext context) {
    final premium = context.premiumOrNull ?? AksharaPremiumTokens.light();
    final text = context.aksharaText;
    final onBar = premium.onAiBar;

    return Semantics(
      container: true,
      label: '$semanticLabelPrefix: $message',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: premium.aiBarGradient,
          ),
          borderRadius: BorderRadius.circular(AksharaRadius.xl),
          boxShadow: [
            BoxShadow(
              color: premium.brandStart.withValues(alpha: 0.34),
              blurRadius: 38,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AksharaRadius.xl),
          child: Stack(
            children: [
              const Positioned(
                right: -8,
                top: -12,
                child: AksharaLineArt(
                  motif: AksharaMotif.spark,
                  size: 120,
                  color: Colors.white,
                  opacity: 0.18,
                  strokeWidth: 2,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(AksharaRadius.md),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: onBar,
                      ),
                    ),
                    const SizedBox(width: AksharaSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            eyebrow,
                            style: text.labelSmall.copyWith(
                              color: onBar.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            style: text.bodyMedium.copyWith(
                              color: onBar,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(width: AksharaSpacing.s3),
                      Flexible(
                        child: _AiActionButton(
                          label: actionLabel!,
                          onTap: onAction!,
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

class _AiActionButton extends StatelessWidget {
  const _AiActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final premium = context.premiumOrNull ?? AksharaPremiumTokens.light();
    final text = context.aksharaText;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AksharaRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AksharaRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s3,
            vertical: AksharaSpacing.s3,
          ),
          child: Text(
            label,
            style: text.labelLarge.copyWith(
              color: premium.brandStart,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
