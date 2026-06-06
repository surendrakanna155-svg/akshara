import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../fees/fees_provider.dart';
import '../payment_models.dart';

/// Amount breakdown card for PA-10 payment summary.
class PaymentBreakdownCard extends StatelessWidget {
  const PaymentBreakdownCard({
    super.key,
    required this.summary,
  });

  final PaymentSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Payment amount breakdown',
      child: Material(
        color: colors.surface,
        elevation: 1,
        shadowColor: colors.onSurface.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                summary.installmentTitle,
                style: text.titleSmall.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                summary.dueLabel,
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s3),
              for (final line in summary.breakdown) ...[
                _BreakdownRow(label: line.label, amount: line.amount),
                const SizedBox(height: AksharaSpacing.s2),
              ],
              Divider(color: colors.outlineVariant),
              const SizedBox(height: AksharaSpacing.s2),
              _BreakdownRow(
                label: 'Total payable',
                amount: summary.totalAmount,
                emphasize: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final int amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: (emphasize ? text.titleSmall : text.bodyMedium).copyWith(
              color: colors.onSurface,
              fontWeight: emphasize ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          formatInr(amount),
          style: (emphasize ? text.titleSmall : text.bodyMedium).copyWith(
            color: emphasize ? colors.primary : colors.onSurface,
            fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
