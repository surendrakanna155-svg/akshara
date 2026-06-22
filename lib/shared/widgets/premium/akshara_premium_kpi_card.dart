import 'package:flutter/material.dart';

import '../../../theme/premium_tokens.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';

/// Premium KPI tile — soft layered card, a status-tinted rounded icon badge, a
/// muted label, and a big confident number. Mobile-first and text-scale aware
/// (grows with accessibility text so tall Indic scripts never clip). Self-sizing
/// height — put it inside an [Expanded] in a [Row].
class AksharaPremiumKpiCard extends StatelessWidget {
  const AksharaPremiumKpiCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    this.onTap,
    this.semanticLabel,
  });

  final String value;
  final String label;
  final IconData icon;
  final KpiAccent accent;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final premium = context.premiumOrNull ?? AksharaPremiumTokens.light();
    final text = context.aksharaText;
    final colors = context.colors;
    final accentColors = accent.resolve(context);

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: premium.premiumSurface,
        borderRadius: BorderRadius.circular(AksharaRadius.xl),
        border: Border.all(color: premium.premiumBorder),
        boxShadow: premium.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColors.container,
                borderRadius: BorderRadius.circular(AksharaRadius.md),
              ),
              child: Icon(icon, size: 19, color: accentColors.foreground),
            ),
            const SizedBox(height: AksharaSpacing.s3),
            Text(
              label,
              style: text.kpiLabel.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              value,
              style: text.titleLarge.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.05,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? '$value $label',
      child: onTap == null
          ? card
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AksharaRadius.xl),
                child: card,
              ),
            ),
    );
  }
}
