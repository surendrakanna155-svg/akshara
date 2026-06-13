import 'package:flutter/material.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'fees_provider.dart';

/// PA-03 installment timeline section with vertical rail.
class InstallmentTimeline extends StatelessWidget {
  const InstallmentTimeline({
    super.key,
    required this.installments,
    this.onPayInstallment,
    this.onReceiptTap,
  });

  final List<FeeInstallment> installments;
  final void Function(FeeInstallment installment)? onPayInstallment;
  final void Function(FeeInstallment installment)? onReceiptTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(
          title: 'Installments',
          fixedHeight: false,
          spacingBelow: AksharaSpacing.s3,
        ),
        Padding(
          padding: const EdgeInsets.only(left: AksharaSpacing.s2),
          child: Column(
            children: [
              for (var i = 0; i < installments.length; i++)
                _InstallmentRow(
                  installment: installments[i],
                  showRailLine: !installments[i].isLast,
                  onPay: installments[i].status == FeeInstallmentStatus.due
                      ? () => onPayInstallment?.call(installments[i])
                      : null,
                  onReceipt: installments[i].hasReceipt
                      ? () => onReceiptTap?.call(installments[i])
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({
    required this.installment,
    required this.showRailLine,
    this.onPay,
    this.onReceipt,
  });

  final FeeInstallment installment;
  final bool showRailLine;
  final VoidCallback? onPay;
  final VoidCallback? onReceipt;

  static const double rowHeight = 96;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final statusStyle = _statusStyle(context, installment.status);

    return SizedBox(
      height: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                _TimelineDot(color: statusStyle.dotColor),
                if (showRailLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colors.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  installment.title,
                  style: text.bodyLarge.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (installment.meta != null) ...[
                  const SizedBox(height: AksharaSpacing.s1),
                  Text(
                    installment.meta!,
                    style: text.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AksharaSpacing.s1),
                Wrap(
                  spacing: AksharaSpacing.s2,
                  runSpacing: AksharaSpacing.s1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AksharaStatusChip(
                      label: statusStyle.label,
                      background: statusStyle.background,
                      foreground: statusStyle.foreground,
                    ),
                    if (onPay != null)
                      TextButton(
                        onPressed: onPay,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Pay now',
                          style: text.labelLarge.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onReceipt != null)
            IconButton(
              onPressed: onReceipt,
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'View receipt',
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 40),
              ),
            ),
        ],
      ),
    );
  }

  ({String label, Color background, Color foreground, Color dotColor})
      _statusStyle(BuildContext context, FeeInstallmentStatus status) {
    final colors = context.colors;
    final ext = context.akshara;

    return switch (status) {
      FeeInstallmentStatus.paid => (
          label: 'Paid',
          background: ext.successContainer,
          foreground: ext.success,
          dotColor: ext.success,
        ),
      FeeInstallmentStatus.due => (
          label: 'Due',
          background: ext.warningContainer,
          foreground: ext.warning,
          dotColor: ext.warning,
        ),
      FeeInstallmentStatus.upcoming => (
          label: 'Upcoming',
          background: colors.surfaceContainerHighest,
          foreground: colors.onSurfaceVariant,
          dotColor: colors.onSurfaceVariant,
        ),
    };
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: context.colors.surface,
          width: 2,
        ),
      ),
    );
  }
}

