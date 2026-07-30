import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/async/erp_async_state.dart';
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
    // CERT-001 — honest-async contract: loading / error / empty all come from
    // the real repository state. There is no mock payload behind this screen.
    final state = ref.watch(parentFeesViewStateProvider);
    final data = ref.watch(parentFeesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: 'Fees',
        unreadNotifications: state.hasData ? data.unreadNotifications : 0,
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
      // DS V2 Phase 3 — premium persona canvas behind the fees content, cohesive
      // with the dashboards. Money display + pay flow below are unchanged.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: ErpAsyncBody<ParentFeesData>(
          state: state,
          loadingLabel: 'Loading fees',
          emptyMessage:
              'No fee statement has been issued for your child yet. It will '
              'appear here once the school assigns a fee structure.',
          emptyIcon: Icons.receipt_long_outlined,
          onRetry: () {
            ref.read(parentFeesErrorProvider.notifier).state = false;
            ref.invalidate(parentFeesFutureProvider);
          },
          builder: (data) => LayoutBuilder(
                    builder: (context, constraints) {
                      final isTablet =
                          constraints.maxWidth >= _tabletBreakpoint;
                      final horizontalPadding = isTablet
                          ? AksharaSpacing.tabletMargin
                          : AksharaSpacing.mobileMargin;
                      final payableId = _payableInstallmentId(data);
                      final showStickyCta =
                          !isTablet && data.hasPending && payableId != null;

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
                                          // JOURNEY-007 — the pay action carries
                                          // the REAL due installment id, never a
                                          // demo fixture id, and is disabled
                                          // when there is none.
                                          onPayNow: payableId == null
                                              ? null
                                              : () => _handlePayNow(
                                                    installmentId: payableId,
                                                  ),
                                        ),
                                        const SizedBox(
                                            height: AksharaSpacing.s4),
                                        // `annualAmount` is the denominator of
                                        // the collection %, passed so the ring
                                        // can stay silent when it is unknown
                                        // (undefined ≠ 0%).
                                        FeeCollectionProgress(
                                          percent: data.progressPercent,
                                          annualAmount: data.annualAmount,
                                        ),
                                        const SizedBox(
                                            height: AksharaSpacing.s4),
                                        InstallmentTimeline(
                                          installments: data.installments,
                                          onPayInstallment: (installment) =>
                                              _handlePayNow(
                                            installmentId: installment.id,
                                          ),
                                          onReceiptTap: (installment) =>
                                              onViewReceipt
                                                  ?.call(installment.id),
                                        ),
                                        const SizedBox(
                                            height: AksharaSpacing.s4),
                                        FeeBreakdownCard(
                                          categories: data.breakdown,
                                        ),
                                        const SizedBox(
                                            height: AksharaSpacing.s3),
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
                                  onPayNow: () => _handlePayNow(
                                    installmentId: payableId,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }

  /// The real, server-issued id of the installment a payment should target.
  /// Null when the school has raised nothing payable — in which case the pay
  /// affordances are hidden rather than pointed at a demo id (JOURNEY-007).
  static String? _payableInstallmentId(ParentFeesData data) {
    for (final installment in data.installments) {
      if (installment.status == FeeInstallmentStatus.due &&
          installment.id.trim().isNotEmpty) {
        return installment.id;
      }
    }
    return null;
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
