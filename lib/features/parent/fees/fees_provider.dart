import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../shared/async/erp_async_state.dart';
import '../parent_active_child_provider.dart';

/// Installment payment state (PA-03 §8).
enum FeeInstallmentStatus { paid, due, upcoming }

/// Single fee installment timeline row.
class FeeInstallment {
  const FeeInstallment({
    required this.id,
    required this.title,
    required this.amount,
    required this.status,
    this.meta,
    this.dueDateLabel,
    this.hasReceipt = false,
    this.isLast = false,
  });

  final String id;
  final String title;
  final int amount;
  final FeeInstallmentStatus status;
  final String? meta;
  final String? dueDateLabel;
  final bool hasReceipt;
  final bool isLast;
}

/// Line item inside a breakdown category.
class FeeBreakdownLine {
  const FeeBreakdownLine({
    required this.label,
    required this.amount,
  });

  final String label;
  final int amount;
}

/// Accordion category in fee breakdown.
class FeeBreakdownCategory {
  const FeeBreakdownCategory({
    required this.id,
    required this.title,
    required this.lines,
    this.initiallyExpanded = false,
  });

  final String id;
  final String title;
  final List<FeeBreakdownLine> lines;
  final bool initiallyExpanded;
}

/// Payment history list entry.
class PaymentHistoryItem {
  const PaymentHistoryItem({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.amount,
    required this.statusLabel,
    required this.isSuccess,
  });

  final String id;
  final String title;
  final String dateLabel;
  final int amount;
  final String statusLabel;
  final bool isSuccess;
}

/// Full fees screen payload (PA-03 sample data §6).
class ParentFeesData {
  const ParentFeesData({
    required this.pendingAmount,
    required this.isOverdue,
    required this.dueLabel,
    required this.paidAmount,
    required this.annualAmount,
    required this.progressPercent,
    required this.installments,
    required this.breakdown,
    required this.paymentHistory,
    this.unreadNotifications = 0,
  });

  final int pendingAmount;
  final bool isOverdue;
  final String dueLabel;
  final int paidAmount;
  final int annualAmount;
  final int progressPercent;
  final List<FeeInstallment> installments;
  final List<FeeBreakdownCategory> breakdown;
  final List<PaymentHistoryItem> paymentHistory;
  final int unreadNotifications;

  bool get hasPending => pendingAmount > 0;

  /// Honest-async contract: the neutral shape used when the server issued no
  /// fee statement. It carries NO money, NO due date and NO payment history —
  /// the screen renders an empty/error state around it.
  factory ParentFeesData.empty() {
    return const ParentFeesData(
      pendingAmount: 0,
      isOverdue: false,
      dueLabel: '',
      paidAmount: 0,
      annualAmount: 0,
      progressPercent: 0,
      installments: [],
      breakdown: [],
      paymentHistory: [],
    );
  }

