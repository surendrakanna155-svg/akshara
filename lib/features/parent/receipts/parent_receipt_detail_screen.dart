import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../fees/fees_provider.dart';
import 'parent_receipts_provider.dart';
import 'receipt_models.dart';

/// PA-11 receipt detail with download and share actions.
class ParentReceiptDetailScreen extends ConsumerWidget {
  const ParentReceiptDetailScreen({
    super.key,
    required this.receiptId,
    this.onNotificationsTap,
    this.onDownload,
    this.onShare,
  });

  final String receiptId;
  final VoidCallback? onNotificationsTap;
  final void Function(FeeReceipt receipt)? onDownload;
  final void Function(FeeReceipt receipt)? onShare;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(parentReceiptDetailProvider(receiptId));
    final isLoading = ref.watch(parentReceiptsLoadingProvider);
    final hasError = ref.watch(parentReceiptsErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Receipt',
        subtitle: receipt?.receiptNumber,
        unreadNotifications: 2,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading receipt')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load receipt details.',
                  onRetry: () => ref
                      .read(parentReceiptsErrorProvider.notifier)
                      .state = false,
                )
              : receipt == null
                  ? const AksharaEmptyState(
                      message: 'Receipt not found.',
                      icon: Icons.receipt_long_outlined,
                    )
                  : _ReceiptDetailBody(
                      receipt: receipt,
                      onDownload: onDownload,
                      onShare: onShare,
                    ),
    );
  }
}

class _ReceiptDetailBody extends StatelessWidget {
  const _ReceiptDetailBody({
    required this.receipt,
    this.onDownload,
    this.onShare,
  });

  final FeeReceipt receipt;
  final void Function(FeeReceipt receipt)? onDownload;
  final void Function(FeeReceipt receipt)? onShare;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >=
            ParentReceiptDetailScreen._tabletBreakpoint;
        final horizontalPadding = isTablet
            ? AksharaSpacing.tabletMargin
            : AksharaSpacing.mobileMargin;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet
                  ? ParentReceiptDetailScreen._tabletMaxContentWidth
                  : double.infinity,
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AksharaSpacing.s4,
                      horizontalPadding,
                      AksharaSpacing.s4,
                    ),
                    child: Semantics(
                      container: true,
                      label: 'Receipt ${receipt.receiptNumber}',
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
                              Row(
                                children: [
                                  Icon(
                                    Icons.verified_outlined,
                                    color: ext.success,
                                  ),
                                  const SizedBox(width: AksharaSpacing.s2),
                                  Expanded(
                                    child: Text(
                                      receipt.statusLabel,
                                      style: text.labelLarge.copyWith(
                                        color: ext.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AksharaSpacing.s3),
                              Text(
                                receipt.title,
                                style: text.titleMedium.copyWith(
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: AksharaSpacing.s1),
                              Text(
                                receipt.dateLabel,
                                style: text.bodySmall.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              _DetailRow(
                                label: 'Student',
                                value:
                                    '${receipt.childName} · ${receipt.childClass}',
                              ),
                              _DetailRow(
                                label: 'School',
                                value: receipt.schoolName,
                              ),
                              _DetailRow(
                                label: 'Payment method',
                                value: receipt.paymentMethod,
                              ),
                              const Divider(height: AksharaSpacing.s6),
                              for (final line in receipt.lineItems) ...[
                                _AmountRow(
                                  label: line.label,
                                  amount: line.amount,
                                ),
                                const SizedBox(height: AksharaSpacing.s2),
                              ],
                              const Divider(height: AksharaSpacing.s6),
                              _AmountRow(
                                label: 'Total paid',
                                amount: receipt.amount,
                                emphasize: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AksharaSpacing.s3,
                      horizontalPadding,
                      AksharaSpacing.s3,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onShare == null
                                ? null
                                : () => onShare!(receipt),
                            icon: const Icon(Icons.ios_share_outlined),
                            label: const Text('Share'),
                          ),
                        ),
                        const SizedBox(width: AksharaSpacing.s3),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onDownload == null
                                ? null
                                : () => onDownload!(receipt),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Download'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: text.bodyMedium.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
