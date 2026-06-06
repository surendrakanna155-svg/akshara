import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../fees/fees_provider.dart';
import '../receipt_models.dart';

/// Receipt list row for PA-11.
class ReceiptListRow extends StatelessWidget {
  const ReceiptListRow({
    super.key,
    required this.receipt,
    this.onTap,
    this.showDivider = true,
  });

  final FeeReceipt receipt;
  final VoidCallback? onTap;
  final bool showDivider;

  static const double rowHeight = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: onTap != null,
          label:
              '${receipt.title}, ${receipt.receiptNumber}, ${formatInr(receipt.amount)}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: rowHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AksharaSpacing.s4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: ext.successContainer,
                          borderRadius: AksharaRadius.chip,
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: ext.success,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AksharaSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              receipt.title,
                              style: text.bodyMedium.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${receipt.receiptNumber} · ${receipt.dateLabel}',
                              style: text.bodySmall.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatInr(receipt.amount),
                        style: text.titleSmall.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: AksharaSpacing.s1),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: colors.outlineVariant),
      ],
    );
  }
}
