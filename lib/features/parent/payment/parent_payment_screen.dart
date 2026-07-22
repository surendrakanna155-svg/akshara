import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../fees/fees_provider.dart';
import 'parent_payment_provider.dart';
import 'payment_models.dart';
import 'widgets/payment_breakdown_card.dart';
import 'widgets/payment_method_selector.dart';
import '../../../theme/breakpoints.dart';

/// Parent fee payment flow — PA-10.
class ParentPaymentScreen extends ConsumerStatefulWidget {
  const ParentPaymentScreen({
    super.key,
    this.installmentId,
    this.onNotificationsTap,
    this.onViewReceipt,
    this.onBackToFees,
  });

  final String? installmentId;
  final VoidCallback? onNotificationsTap;
  final void Function(String receiptId)? onViewReceipt;
  final VoidCallback? onBackToFees;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth =
      AksharaBreakpoints.compactContentMaxWidth;

  @override
  ConsumerState<ParentPaymentScreen> createState() =>
      _ParentPaymentScreenState();
}

class _ParentPaymentScreenState extends ConsumerState<ParentPaymentScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.installmentId != null) {
      Future.microtask(() {
        ref.read(parentPaymentInstallmentIdProvider.notifier).state =
            widget.installmentId!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(parentPaymentLoadingProvider);
    final hasError = ref.watch(parentPaymentErrorProvider);
    final phase = ref.watch(parentPaymentPhaseProvider);

    PaymentSummary? summary;
    if (!hasError && phase == PaymentFlowPhase.summary) {
      summary = ref.watch(parentPaymentSummaryProvider);
    } else if (!hasError &&
        (phase == PaymentFlowPhase.processing ||
            phase == PaymentFlowPhase.success ||
            phase == PaymentFlowPhase.failure)) {
      summary = ref.read(parentPaymentSummaryProvider);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: 'Pay Fee',
        subtitle: summary == null
            ? null
            : '${summary.childName} · ${summary.childClass}',
        unreadNotifications: summary?.unreadNotifications ?? 0,
        trailingPadding: true,
        onNotificationsTap: widget.onNotificationsTap,
      ),
      // DS V2 P4 — premium persona canvas behind the pay flow. The payment
      // summary, honest fail-closed "not charged" state, and the success
      // ceremony below are unchanged.
      body: AksharaPremiumBackground(
        showMotif: false,
        child: isLoading
            ? const AksharaLoadingState(
                semanticLabel: 'Loading payment details')
            : hasError
                ? AksharaErrorState(
                    message: 'Unable to load payment details.',
                    onRetry: () => ref
                        .read(parentPaymentErrorProvider.notifier)
                        .state = false,
                  )
                : _buildPhaseBody(context, ref, phase, summary),
      ),
    );
  }

  Widget _buildPhaseBody(
    BuildContext context,
    WidgetRef ref,
    PaymentFlowPhase phase,
    PaymentSummary? summary,
  ) {
    return switch (phase) {
      PaymentFlowPhase.processing => const AksharaLoadingState(
          semanticLabel: 'Processing payment',
        ),
      // PRA-P0-02 (client half): fail-closed terminal state. The intent was
      // created but there is no verified gateway payment to confirm it — no
      // gateway SDK is enabled — so we show an honest "not charged" notice
      // instead of a fabricated receipt.
      PaymentFlowPhase.pendingGatewayVerification => AksharaEmptyState(
          title: 'Online payment not enabled yet',
          message:
              'This school has not enabled an online payment gateway, so the '
              'fee could not be charged. You have NOT been charged. Please pay '
              'at the school office or try again later.',
          icon: Icons.lock_clock_outlined,
          actionLabel: 'Back to fees',
          onAction: () => resetPaymentFlow(ref),
        ),
      PaymentFlowPhase.success => _PaymentSuccessView(
          onViewReceipt: widget.onViewReceipt,
          onBackToFees: widget.onBackToFees,
        ),
      PaymentFlowPhase.failure => AksharaErrorState(
          message: 'Payment could not be completed. Please try again.',
          onRetry: () => resetPaymentFlow(ref),
        ),
      PaymentFlowPhase.summary => summary == null
          ? const AksharaEmptyState(
              message: 'No payable installment selected.',
              icon: Icons.payments_outlined,
            )
          : _PaymentSummaryView(
              summary: summary,
              onPay: () => submitParentPayment(ref),
            ),
    };
  }
}

class _PaymentSummaryView extends ConsumerWidget {
  const _PaymentSummaryView({
    required this.summary,
    required this.onPay,
  });

  final PaymentSummary summary;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final method = ref.watch(parentPaymentMethodProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet =
            constraints.maxWidth >= ParentPaymentScreen._tabletBreakpoint;
        final horizontalPadding = isTablet
            ? AksharaSpacing.tabletMargin
            : AksharaSpacing.mobileMargin;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet
                  ? ParentPaymentScreen._tabletMaxContentWidth
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PaymentHeroCard(summary: summary),
                        const SizedBox(height: AksharaSpacing.s4),
                        PaymentBreakdownCard(summary: summary),
                        const SizedBox(height: AksharaSpacing.s4),
                        const AksharaSectionHeader(
                          title: 'Payment method',
                          fixedHeight: false,
                          spacingBelow: AksharaSpacing.s3,
                        ),
                        PaymentMethodSelector(
                          selected: method,
                          onChanged: (value) => ref
                              .read(parentPaymentMethodProvider.notifier)
                              .state = value,
                        ),
                      ],
                    ),
                  ),
                ),
                _PayNowBar(
                  amount: summary.totalAmount,
                  onPay: onPay,
                  horizontalPadding: horizontalPadding,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaymentHeroCard extends StatelessWidget {
  const _PaymentHeroCard({required this.summary});

  final PaymentSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label:
          'Payment summary ${formatInr(summary.totalAmount)} for ${summary.installmentTitle}',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount payable',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                formatInr(summary.totalAmount),
                style: text.headlineSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${summary.installmentTitle} · ${summary.dueLabel}',
                style: text.bodyMedium.copyWith(color: colors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayNowBar extends StatelessWidget {
  const _PayNowBar({
    required this.amount,
    required this.onPay,
    required this.horizontalPadding,
  });

  final int amount;
  final VoidCallback onPay;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AksharaSpacing.s3,
            horizontalPadding,
            AksharaSpacing.s3,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total',
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatInr(amount),
                      style: text.titleMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Pay ${formatInr(amount)} now',
                child: FilledButton(
                  onPressed: onPay,
                  child: const Text('Pay now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentSuccessView extends ConsumerWidget {
  const _PaymentSuccessView({
    this.onViewReceipt,
    this.onBackToFees,
  });

  final void Function(String receiptId)? onViewReceipt;
  final VoidCallback? onBackToFees;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(parentPaymentSuccessResultProvider);

    if (result == null) {
      return const AksharaEmptyState(
        message: 'Payment result unavailable.',
        icon: Icons.receipt_long_outlined,
      );
    }

    // P2-UX-1 — the shared success ceremony (adds the success haptic by
    // construction). Layout matches the former bespoke view exactly.
    return AksharaSuccessView(
      title: 'Payment successful',
      highlight: formatInr(result.paidAmount),
      subtitle: 'Receipt ${result.receiptNumber}',
      caption: '${result.paymentMethod.label} · ${result.paidAtLabel}',
      primaryLabel: 'View receipt',
      onPrimary: () => onViewReceipt?.call(result.receiptId),
      secondaryLabel: 'Back to fees',
      onSecondary: onBackToFees,
    );
  }
}
