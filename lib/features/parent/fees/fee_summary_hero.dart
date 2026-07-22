import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_progress_ring.dart';
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
        // DS V2 P4 — size to content (was a fixed 160 that overflowed when the
        // due label / amount wrapped or text scaled up). The money display,
        // colours, and semantics are unchanged.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
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
                const SizedBox(height: AksharaSpacing.s4),
                // Wrap (not Row) so long INR amounts reflow instead of
                // overflowing the card width.
                Wrap(
                  spacing: AksharaSpacing.s4,
                  runSpacing: AksharaSpacing.s1,
                  children: [
                    _MetaItem(
                      label: 'Paid: ${formatInr(paidAmount)}',
                      color: ext.success,
                      textStyle: text.bodySmall,
                    ),
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

/// PA-03 collection progress — DS V2 Phase 3 flagship: the fees-collected
/// percentage as a premium success-toned progress **ring** (was a linear bar),
/// with a supporting bar for the exact fill. Same data, richer presentation.
class FeeCollectionProgress extends StatelessWidget {
  const FeeCollectionProgress({
    super.key,
    required this.percent,
  });

  final int percent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ext = context.akshara;
    final text = context.aksharaText;
    final clamped = percent.clamp(0, 100);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Row(
          children: [
            AksharaProgressRing(
              value: clamped / 100,
              size: 60,
              strokeWidth: 7,
              color: ext.success,
              semanticLabel: 'Collection progress $clamped percent',
              child: Text(
                '$clamped%',
                style: text.labelLarge.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: AksharaSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Collection progress',
                    style: text.bodyMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(
                    'of your annual fees paid so far',
                    style: text.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AksharaSpacing.s2),
                  ClipRRect(
                    borderRadius: AksharaRadius.chip,
                    child: SizedBox(
                      height: 6,
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
          ],
        ),
      ),
    );
  }
}
