import '../../../features/parent/fees/fees_provider.dart';
import '../../../features/parent/receipts/receipt_models.dart';
import 'mock_canonical_student_registry.dart';

/// In-memory fees state so a confirmed payment actually closes the loop:
/// the installment is marked paid, the amount due drops, and a receipt appears
/// in history. Seeded once from the static sample data so initial screens are
/// unchanged.
class MockFeeStore {
  MockFeeStore._();
  static final MockFeeStore instance = MockFeeStore._();

  ParentFeesData? _seed;
  List<FeeInstallment>? _installments;
  List<PaymentHistoryItem>? _history;
  List<FeeReceipt>? _receipts;
  int _pendingAmount = 0;
  int _paidAmount = 0;
  int _annualAmount = 0;
  int _receiptSeq = 0;

  void ensureSeeded({
    required ParentFeesData seedFees,
    required List<FeeReceipt> seedReceipts,
  }) {
    if (_installments != null) return;
    _seed = seedFees;
    _installments = [...seedFees.installments];
    _history = [...seedFees.paymentHistory];
    _receipts = [...seedReceipts];
    _pendingAmount = seedFees.pendingAmount;
    _paidAmount = seedFees.paidAmount;
    _annualAmount = seedFees.annualAmount;
  }

  void reset() {
    _seed = null;
    _installments = null;
    _history = null;
    _receipts = null;
    _pendingAmount = 0;
    _paidAmount = 0;
    _annualAmount = 0;
    _receiptSeq = 0;
  }

  ParentFeesData feesData() {
    final seed = _seed!;
    final progress =
        _annualAmount == 0 ? 0 : ((_paidAmount / _annualAmount) * 100).round();
    return ParentFeesData(
      pendingAmount: _pendingAmount,
      isOverdue: _pendingAmount > 0 && seed.isOverdue,
      dueLabel: _pendingAmount > 0 ? seed.dueLabel : 'All dues cleared',
      paidAmount: _paidAmount,
      annualAmount: _annualAmount,
      progressPercent: progress,
      unreadNotifications: seed.unreadNotifications,
      installments: List.unmodifiable(_installments!),
      breakdown: seed.breakdown,
      paymentHistory: List.unmodifiable(_history!),
    );
  }

  List<FeeReceipt> receipts() => List.unmodifiable(_receipts!);

  /// Records a confirmed payment for [installmentId]: marks it paid, lowers the
  /// outstanding total, prepends a payment-history row, and creates a receipt.
  FeeReceipt recordPayment({
    required String installmentId,
    required int amount,
    required String paymentMethodLabel,
  }) {
    final child = MockCanonicalStudentRegistry.primaryMobileStudent;
    _receiptSeq++;

    final index =
        _installments!.indexWhere((i) => i.id == installmentId);
    var title = 'Fee payment';
    if (index != -1) {
      final inst = _installments![index];
      title = inst.title;
      if (inst.status != FeeInstallmentStatus.paid) {
        _pendingAmount =
            (_pendingAmount - inst.amount) < 0 ? 0 : _pendingAmount - inst.amount;
        _paidAmount += inst.amount;
      }
      _installments![index] = FeeInstallment(
        id: inst.id,
        title: inst.title,
        amount: inst.amount,
        status: FeeInstallmentStatus.paid,
        meta: 'Paid just now · ₹${inst.amount}',
        dueDateLabel: inst.dueDateLabel,
        hasReceipt: true,
        isLast: inst.isLast,
      );
    }

    final receiptNumber = 'APS-2026-${installmentId.toUpperCase()}';
    _history!.insert(
      0,
      PaymentHistoryItem(
        id: 'ph_paid_$_receiptSeq',
        title: '$title — Payment',
        dateLabel: 'Just now',
        amount: amount,
        statusLabel: 'Paid',
        isSuccess: true,
      ),
    );

    final receipt = FeeReceipt(
      id: 'rcpt_$installmentId',
      receiptNumber: receiptNumber,
      title: '$title — Fee payment',
      dateLabel: 'Just now',
      amount: amount,
      paymentMethod: paymentMethodLabel,
      statusLabel: 'Paid',
      childName: child.studentName,
      childClass: child.classLabel,
      category: 'Tuition',
      lineItems: [ReceiptLineItem(label: title, amount: amount)],
      schoolName: 'NIKSHA Vidyalaya',
    );
    _receipts!.insert(0, receipt);
    return receipt;
  }
}