  factory ParentFeesData.mock() {
    return const ParentFeesData(
      pendingAmount: 4200,
      isOverdue: true,
      dueLabel: 'Due 12 Jun 2026 · Term 2',
      paidAmount: 18800,
      annualAmount: 23000,
      progressPercent: 82,
      unreadNotifications: 2,
      installments: [
        FeeInstallment(
          id: 'term_1',
          title: 'Term 1',
          amount: 8000,
          status: FeeInstallmentStatus.paid,
          meta: 'Paid 15 Apr · ₹8,000',
          hasReceipt: true,
        ),
        FeeInstallment(
          id: 'term_2',
          title: 'Term 2',
          amount: 4200,
          status: FeeInstallmentStatus.due,
          meta: 'Due 12 Jun 2026',
          dueDateLabel: 'Due 12 Jun',
        ),
        FeeInstallment(
          id: 'term_3',
          title: 'Term 3',
          amount: 5400,
          status: FeeInstallmentStatus.upcoming,
          meta: 'Due Aug 2026',
        ),
        FeeInstallment(
          id: 'term_4',
          title: 'Term 4',
          amount: 5400,
          status: FeeInstallmentStatus.upcoming,
          meta: 'Due Nov 2026',
          isLast: true,
        ),
      ],
      breakdown: [
        FeeBreakdownCategory(
          id: 'tuition',
          title: 'Tuition',
          initiallyExpanded: true,
          lines: [
            FeeBreakdownLine(label: 'Tuition fee', amount: 18000),
            FeeBreakdownLine(label: 'Lab fee', amount: 2000),
            FeeBreakdownLine(label: 'Exam fee', amount: 1000),
          ],
        ),
        FeeBreakdownCategory(
          id: 'transport',
          title: 'Transport',
          lines: [
            FeeBreakdownLine(label: 'Bus route A', amount: 1200),
            FeeBreakdownLine(label: 'Fuel surcharge', amount: 300),
          ],
        ),
        FeeBreakdownCategory(
          id: 'activity',
          title: 'Activity',
          lines: [
            FeeBreakdownLine(label: 'Sports club', amount: 800),
            FeeBreakdownLine(label: 'Annual day', amount: 500),
          ],
        ),
      ],
      paymentHistory: [
        PaymentHistoryItem(
          id: 'ph_1',
          title: 'Term 1 — Full payment',
          dateLabel: '15 Apr 2026',
          amount: 8000,
          statusLabel: 'Paid',
          isSuccess: true,
        ),
        PaymentHistoryItem(
          id: 'ph_2',
          title: 'Admission fee',
          dateLabel: '2 Mar 2026',
          amount: 5000,
          statusLabel: 'Paid',
          isSuccess: true,
        ),
        PaymentHistoryItem(
          id: 'ph_3',
          title: 'Transport — Q1',
          dateLabel: '10 Jan 2026',
          amount: 1500,
          statusLabel: 'Paid',
          isSuccess: true,
        ),
        PaymentHistoryItem(
          id: 'ph_4',
          title: 'Activity kit',
          dateLabel: '5 Dec 2025',
          amount: 800,
          statusLabel: 'Paid',
          isSuccess: true,
        ),
      ],
    );
  }

}

/// Formats whole rupee amounts as `₹4,200`.
String formatInr(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  if (negative) {
    buffer.write('-');
  }
  buffer.write('₹');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

final parentFeesLoadingProvider = StateProvider<bool>((ref) => false);
final parentFeesErrorProvider = StateProvider<bool>((ref) => false);
final parentFeesEmptyProvider = StateProvider<bool>((ref) => false);

final parentFeesFutureProvider = FutureProvider<ParentFeesData>((ref) async {
  return ref.read(parentRepositoryProvider).getFees(query: ref.watch(parentRepositoryQueryProvider));
});

/// CERT-001 — honest-async contract. Loading/error/empty are derived from the
/// REAL [AsyncValue]; there is no terminal mock fallback, so a failed or empty
/// `GET /parent/fees` can no longer render a fabricated ₹23,000 statement with
/// four "Paid" receipts.
final parentFeesViewStateProvider = Provider<ErpViewState<ParentFeesData>>((
  ref,
) {
  return resolveErpAsync<ParentFeesData>(
    ref.watch(parentFeesFutureProvider),
    forceLoading: ref.watch(parentFeesLoadingProvider),
    forceError: ref.watch(parentFeesErrorProvider),
    forceEmpty: ref.watch(parentFeesEmptyProvider),
    errorMessage: 'Unable to load fees right now.',
    // NOT `isDataEmpty`: a school that has published nothing still renders the
    // screen, because each section carries its OWN honest empty state
    // ("No installment schedule published yet.", "No fee breakdown published
    // yet.") which says more than one generic page-level empty would.
  );
});

/// Fees payload for [ParentFeesScreen]. Neutral-empty when the server issued
/// nothing — never a demo statement.
final parentFeesProvider = Provider<ParentFeesData>((ref) {
  return honestPayload(
    ref.watch(parentFeesViewStateProvider),
    ParentFeesData.empty,
  );
});

/// Index of expanded accordion panel (PA-03 expanded index 0).
final feesAccordionExpandedProvider = StateProvider<int?>((ref) => 0);
