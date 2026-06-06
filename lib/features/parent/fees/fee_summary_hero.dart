import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/elevation.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'fees_provider.dart';

/// PA-03 fee due hero card — Parent/FeeDueCard (358×160).
class FeeSummaryHero extends StatelessWidget {
  const FeeSummaryHero({
    super.key,
    required this.pendingAmount,
    required this.isOverdue,
    required this.dueLabel,
    required this.paidAmount,
    required this.annualAmount,
    this.onPayNow,
    this.showInlinePayButton = false,
  });

  final int pendingAmount;
  final bool isOverdue;
  final String dueLabel;
  final int paidAmount;
  final int annualAmount;
  final VoidCallback? onPayNow;
  final bool showInlinePayButton;

  static const double height = 160;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ext = context.akshara;
    final text = context.aksharaText;
    final amountColor = isOverdue ? colors.error : colors.onSurface;

    return Semantics(
      container: true,
      label:
          'Total pending ${formatInr(pendingAmount)}. $dueLabel. Paid ${formatInr(paidAmount)} of ${formatInr(annualAmount)} annual.',
      child: Card(
        elevation: AksharaElevation.level2,
        margin: EdgeInsets.zero,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Total Pending',
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (isOverdue)
                      AksharaStatusChip(
                        label: 'Overdue',
                        background: colors.errorContainer,
                        foreground: colors.error,
                        size: AksharaStatusChipSize.compact,
                      ),
                    if (showInlinePayButton && pendingAmount > 0) ...[
                      const SizedBox(width: AksharaSpacing.s2),
                      FilledButton(
                        onPressed: onPayNow,
                        child: const Text('Pay Now'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AksharaSpacing.s2),
                Text(
                  formatInr(pendingAmount),
                  style: text.headlineMedium.copyWith(color: amountColor),
                ),
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  dueLabel,
                  style: text.bodyMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _MetaItem(
                      label: 'Paid: ${formatInr(paidAmount)}',
                      color: ext.success,
                      textStyle: text.bodySmall,
                    ),
                    const SizedBox(width: AksharaSpacing.s4),
                    _MetaItem(
                      label: 'Annual: ${formatInr(annualAmount)}',
                      color: colors.onSurfaceVariant,
                      textStyle: text.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.label,
    required this.color,
    required this.textStyle,
  });

  final String label;
  final Color color;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: textStyle.copyWith(color: color),
    );
  }
}

/// PA-03 collection progress card (358×72).
class FeeCollectionProgress extends StatelessWidget {
  const FeeCollectionProgress({
    super.key,
    required this.percent,
  });

  final int percent;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ext = context.akshara;
    final text = context.aksharaText;
    final clamped = percent.clamp(0, 100);

    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Collection progress',
                    style: text.bodyMedium.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$clamped%',
                    style: text.titleMedium.copyWith(color: ext.success),
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s2),
              ClipRRect(
                borderRadius: AksharaRadius.chip,
                child: SizedBox(
                  height: 8,
                  child: LinearProgressIndicator(
                    value: clamped / 100,
                    backgroundColor: colors.surfaceContainerHighest,
                    color: ext.success,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
