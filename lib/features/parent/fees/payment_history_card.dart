import 'package:flutter/material.dart';

import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'fees_provider.dart';

/// Single payment history row (used in list / bottom sheet).
class PaymentHistoryCard extends StatelessWidget {
  const PaymentHistoryCard({
    super.key,
    required this.item,
    this.onTap,
    this.showDivider = true,
  });

  final PaymentHistoryItem item;
  final VoidCallback? onTap;
  final bool showDivider;

  static const double rowHeight = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;
    final statusColor = item.isSuccess ? ext.success : colors.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: onTap != null,
          label: '${item.title}, ${item.dateLabel}, ${formatInr(item.amount)}',
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
                          color: item.isSuccess
                              ? ext.successContainer
                              : colors.errorContainer,
                          borderRadius: AksharaRadius.chip,
                        ),
                        child: Icon(
                          item.isSuccess
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: statusColor,
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
                              item.title,
                              style: text.bodyMedium.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.dateLabel,
                              style: text.bodySmall.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            formatInr(item.amount),
                            style: text.titleSmall.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            item.statusLabel,
                            style: text.labelSmall.copyWith(
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: colors.outlineVariant,
          ),
      ],
    );
  }
}

/// Bottom sheet listing all payment history entries.
class PaymentHistorySheet extends StatelessWidget {
  const PaymentHistorySheet({
    super.key,
    required this.items,
    this.onItemTap,
  });

  final List<PaymentHistoryItem> items;
  final void Function(PaymentHistoryItem item)? onItemTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + AksharaSpacing.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s4,
              vertical: AksharaSpacing.s2,
            ),
            child: Text(
              'Payment history',
              style: text.titleMedium.copyWith(color: colors.onSurface),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: colors.outlineVariant,
              ),
              itemBuilder: (context, index) {
                return PaymentHistoryCard(
                  item: items[index],
                  showDivider: false,
                  onTap: onItemTap == null
                      ? null
                      : () => onItemTap!(items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
