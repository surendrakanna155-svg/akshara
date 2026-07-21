import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'fee_breakdown_card.dart';
import 'fee_summary_hero.dart';
import 'fees_provider.dart';
import 'installment_timeline.dart';
import 'pay_now_bottom_bar.dart';
import 'payment_history_card.dart';
import '../../../theme/breakpoints.dart';

/// Parent fees overview — PA-03 `PA-03-ParentFees-M`.
class ParentFeesScreen extends ConsumerWidget {
  const ParentFeesScreen({
    super.key,
    this.onPayNow,
    this.onViewReceipt,
    this.onPaymentHistoryItemTap,
    this.onOpenReceipts,
    this.onNotificationsTap,
  });

  /// Navigates to PA-10 fee payment.
  final void Function({String? installmentId})? onPayNow;

  /// Navigates to PA-11 receipt detail.
  final void Function(String installmentId)? onViewReceipt;

  final void Function(PaymentHistoryItem item)? onPaymentHistoryItemTap;
  final VoidCallback? onOpenReceipts;
  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth =
      AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(parentFeesProvider);
    final isLoading = ref.watch(parentFeesLoadingProvider);
    final hasError = ref.watch(parentFeesErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Fees',
        unreadNotifications: data.unreadNotifications,
        showReceiptHistory: true,
        trailingPadding: true,
        onReceiptHistoryTap: () {
          if (onOpenReceipts != null) {
            onOpenReceipts!();
          } else {
            _showPaymentHistory(context, data);
          }
        },
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load fees right now.',
                  onRetry: () =>
                      ref.read(parentFeesErrorProvider.notifier).state = false,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= _tabletBreakpoint;
                    final horizontalPadding = isTablet
                        ? AksharaSpacing.tabletMargin
                        : AksharaSpacing.mobileMargin;
                    final showStickyCta = !isTablet && data.hasPending;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet
                              ? _tabletMaxContentWidth
                              : double.infinity,
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: () async =>
                                    ref.invalidate(parentFeesFutureProvider),
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    horizontalPadding,
                                    AksharaSpacing.s4,
                                    horizontalPadding,
                                    showStickyCta ? 88 : AksharaSpacing.s6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      FeeSummaryHero(
                                        pendingAmount: data.pendingAmount,
                                        isOverdue: data.isOverdue,
                                        dueLabel: data.dueLabel,
                                        paidAmount: data.paidAmount,
                                        annualAmount: data.annualAmount,
                                        showInlinePayButton: isTablet,
                                        onPayNow: data.hasPending
                                            ? () => _handlePayNow(
                                                installmentId: 'term_2')
                                            : null,
                                      ),
                                      const SizedBox(height: AksharaSpacing.s4),
                                      FeeCollectionProgress(
                                        percent: data.progressPercent,
                                      ),
                                      const SizedBox(height: AksharaSpacing.s4),
                                      InstallmentTimeline(
                                        installments: data.installments,
                                        onPayInstallment: (installment) =>
                                            _handlePayNow(
                                          installmentId: installment.id,
                                        ),
                                        onReceiptTap: (installment) =>
                                            onViewReceipt?.call(installment.id),
                                      ),
                                      const SizedBox(height: AksharaSpacing.s4),
                                      FeeBreakdownCard(
                                        categories: data.breakdown,
                                      ),
                                      const SizedBox(height: AksharaSpacing.s3),
                                      SizedBox(
                                        height: 48,
                                        child: Center(
                                          child: TextButton(
                                            onPressed: () =>
                                                _showPaymentHistory(
                                                    context, data),
                                            child: Text(
                                              'View payment history',
                                              style: context
                                                  .aksharaText.labelLarge
                                                  .copyWith(
                                                color: context.colors.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (showStickyCta)
                              PayNowBottomBar(
                                amountDue: data.pendingAmount,
                                onPayNow: () =>
                                    _handlePayNow(installmentId: 'term_2'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _handlePayNow({String? installmentId}) {
    onPayNow?.call(installmentId: installmentId);
  }

  void _showPaymentHistory(BuildContext context, ParentFeesData data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PaymentHistorySheet(
        items: data.paymentHistory,
        onItemTap: onPaymentHistoryItemTap,
      ),
    );
  }
}
