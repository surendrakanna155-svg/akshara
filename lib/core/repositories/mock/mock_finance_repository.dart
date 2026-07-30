import 'package:flutter/material.dart';

import '../../../features/finance/finance_fee_proration.dart';
import '../../../features/finance/finance_models.dart';
import '../../../features/finance/finance_requests.dart';
import '../../../features/finance/intelligence/finance_intelligence_models.dart';
import '../../../router/route_names.dart';
import '../interfaces/finance_repository.dart';
import '../paginated_result.dart';
import '../pagination_helpers.dart';
import '../repository_query.dart';
import '../../tenant/tenant_mock_scope.dart';

double _parseFinanceAmount(String value) =>
    double.tryParse(value.replaceAll(RegExp(r'[₹,\s]'), '')) ?? 0;

String _formatFinanceAmount(double value) => '₹${value.round()}';

/// Plain (no currency symbol) numeric string for fee-reduction percent /
/// fixed-amount fields — mirrors the backend's `String(row.percent)`.
String _plainNumber(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

/// In-memory finance data for MVP and Phase 2 screens.
class MockFinanceRepository implements FinanceRepository {
  final _FinanceMutableStore _store = _FinanceMutableStore();

  // PRC-A gap fix — bulk/class-wide assignment: tracks "$studentId|
  // $feeStructureId|$academicYear" tuples already bulk-assigned in this mock
  // session so a repeat call reports the same skip-a-duplicate semantics as
  // the real backend (mock has no per-student-id-keyed account row to check
  // against directly — see bulkAssignFeeStructure below).
  final Set<String> _bulkAssignedKeys = {};

  // FIN-R1..R5 — fee-recovery CRM in-memory state.
  final List<PromiseToPay> _promises = [
    const PromiseToPay(
      id: 'ptp_1',
      studentId: 'def_1',
      studentName: 'Priya Sharma',
      amount: '₹65000',
      promiseDate: '2026-07-10',
      status: PromiseToPayStatus.pending,
      notes: 'Parent committed to pay after salary credit.',
      createdAt: '2026-06-28',
    ),
    const PromiseToPay(
      id: 'ptp_2',
      studentId: 'def_3',
      studentName: 'Kavya Iyer',
      amount: '₹26000',
      promiseDate: '2026-06-25',
      status: PromiseToPayStatus.pending,
      notes: 'Partial promise — half of overdue.',
      createdAt: '2026-06-18',
    ),
    const PromiseToPay(
      id: 'ptp_3',
      studentId: 'def_2',
      studentName: 'Ananya Reddy',
      amount: '₹71667',
      promiseDate: '2026-06-15',
      status: PromiseToPayStatus.kept,
      notes: 'Paid in full on promise date.',
      createdAt: '2026-06-05',
      resolvedAt: '2026-06-15',
    ),
  ];

  // FIN-R6: collectorId → monthly target (whole-rupee string). Demo-mode store.
  final Map<String, String> _recoveryTargets = {};

  final Map<String, List<RecoveryContact>> _contacts = {
    'def_1': <RecoveryContact>[
      const RecoveryContact(
        id: 'rc_1',
        studentId: 'def_1',
        channel: 'whatsapp',
        outcome: 'no_answer',
        notes: 'Sent payment reminder with UPI link.',
        contactedBy: 'finance_demo',
        timestamp: '2026-05-12T16:30:00Z',
      ),
    ],
  };

  // FIN-D3 cancelled register + FIN-D1 day-close, in-memory.
  final List<CancelledCollection> _cancelledCollections = <CancelledCollection>[];
  final List<DayCloseEntry> _dayCloseEntries = <DayCloseEntry>[];
  int _dayCloseSeq = 0;

  int _recoverySeq = 100;
  @override
  Future<FinanceDashboardData> getDashboard(
      {required RepositoryQuery query}) async {
    return const FinanceDashboardData(
      outstandingAmount: '₹18.6L',
      defaultersCount: 47,
      kpis: [
        FinanceKpi(
          id: 'collected_mtd',
          value: '₹42.0L',
          label: 'Fee Collected (MTD)',
          icon: Icons.payments_outlined,
          accentName: 'success',
          detail: '+12% vs last month',
        ),
        FinanceKpi(
          id: 'outstanding',
          value: '₹18.6L',
          label: 'Outstanding',
          icon: Icons.pending_actions_outlined,
          accentName: 'warning',
        ),
        FinanceKpi(
          id: 'defaulters',
          value: '47',
          label: 'Defaulters',
          icon: Icons.warning_amber_outlined,
          accentName: 'error',
          detail: '12 critical',
        ),
        FinanceKpi(
          id: 'collection_rate',
          value: '68%',
          label: 'Collection Rate',
          icon: Icons.trending_up,
          accentName: 'primary',
        ),
        FinanceKpi(
          id: 'today',
          value: '₹2.4L',
          label: 'Collected Today',
          icon: Icons.today_outlined,
          accentName: 'success',
        ),
        FinanceKpi(
          id: 'pending_handoffs',
          value: '2',
          label: 'Admissions Handoffs',
          icon: Icons.swap_horiz_outlined,
          accentName: 'neutral',
        ),
      ],
      collectionTrend: [
        CollectionTrendPoint(label: 'Jan', amountLakhs: 6.2, targetLakhs: 7.0),
        CollectionTrendPoint(label: 'Feb', amountLakhs: 7.8, targetLakhs: 7.0),
        CollectionTrendPoint(label: 'Mar', amountLakhs: 8.4, targetLakhs: 8.0),
        CollectionTrendPoint(label: 'Apr', amountLakhs: 9.1, targetLakhs: 8.5),
        CollectionTrendPoint(label: 'May', amountLakhs: 10.5, targetLakhs: 9.0),
        CollectionTrendPoint(
            label: 'Jun', amountLakhs: 11.2, targetLakhs: 10.0),
      ],
      recentPayments: [
        RecentPayment(
          id: 'pay_1',
          studentName: 'Arjun Patel',
          admissionNumber: 'ADM-2026-0138',
          amount: '₹62,000',
          mode: 'UPI',
          receiptNumber: 'RCP-2026-8841',
          collectedAt: 'Today, 10:42',
          status: CollectionStatus.completed,
        ),
        RecentPayment(
          id: 'pay_2',
          studentName: 'Priya Sharma',
          admissionNumber: 'ADM-2025-0092',
          amount: '₹45,000',
          mode: 'Cash',
          receiptNumber: 'RCP-2026-8840',
          collectedAt: 'Today, 09:15',
          status: CollectionStatus.completed,
        ),
        RecentPayment(
          id: 'pay_3',
          studentName: 'Rohan Mehta',
          admissionNumber: 'ADM-2025-0114',
          amount: '₹38,500',
          mode: 'Card',
          receiptNumber: 'RCP-2026-8839',
          collectedAt: 'Yesterday',
          status: CollectionStatus.completed,
        ),
        RecentPayment(
          id: 'pay_4',
          studentName: 'Ananya Reddy',
          admissionNumber: 'ADM-2026-0142',
          amount: '₹71,500',
          mode: 'UPI',
          receiptNumber: 'RCP-2026-8838',
          collectedAt: 'Yesterday',
          status: CollectionStatus.pending,
        ),
        RecentPayment(
          id: 'pay_5',
          studentName: 'Emma Thomas',
          admissionNumber: 'ADM-2026-0135',
          amount: '₹85,000',
          mode: 'Bank Transfer',
          receiptNumber: 'RCP-2026-8837',
          collectedAt: '2 days ago',
          status: CollectionStatus.completed,
        ),
      ],
      aiInsight:
          'Collection rate dropped 4% in Class 8 this week. 12 students have overdue installments exceeding 30 days — consider sending reminders before the term-end deadline.',
    );
  }

  @override
  Future<PaginatedResult<CollectionPayment>> getCollections({
    required RepositoryQuery query,
  }) async =>
      PaginatedResult.fromItems(
        TenantMockScope.filter(query: query, items: _store.payments),
        page: query.page,
        pageSize: query.pageSize,
      );

  @override
  Future<DailyCollectionSummary> getDailySummary(
      {required RepositoryQuery query}) async {
    return const DailyCollectionSummary(
      dateLabel: 'Today, 5 Jun 2026',
      totalCollected: '₹2,41,500',
      transactionCount: 18,
      cashAmount: '₹45,000',
      upiAmount: '₹1,96,500',
      pendingReconciliation: 2,
    );
  }

  @override
  Future<PaginatedResult<FinanceFeeStructure>> getFeeStructures({
    required RepositoryQuery query,
    required String academicYear,
  }) async {
    return paginateList(_store.feeStructuresForYear(academicYear), query);
  }

  @override
  Future<PaginatedResult<String>> getAcademicYears({
    required RepositoryQuery query,
  }) async =>
      paginateList(const ['2026-27', '2025-26', '2024-25'], query);

  @override
  Future<PaginatedResult<StudentFeeAccount>> getStudentAccounts({
    required RepositoryQuery query,
  }) async =>
      PaginatedResult.fromItems(
        TenantMockScope.filter(
          query: query,
          items: List.unmodifiable(_store.studentAccounts),
        ),
        page: query.page,
        pageSize: query.pageSize,
      );

  @override
  Future<PaginatedResult<InstallmentPlan>> getInstallmentPlans({
    required RepositoryQuery query,
  }) async =>
      paginateList(const [
        InstallmentPlan(
          id: 'plan_quarterly',
          label: '3-term quarterly',
          installmentCount: 3,
          type: InstallmentPlanType.quarterly,
        ),
        InstallmentPlan(
          id: 'plan_termly',
          label: '4-term termly',
          installmentCount: 4,
          type: InstallmentPlanType.termly,
        ),
        InstallmentPlan(
          id: 'plan_monthly',
          label: '10-month monthly',
          installmentCount: 10,
          type: InstallmentPlanType.monthly,
        ),
        InstallmentPlan(
          id: 'plan_annual',
          label: 'Annual single payment',
          installmentCount: 1,
          type: InstallmentPlanType.annual,
        ),
      ], query);

  @override
  Future<CollectionDetail?> getCollectionDetail(
      {required RepositoryQuery query, required String collectionId}) async {
    for (final payment in _store.payments) {
      if (payment.id == collectionId) {
        return CollectionDetail(
          payment: payment,
          feeAccountId: _accountIdForAdmission(payment.admissionNumber),
          invoiceId: _store.invoices.isNotEmpty ? _store.invoices.first.id : '',
          summaryKpis: [
            FinanceKpi(
              id: 'amount',
              value: payment.amount,
              label: 'Payment amount',
              icon: Icons.payments_outlined,
              accentName: 'success',
            ),
            FinanceKpi(
              id: 'balance',
              value: _balanceForAdmission(payment.admissionNumber),
              label: 'Remaining balance',
              icon: Icons.account_balance_wallet_outlined,
              accentName: 'warning',
            ),
            const FinanceKpi(
              id: 'installments',
              value: '3 of 4 paid',
              label: 'Installments',
              icon: Icons.calendar_month_outlined,
              accentName: 'primary',
            ),
            FinanceKpi(
              id: 'mode',
              value: payment.mode,
              label: 'Payment mode',
              icon: Icons.credit_card_outlined,
              accentName: 'neutral',
            ),
          ],
          paymentTimeline: [
            PaymentTimelineEntry(
              id: 'tl_1',
              label: payment.receiptNumber,
              amount: payment.amount,
              timestamp: payment.collectedAt,
              status: payment.status,
              mode: payment.mode,
            ),
            const PaymentTimelineEntry(
              id: 'tl_2',
              label: 'Term 2 installment',
              amount: '₹45,000',
              timestamp: '15 May 2026',
              status: CollectionStatus.completed,
              mode: 'UPI',
            ),
            const PaymentTimelineEntry(
              id: 'tl_3',
              label: 'Term 1 installment',
              amount: '₹45,000',
              timestamp: '10 Apr 2026',
              status: CollectionStatus.completed,
              mode: 'Cash',
            ),
          ],
          installmentHistory: [
            const InstallmentHistoryEntry(
              id: 'inst_1',
              termLabel: 'Term 1',
              dueDate: '10 Apr 2026',
              amount: '₹61,667',
              paidAmount: '₹61,667',
              status: CollectionStatus.completed,
            ),
            const InstallmentHistoryEntry(
              id: 'inst_2',
              termLabel: 'Term 2',
              dueDate: '15 May 2026',
              amount: '₹61,667',
              paidAmount: '₹61,667',
              status: CollectionStatus.completed,
            ),
            InstallmentHistoryEntry(
              id: 'inst_3',
              termLabel: 'Term 3',
              dueDate: '15 Jun 2026',
              amount: '₹61,666',
              paidAmount: payment.amount,
              status: CollectionStatus.pending,
            ),
          ],
          receiptLinks: [
            ReceiptLink(
              receiptNumber: payment.receiptNumber,
              amount: payment.amount,
              dateLabel: payment.collectedAt,
              parentReceiptRoute: RouteNames.parentReceiptDetail(
                payment.receiptNumber,
              ),
            ),
            const ReceiptLink(
              receiptNumber: 'RCP-2026-8801',
              amount: '₹45,000',
              dateLabel: '15 May 2026',
              parentReceiptRoute: '/parent/receipts/RCP-2026-8801',
            ),
          ],
          aiInsight:
              'Payment aligns with quarterly plan. Next installment due in 10 days — auto-reminder scheduled via Parent App (PA-03).',
        );
      }
    }
    return null;
  }

  @override
  Future<FinanceCollectionResult> createCollection({
    required RepositoryQuery query,
    required CreateCollectionRequest request,
  }) async {
    final invoiceIndex = _store.invoices.indexWhere(
      (item) => item.id == request.invoiceId,
    );
    if (invoiceIndex < 0) {
      throw StateError('Invoice not found: ${request.invoiceId}');
    }
    final invoice = _store.invoices[invoiceIndex];
    if (invoice.invoiceStatus == InvoiceStatus.draft ||
        invoice.invoiceStatus == InvoiceStatus.cancelled) {
      throw StateError('Invoice is not collectible');
    }

    final amount = double.tryParse(
          request.amountCollected.replaceAll(RegExp(r'[₹,\s]'), ''),
        ) ??
        0;
    final outstanding = double.tryParse(invoice.outstandingAmount) ?? 0;
    if (amount <= 0 || amount > outstanding) {
      throw StateError('Invalid collection amount');
    }

    final newOutstanding = outstanding - amount;
    final paid = (double.tryParse(invoice.paidAmount) ?? 0) + amount;
    final newStatus = newOutstanding <= 0
        ? InvoiceStatus.paid
        : (paid > 0 ? InvoiceStatus.partiallyPaid : InvoiceStatus.issued);

    final collectionId = _store.nextId('col_');
    final receiptNumber =
        'RCP-${DateTime.now().year}-${collectionId.split('_').last}';
    final account =
        _store.studentAccounts.cast<StudentFeeAccount?>().firstWhere(
              (item) => item?.id == invoice.studentId,
              orElse: () => null,
            );
    final payment = CollectionPayment(
      id: collectionId,
      receiptNumber: receiptNumber,
      studentName: account?.studentName ?? 'Student',
      admissionNumber: account?.admissionNumber ?? 'ADM-MOCK',
      amount: request.amountCollected,
      mode: request.paymentMethod,
      collectedAt: request.collectionDate ?? 'Today',
      collectedBy: 'Finance Staff',
      status: CollectionStatus.completed,
      classLabel: account?.classLabel ?? '10',
    );
    _store.payments.insert(0, payment);

    final updatedInvoice = invoice.copyWith(
      outstandingAmount: newOutstanding.toStringAsFixed(0),
      paidAmount: paid.toStringAsFixed(0),
      invoiceStatus: newStatus,
    );
    _store.invoices[invoiceIndex] = updatedInvoice;

    final receipt = FinanceReceiptDetail(
      id: _store.nextId('rcpt_'),
      receiptNumber: receiptNumber,
      amount: request.amountCollected,
      receiptDate: request.collectionDate ?? '2026-06-10',
      collectionId: collectionId,
      invoiceId: invoice.id,
      studentAccountId: 'acct_mock',
    );

    return FinanceCollectionResult(
      collectionId: collectionId,
      invoiceId: invoice.id,
      studentAccountId: 'acct_mock',
      receiptNumber: receiptNumber,
      amountCollected: request.amountCollected,
      paymentMethod: request.paymentMethod,
      collectionDate: request.collectionDate ?? '2026-06-10',
      receipt: receipt,
      invoice: updatedInvoice,
    );
  }

  @override
  Future<QrPaymentSession> createQrPaymentSession({
    required RepositoryQuery query,
    required CreateQrPaymentSessionRequest request,
  }) async {
    final sessionId = _store.nextId('qr_');
    final amount = request.amount.trim();
    final session = QrPaymentSession(
      id: sessionId,
      invoiceId: request.invoiceId,
      amount: amount,
      upiPayload: 'upi://pay?pa=school@upi&pn=NIKSHA&am=$amount&tr=$sessionId',
      status: QrPaymentSessionStatus.pending,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
    _store.qrPaymentSessions.insert(0, session);
    return session;
  }

  @override
  Future<QrPaymentSession?> getQrPaymentSession({
    required RepositoryQuery query,
    required String sessionId,
  }) async {
    final index =
        _store.qrPaymentSessions.indexWhere((item) => item.id == sessionId);
    if (index < 0) return null;
    final current = _store.qrPaymentSessions[index];
    if (current.status == QrPaymentSessionStatus.pending &&
        DateTime.now().isAfter(current.expiresAt)) {
      final expired = QrPaymentSession(
        id: current.id,
        invoiceId: current.invoiceId,
        amount: current.amount,
        upiPayload: current.upiPayload,
        status: QrPaymentSessionStatus.expired,
        expiresAt: current.expiresAt,
        receiptNumber: current.receiptNumber,
      );
      _store.qrPaymentSessions[index] = expired;
      return expired;
    }
    return current;
  }

  @override
  Future<QrPaymentSession> confirmQrPaymentSession({
    required RepositoryQuery query,
    required String sessionId,
    required ConfirmQrPaymentRequest request,
  }) async {
    final index =
        _store.qrPaymentSessions.indexWhere((item) => item.id == sessionId);
    if (index < 0) {
      throw StateError('QR session not found: $sessionId');
    }
    final current = _store.qrPaymentSessions[index];
    if (current.status == QrPaymentSessionStatus.expired ||
        DateTime.now().isAfter(current.expiresAt)) {
      final expired = QrPaymentSession(
        id: current.id,
        invoiceId: current.invoiceId,
        amount: current.amount,
        upiPayload: current.upiPayload,
        status: QrPaymentSessionStatus.expired,
        expiresAt: current.expiresAt,
        receiptNumber: current.receiptNumber,
      );
      _store.qrPaymentSessions[index] = expired;
      throw StateError('QR session expired');
    }
    final confirmed = QrPaymentSession(
      id: current.id,
      invoiceId: current.invoiceId,
      amount: current.amount,
      upiPayload: current.upiPayload,
      status: QrPaymentSessionStatus.confirmed,
      expiresAt: current.expiresAt,
      receiptNumber: request.receiptNumber?.trim().isNotEmpty == true
          ? request.receiptNumber!.trim()
          : 'RCP-${DateTime.now().year}-${current.id.split('_').last}',
    );
    _store.qrPaymentSessions[index] = confirmed;
    return confirmed;
  }

  @override
  Future<FinanceCollectionResult> cancelCollection({
    required RepositoryQuery query,
    required String collectionId,
    required String reason,
  }) async {
    // FIN-D3: reason is mandatory (mirrors the backend 422 guard).
    if (reason.trim().isEmpty) {
      throw StateError('A cancellation reason is required');
    }
    final paymentIndex =
        _store.payments.indexWhere((item) => item.id == collectionId);
    if (paymentIndex < 0) {
      throw StateError('Collection not found: $collectionId');
    }
    final payment = _store.payments[paymentIndex];
    if (payment.status == CollectionStatus.refunded) {
      throw StateError('Collection already cancelled');
    }
    _store.payments[paymentIndex] = CollectionPayment(
      id: payment.id,
      receiptNumber: payment.receiptNumber,
      studentName: payment.studentName,
      admissionNumber: payment.admissionNumber,
      amount: payment.amount,
      mode: payment.mode,
      collectedAt: payment.collectedAt,
      collectedBy: payment.collectedBy,
      status: CollectionStatus.refunded,
      classLabel: payment.classLabel,
    );

    // FIN-D3: record it in the cancelled register.
    _cancelledCollections.insert(
      0,
      CancelledCollection(
        id: payment.id,
        receiptNumber: payment.receiptNumber,
        studentName: payment.studentName,
        admissionNumber: payment.admissionNumber,
        classLabel: payment.classLabel,
        amount: payment.amount,
        mode: payment.mode,
        collectedAt: payment.collectedAt,
        reason: reason.trim(),
        cancelledBy: 'finance_demo',
        cancelledByName: 'Finance Admin',
        cancelledAt: DateTime.now().toIso8601String(),
      ),
    );

    return FinanceCollectionResult(
      collectionId: payment.id,
      invoiceId: '',
      studentAccountId: '',
      receiptNumber: payment.receiptNumber,
      amountCollected: payment.amount,
      paymentMethod: payment.mode,
      collectionDate: payment.collectedAt,
      receipt: FinanceReceiptDetail(
        id: payment.id,
        receiptNumber: payment.receiptNumber,
        amount: payment.amount,
        receiptDate: payment.collectedAt,
        collectionId: payment.id,
        invoiceId: '',
        studentAccountId: '',
      ),
      invoice: _store.invoices.first,
    );
  }

  // ── FIN-D3: cancelled register ─────────────────────────────────────────────
  @override
  Future<List<CancelledCollection>> getCancelledCollections({
    required RepositoryQuery query,
  }) async {
    return List<CancelledCollection>.unmodifiable(_cancelledCollections);
  }

  // ── FIN-D5: late-fee accrual + waive ───────────────────────────────────────
  @override
  Future<LateFeeAccrualResult> accrueLateFees({
    required RepositoryQuery query,
  }) async {
    // Demo: accrue a flat 2% on issued/partially-paid invoices with no late fee.
    var count = 0;
    var total = 0.0;
    for (var i = 0; i < _store.invoices.length; i++) {
      final inv = _store.invoices[i];
      if (inv.invoiceStatus != InvoiceStatus.issued &&
          inv.invoiceStatus != InvoiceStatus.partiallyPaid) {
        continue;
      }
      if (inv.hasLateFee) continue;
      final totalAmount =
          double.tryParse(inv.totalAmount.replaceAll(RegExp(r'[^\d.-]'), '')) ??
              0;
      final fee = (totalAmount * 2 / 100);
      if (fee <= 0) continue;
      final newOutstanding =
          (double.tryParse(
                    inv.outstandingAmount.replaceAll(RegExp(r'[^\d.-]'), ''),
                  ) ??
                  0) +
              fee;
      _store.invoices[i] = inv.copyWith(
        lateFeeAmount: fee.toStringAsFixed(2),
        lateFeeAccruedAt: DateTime.now().toIso8601String(),
        outstandingAmount: newOutstanding.toStringAsFixed(2),
      );
      count += 1;
      total += fee;
    }
    return LateFeeAccrualResult(
      accruedCount: count,
      totalLateFee: total.toStringAsFixed(2),
    );
  }

  @override
  Future<FinanceInvoice> waiveLateFee({
    required RepositoryQuery query,
    required String invoiceId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw StateError('A waive reason is required');
    }
    final index = _store.invoices.indexWhere((i) => i.id == invoiceId);
    if (index < 0) {
      throw StateError('Invoice not found: $invoiceId');
    }
    final inv = _store.invoices[index];
    final lateFee =
        double.tryParse(inv.lateFeeAmount.replaceAll(RegExp(r'[^\d.-]'), '')) ??
            0;
    if (lateFee <= 0) {
      throw StateError('Invoice has no late fee to waive: $invoiceId');
    }
    final outstanding =
        (double.tryParse(
                  inv.outstandingAmount.replaceAll(RegExp(r'[^\d.-]'), ''),
                ) ??
                0) -
            lateFee;
    _store.invoices[index] = inv.copyWith(
      lateFeeAmount: '0',
      lateFeeAccruedAt: '',
      outstandingAmount: (outstanding < 0 ? 0 : outstanding).toStringAsFixed(2),
    );
    return _store.invoices[index];
  }

  // ── FIN-D1: day-close lock ─────────────────────────────────────────────────
  @override
  Future<List<DayCloseEntry>> getDayCloseEntries({
    required RepositoryQuery query,
    String? from,
    String? to,
  }) async {
    return List<DayCloseEntry>.unmodifiable(_dayCloseEntries);
  }

  @override
  Future<DayCloseEntry> closeDay({
    required RepositoryQuery query,
    String? date,
  }) async {
    final closeDate =
        (date == null || date.isEmpty) ? _todayIso() : date;
    _dayCloseEntries.removeWhere((e) => e.closeDate == closeDate);
    final entry = DayCloseEntry(
      id: 'dayclose_${_dayCloseSeq++}',
      closeDate: closeDate,
      status: DayCloseStatus.closed,
      closedBy: 'finance_demo',
      closedAt: DateTime.now().toIso8601String(),
      reopenedBy: '',
      reopenedAt: '',
    );
    _dayCloseEntries.insert(0, entry);
    return entry;
  }

  @override
  Future<DayCloseEntry> reopenDay({
    required RepositoryQuery query,
    required String date,
  }) async {
    final index = _dayCloseEntries.indexWhere(
      (e) => e.closeDate == date && e.status == DayCloseStatus.closed,
    );
    if (index < 0) {
      throw StateError('No closed day found for date: $date');
    }
    final prev = _dayCloseEntries[index];
    final reopened = DayCloseEntry(
      id: prev.id,
      closeDate: prev.closeDate,
      status: DayCloseStatus.open,
      closedBy: prev.closedBy,
      closedAt: prev.closedAt,
      reopenedBy: 'finance_demo',
      reopenedAt: DateTime.now().toIso8601String(),
    );
    _dayCloseEntries[index] = reopened;
    return reopened;
  }

  static String _todayIso() => DateTime.now().toIso8601String().substring(0, 10);

  // ── FIN-2: printable student ledger ────────────────────────────────────────
  @override
  Future<StudentLedger> getStudentLedger({
    required RepositoryQuery query,
    required String studentAccountId,
  }) async {
    final account = _store.studentAccounts.firstWhere(
      (a) => a.id == studentAccountId,
      orElse: () => _store.studentAccounts.isNotEmpty
          ? _store.studentAccounts.first
          : throw StateError('Student account not found: $studentAccountId'),
    );
    final invoices = _store.invoices;
    final payments = _store.payments;

    final ledgerInvoices = [
      for (final inv in invoices)
        StudentLedgerInvoice(
          id: inv.id,
          invoiceNumber: inv.invoiceNumber,
          invoiceDate: inv.invoiceDate,
          dueDate: inv.dueDate,
          totalAmount: inv.totalAmount,
          outstandingAmount: inv.outstandingAmount,
          lateFeeAmount: inv.lateFeeAmount,
          status: inv.invoiceStatus.name,
        ),
    ];
    final ledgerPayments = [
      for (final p in payments)
        StudentLedgerPayment(
          id: p.id,
          receiptNumber: p.receiptNumber,
          date: p.collectedAt,
          mode: p.mode,
          amount: p.amount,
          status: p.status.name,
        ),
    ];

    double parse(String v) =>
        double.tryParse(v.replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0;
    var running = 0.0;
    final entries = <StudentLedgerEntry>[];
    for (final inv in ledgerInvoices) {
      running += parse(inv.totalAmount);
      entries.add(
        StudentLedgerEntry(
          date: inv.invoiceDate,
          kind: 'invoice',
          reference: inv.invoiceNumber,
          description: 'Invoice ${inv.invoiceNumber}',
          debit: inv.totalAmount,
          credit: '0',
          balance: running.toStringAsFixed(2),
        ),
      );
    }
    for (final p in ledgerPayments) {
      if (p.status == CollectionStatus.refunded.name) continue;
      running -= parse(p.amount);
      entries.add(
        StudentLedgerEntry(
          date: p.date,
          kind: 'payment',
          reference: p.receiptNumber,
          description: 'Payment ${p.receiptNumber} (${p.mode})',
          debit: '0',
          credit: p.amount,
          balance: running.toStringAsFixed(2),
        ),
      );
    }

    return StudentLedger(
      account: StudentLedgerAccount(
        id: account.id,
        studentId: account.id,
        studentName: account.studentName,
        admissionNumber: account.admissionNumber,
        classLabel: account.classLabel,
        academicYear: '',
        totalDue: account.totalDue,
        totalPaid: account.totalPaid,
        balance: account.balance,
        status: account.status.name,
      ),
      invoices: ledgerInvoices,
      payments: ledgerPayments,
      ledger: entries,
    );
  }

  @override
  Future<OfflinePaymentRecord> recordOfflinePayment({
    required RepositoryQuery query,
    required RecordOfflinePaymentRequest request,
  }) async {
    final record = OfflinePaymentRecord(
      id: _store.nextId('op_'),
      invoiceId: request.invoiceId,
      studentName: request.studentName,
      amount: request.amount,
      method: request.method,
      referenceNumber: request.referenceNumber,
      recordedAt: request.recordedAt,
      status: OfflinePaymentStatus.pendingReconciliation,
      instrumentDate: request.instrumentDate,
      bankName: request.bankName,
    );
    _store.offlinePayments.insert(0, record);
    _store.pendingOfflinePaymentQueue.add(record.id);
    return record;
  }

  @override
  Future<PaginatedResult<OfflinePaymentRecord>> listOfflinePayments({
    required RepositoryQuery query,
  }) async {
    return paginateList(
      List.unmodifiable(_store.offlinePayments),
      query,
    );
  }

  @override
  Future<OfflinePaymentRecord> reconcileOfflinePayment({
    required RepositoryQuery query,
    required String offlinePaymentId,
    required ReconcileOfflinePaymentRequest request,
  }) async {
    final index = _store.offlinePayments
        .indexWhere((item) => item.id == offlinePaymentId);
    if (index < 0) {
      throw StateError('Offline payment not found: $offlinePaymentId');
    }
    final current = _store.offlinePayments[index];
    if (current.status == OfflinePaymentStatus.reconciled) {
      return current;
    }
    // FIN-R7: a bounced (dishonoured) instrument is terminal — cannot reconcile.
    if (current.status == OfflinePaymentStatus.bounced) {
      throw StateError('Offline payment already bounced: $offlinePaymentId');
    }

    final collection = await _createCollectionForOfflinePayment(
      query: query,
      record: current,
      request: request,
    );
    final reconciled = OfflinePaymentRecord(
      id: current.id,
      invoiceId: current.invoiceId,
      studentName: current.studentName,
      amount: current.amount,
      method: current.method,
      referenceNumber: current.referenceNumber,
      recordedAt: request.reconciledAt ?? current.recordedAt,
      status: OfflinePaymentStatus.reconciled,
      collectionId: collection.collectionId,
      instrumentDate: current.instrumentDate,
      bankName: current.bankName,
    );
    _store.offlinePayments[index] = reconciled;
    _store.pendingOfflinePaymentQueue.remove(offlinePaymentId);
    return reconciled;
  }

  @override
  Future<OfflinePaymentRecord> bounceOfflinePayment({
    required RepositoryQuery query,
    required String offlinePaymentId,
    required BounceOfflinePaymentRequest request,
  }) async {
    final index = _store.offlinePayments
        .indexWhere((item) => item.id == offlinePaymentId);
    if (index < 0) {
      throw StateError('Offline payment not found: $offlinePaymentId');
    }
    final current = _store.offlinePayments[index];
    // A cleared instrument cannot be bounced; an already-bounced one is a no-op.
    if (current.status == OfflinePaymentStatus.reconciled) {
      throw StateError('Offline payment already reconciled: $offlinePaymentId');
    }
    if (current.status == OfflinePaymentStatus.bounced) {
      return current;
    }
    // Tracking-only: NO collection is created — a bounce reverses no money.
    final bounced = OfflinePaymentRecord(
      id: current.id,
      invoiceId: current.invoiceId,
      studentName: current.studentName,
      amount: current.amount,
      method: current.method,
      referenceNumber: current.referenceNumber,
      recordedAt: current.recordedAt,
      status: OfflinePaymentStatus.bounced,
      instrumentDate: current.instrumentDate,
      bankName: current.bankName,
      bouncedReason: request.reason,
    );
    _store.offlinePayments[index] = bounced;
    _store.pendingOfflinePaymentQueue.remove(offlinePaymentId);
    return bounced;
  }

  Future<FinanceCollectionResult> _createCollectionForOfflinePayment({
    required RepositoryQuery query,
    required OfflinePaymentRecord record,
    required ReconcileOfflinePaymentRequest request,
  }) {
    return createCollection(
      query: query,
      request: CreateCollectionRequest(
        invoiceId: record.invoiceId,
        amountCollected: record.amount,
        paymentMethod: switch (record.method) {
          OfflinePaymentMethod.cash => 'Cash',
          OfflinePaymentMethod.cheque => 'Cheque',
          OfflinePaymentMethod.dd => 'Demand Draft',
          OfflinePaymentMethod.pdc => 'Post-Dated Cheque',
        },
        referenceNumber: record.referenceNumber,
        notes: request.notes,
        collectionDate: request.reconciledAt ?? record.recordedAt,
      ),
    );
  }

  @override
  Future<DefaultersDashboardData> getDefaultersDashboard(
      {required RepositoryQuery query}) async {
    return const DefaultersDashboardData(
      kpis: [
        FinanceKpi(
          id: 'total_overdue',
          value: '₹18.6L',
          label: 'Total overdue',
          icon: Icons.warning_amber_outlined,
          accentName: 'error',
        ),
        FinanceKpi(
          id: 'defaulter_count',
          value: '47',
          label: 'Defaulters',
          icon: Icons.people_outline,
          accentName: 'warning',
        ),
        FinanceKpi(
          id: 'critical',
          value: '12',
          label: 'Critical (>60d)',
          icon: Icons.priority_high,
          accentName: 'error',
        ),
        FinanceKpi(
          id: 'followups',
          value: '8',
          label: 'Follow-ups today',
          icon: Icons.phone_in_talk_outlined,
          accentName: 'primary',
        ),
      ],
      agingBuckets: [
        AgingBucketSummary(
          bucket: DefaulterAgingBucket.current,
          label: 'Current',
          studentCount: 12,
          totalAmount: '₹2.1L',
        ),
        AgingBucketSummary(
          bucket: DefaulterAgingBucket.days1to30,
          label: '1–30 days',
          studentCount: 18,
          totalAmount: '₹4.8L',
        ),
        AgingBucketSummary(
          bucket: DefaulterAgingBucket.days31to60,
          label: '31–60 days',
          studentCount: 9,
          totalAmount: '₹5.2L',
        ),
        AgingBucketSummary(
          bucket: DefaulterAgingBucket.days61to90,
          label: '61–90 days',
          studentCount: 5,
          totalAmount: '₹3.5L',
        ),
        AgingBucketSummary(
          bucket: DefaulterAgingBucket.over90,
          label: '90+ days',
          studentCount: 3,
          totalAmount: '₹3.0L',
        ),
      ],
      defaulters: [
        DefaulterRecord(
          id: 'def_1',
          studentName: 'Priya Sharma',
          admissionNumber: 'ADM-2025-0092',
          classLabel: '8',
          overdueAmount: '₹65,000',
          daysOverdue: 45,
          bucket: DefaulterAgingBucket.days31to60,
          lastContact: '12 May · WhatsApp',
          collectionProbability: 62,
          feeAccountId: 'acct_4',
          guardianPhone: '9876500092',
          contactHistory: [
            ContactHistoryEntry(
              id: 'ch_1',
              timestamp: '12 May · 4:30 PM',
              channel: 'WhatsApp',
              outcome: 'No response',
              notes: 'Sent payment reminder with UPI link (PA-10).',
            ),
            ContactHistoryEntry(
              id: 'ch_2',
              timestamp: '28 Apr · 11:00 AM',
              channel: 'Phone',
              outcome: 'Promised by 5 May',
              notes: 'Parent requested extension for medical expenses.',
            ),
          ],
        ),
        DefaulterRecord(
          id: 'def_2',
          studentName: 'Ananya Reddy',
          admissionNumber: 'ADM-2026-0142',
          classLabel: '5',
          overdueAmount: '₹71,667',
          daysOverdue: 15,
          bucket: DefaulterAgingBucket.days1to30,
          lastContact: '3 Jun · Email',
          collectionProbability: 78,
          feeAccountId: 'acct_2',
          guardianPhone: '9876500142',
          contactHistory: [
            ContactHistoryEntry(
              id: 'ch_3',
              timestamp: '3 Jun · 9:00 AM',
              channel: 'Email',
              outcome: 'Opened',
              notes:
                  'New admission — first installment pending after AD-08 handoff.',
            ),
          ],
        ),
        DefaulterRecord(
          id: 'def_3',
          studentName: 'Kavya Iyer',
          admissionNumber: 'ADM-2025-0101',
          classLabel: '6',
          overdueAmount: '₹52,000',
          daysOverdue: 92,
          bucket: DefaulterAgingBucket.over90,
          lastContact: '20 May · Phone',
          collectionProbability: 34,
          feeAccountId: 'acct_5',
          guardianPhone: '9876500101',
          contactHistory: [
            ContactHistoryEntry(
              id: 'ch_4',
              timestamp: '20 May · 2:00 PM',
              channel: 'Phone',
              outcome: 'Unreachable',
              notes: 'Escalated to management review.',
            ),
          ],
        ),
      ],
      aiInsight:
          'Class 8 defaulters rose 22% this month. Prioritize WhatsApp reminders for 31–60 day bucket — 78% open rate vs 41% for email.',
      aiActionLabel: 'Send bulk reminders',
    );
  }

  @override
  Future<PaginatedResult<RefundRequest>> getRefundRequests({
    required RepositoryQuery query,
  }) async =>
      PaginatedResult.fromItems(
        List.unmodifiable(_store.refundRequests),
        page: query.page,
        pageSize: query.pageSize,
      );

  @override
  Future<RefundRequest?> getRefund({
    required RepositoryQuery query,
    required String refundId,
  }) async {
    for (final refund in _store.refundRequests) {
      if (refund.id == refundId) return refund;
    }
    return null;
  }

  @override
  Future<DiscountsDashboardData> getDiscountsDashboard({
    required RepositoryQuery query,
  }) async {
    return _store.discountsDashboard;
  }

  // ── STEP-5: fee reductions (scholarship awards + discount applications) ───
  // In-memory mirror of finance_fee_reductions_{repository,handlers}.ts: a
  // reduction is born `pending` (no money moves); only [approveFeeReduction]
  // (mirroring the real backend's checker step) reduces the invoice's
  // outstanding + the linked student account's balance, in lockstep — the same
  // simplification `_applyRefundReversal` above uses (outstanding + status
  // only; this mock never modelled `totalAmount`/`discountAmount` deltas).
  @override
  Future<List<FeeReduction>> listFeeReductions({
    required RepositoryQuery query,
    FeeReductionStatus? status,
    String? invoiceId,
    String? studentId,
    FeeReductionSourceKind? sourceKind,
  }) async {
    return _store.feeReductions.where((r) {
      if (status != null && r.status != status) return false;
      if (invoiceId != null && invoiceId.isNotEmpty && r.invoiceId != invoiceId) {
        return false;
      }
      if (studentId != null && studentId.isNotEmpty && r.studentId != studentId) {
        return false;
      }
      if (sourceKind != null && r.sourceKind != sourceKind) return false;
      return true;
    }).toList(growable: false);
  }

  @override
  Future<FeeReduction> proposeScholarshipAward({
    required RepositoryQuery query,
    required String scholarshipId,
    required String invoiceId,
    required String reason,
    double? percent,
    double? amount,
  }) {
    if (!_store.scholarships.any((s) => s.id == scholarshipId)) {
      throw StateError('Scholarship not found: $scholarshipId');
    }
    return _proposeFeeReduction(
      sourceKind: FeeReductionSourceKind.scholarship,
      sourceId: scholarshipId,
      invoiceId: invoiceId,
      reason: reason,
      percent: percent,
      amount: amount,
    );
  }

  @override
  Future<FeeReduction> proposeDiscountApplication({
    required RepositoryQuery query,
    required String discountRuleId,
    required String invoiceId,
    required String reason,
    double? percent,
    double? amount,
  }) {
    if (!_store.discountRules.any((r) => r.id == discountRuleId)) {
      throw StateError('Discount rule not found: $discountRuleId');
    }
    return _proposeFeeReduction(
      sourceKind: FeeReductionSourceKind.discount,
      sourceId: discountRuleId,
      invoiceId: invoiceId,
      reason: reason,
      percent: percent,
      amount: amount,
    );
  }

  Future<FeeReduction> _proposeFeeReduction({
    required FeeReductionSourceKind sourceKind,
    required String sourceId,
    required String invoiceId,
    required String reason,
    double? percent,
    double? amount,
  }) async {
    final invoice = _store.invoices.cast<FinanceInvoice?>().firstWhere(
          (item) => item?.id == invoiceId,
          orElse: () => null,
        );
    if (invoice == null) {
      throw StateError('Invoice not found: $invoiceId');
    }
    if (invoice.invoiceStatus == InvoiceStatus.cancelled) {
      throw StateError('Cannot reduce a cancelled invoice');
    }
    if ((percent == null) == (amount == null)) {
      throw StateError('Send exactly one of percent or amount');
    }
    final account = _store.studentAccounts.cast<StudentFeeAccount?>().firstWhere(
          (item) =>
              item?.feeAssignmentId != null &&
              item!.feeAssignmentId == invoice.feeAssignmentId,
          orElse: () => null,
        );
    final reduction = FeeReduction(
      id: _store.nextId('fred_'),
      sourceKind: sourceKind,
      scholarshipId: sourceKind == FeeReductionSourceKind.scholarship ? sourceId : '',
      discountRuleId: sourceKind == FeeReductionSourceKind.discount ? sourceId : '',
      studentId: invoice.studentId,
      invoiceId: invoice.id,
      studentAccountId: account?.id ?? '',
      reductionKind:
          percent != null ? FeeReductionKind.percent : FeeReductionKind.fixed,
      percent: percent != null ? _plainNumber(percent) : '',
      fixedAmount: amount != null ? _plainNumber(amount) : '',
      status: FeeReductionStatus.pending,
      reason: reason,
      createdBy: 'finance_demo',
      createdAt: 'Today',
      updatedAt: 'Today',
    );
    _store.feeReductions.insert(0, reduction);
    return reduction;
  }

  @override
  Future<FeeReduction> approveFeeReduction({
    required RepositoryQuery query,
    required String reductionId,
  }) async {
    final index = _store.feeReductions.indexWhere((r) => r.id == reductionId);
    if (index < 0) throw StateError('Fee reduction not found: $reductionId');
    final current = _store.feeReductions[index];
    if (current.status != FeeReductionStatus.pending) {
      throw StateError(
          'Cannot approve fee reduction in status: ${current.status.name}');
    }

    final applied = _applyFeeReductionDelta(current, reverse: false);

    final updated = current.copyWith(
      status: FeeReductionStatus.approved,
      appliedAmount: _plainNumber(applied),
      approvedBy: 'finance_checker',
      appliedAt: 'Today',
      updatedAt: 'Today',
    );
    _store.feeReductions[index] = updated;
    return updated;
  }

  @override
  Future<FeeReduction> rejectFeeReduction({
    required RepositoryQuery query,
    required String reductionId,
  }) async {
    final index = _store.feeReductions.indexWhere((r) => r.id == reductionId);
    if (index < 0) throw StateError('Fee reduction not found: $reductionId');
    final current = _store.feeReductions[index];
    if (current.status != FeeReductionStatus.pending) {
      throw StateError(
          'Cannot reject fee reduction in status: ${current.status.name}');
    }
    final updated = current.copyWith(
      status: FeeReductionStatus.rejected,
      approvedBy: 'finance_checker',
      updatedAt: 'Today',
    );
    _store.feeReductions[index] = updated;
    return updated;
  }

  @override
  Future<FeeReduction> reverseFeeReduction({
    required RepositoryQuery query,
    required String reductionId,
  }) async {
    final index = _store.feeReductions.indexWhere((r) => r.id == reductionId);
    if (index < 0) throw StateError('Fee reduction not found: $reductionId');
    final current = _store.feeReductions[index];
    if (current.status != FeeReductionStatus.approved) {
      throw StateError(
          'Cannot reverse fee reduction in status: ${current.status.name}');
    }

    _applyFeeReductionDelta(current, reverse: true);

    final updated = current.copyWith(
      status: FeeReductionStatus.reversed,
      reversedBy: 'finance_checker',
      reversedAt: 'Today',
      updatedAt: 'Today',
    );
    _store.feeReductions[index] = updated;
    return updated;
  }

  /// Applies (or reverses) `reduction`'s money effect on the linked invoice +
  /// student account, in lockstep — mirrors [_applyRefundReversal]. Returns the
  /// clamped amount actually applied (only meaningful on the forward path).
  double _applyFeeReductionDelta(FeeReduction reduction, {required bool reverse}) {
    final invoiceIndex =
        _store.invoices.indexWhere((item) => item.id == reduction.invoiceId);
    if (invoiceIndex < 0) return _parseFinanceAmount(reduction.appliedAmount);

    final invoice = _store.invoices[invoiceIndex];
    final outstanding = _parseFinanceAmount(invoice.outstandingAmount);
    final total = _parseFinanceAmount(invoice.totalAmount);
    final subtotal = _parseFinanceAmount(invoice.subtotalAmount);

    final applied = reverse
        ? _parseFinanceAmount(reduction.appliedAmount)
        : (reduction.reductionKind == FeeReductionKind.fixed
                ? _parseFinanceAmount(reduction.fixedAmount)
                : subtotal * (_parseFinanceAmount(reduction.percent) / 100))
            .clamp(0, outstanding)
            .clamp(0, total)
            .toDouble();
    if (applied <= 0) return applied;

    final newOutstanding = reverse ? outstanding + applied : outstanding - applied;
    final clampedOutstanding = newOutstanding.clamp(0, double.infinity).toDouble();
    final newStatus = clampedOutstanding <= 0
        ? InvoiceStatus.paid
        : (clampedOutstanding < total
            ? InvoiceStatus.partiallyPaid
            : InvoiceStatus.issued);
    _store.invoices[invoiceIndex] = invoice.copyWith(
      outstandingAmount: clampedOutstanding.toStringAsFixed(0),
      invoiceStatus: newStatus,
    );

    final accountIndex = _store.studentAccounts.indexWhere(
      (item) => item.id == reduction.studentAccountId,
    );
    if (accountIndex >= 0) {
      final account = _store.studentAccounts[accountIndex];
      final balance = _parseFinanceAmount(account.balance);
      final totalDue = _parseFinanceAmount(account.totalDue);
      final newBalance = (reverse ? balance + applied : balance - applied)
          .clamp(0, double.infinity)
          .toDouble();
      final newTotalDue = (reverse ? totalDue + applied : totalDue - applied)
          .clamp(0, double.infinity)
          .toDouble();
      _store.studentAccounts[accountIndex] = StudentFeeAccount(
        id: account.id,
        studentName: account.studentName,
        admissionNumber: account.admissionNumber,
        classLabel: account.classLabel,
        feeStructureName: account.feeStructureName,
        totalDue: _formatFinanceAmount(newTotalDue),
        totalPaid: account.totalPaid,
        balance: _formatFinanceAmount(newBalance),
        status: account.status,
        lastPaymentDate: account.lastPaymentDate,
        installmentPlan: account.installmentPlan,
        feeAssignmentId: account.feeAssignmentId,
      );
    }

    return applied;
  }

  @override
  Future<FinanceReportsData> getReportsData(
      {required RepositoryQuery query}) async {
    return const FinanceReportsData(
      selectedReportId: 'rpt_collection',
      catalog: [
        FinanceReportCatalogItem(
          id: 'rpt_collection',
          title: 'Collection Report',
          description: 'Daily and monthly fee collection summary',
          type: FinanceReportType.collection,
          lastGenerated: '5 Jun 2026',
        ),
        FinanceReportCatalogItem(
          id: 'rpt_outstanding',
          title: 'Outstanding Report',
          description: 'Class-wise outstanding and aging analysis',
          type: FinanceReportType.outstanding,
          lastGenerated: '4 Jun 2026',
        ),
        FinanceReportCatalogItem(
          id: 'rpt_discount',
          title: 'Discount Report',
          description: 'Scholarship and discount impact analysis',
          type: FinanceReportType.discount,
          lastGenerated: '1 Jun 2026',
        ),
        FinanceReportCatalogItem(
          id: 'rpt_refund',
          title: 'Refund Report',
          description: 'Refund requests and processing status',
          type: FinanceReportType.refund,
          lastGenerated: '3 Jun 2026',
        ),
      ],
      collectionTrend: [
        FinanceReportTrendPoint(label: 'Jan', value: 6.2, target: 7.0),
        FinanceReportTrendPoint(label: 'Feb', value: 7.8, target: 7.0),
        FinanceReportTrendPoint(label: 'Mar', value: 8.4, target: 8.0),
        FinanceReportTrendPoint(label: 'Apr', value: 9.1, target: 8.5),
        FinanceReportTrendPoint(label: 'May', value: 10.5, target: 9.0),
        FinanceReportTrendPoint(label: 'Jun', value: 11.2, target: 10.0),
      ],
      outstandingTrend: [
        FinanceReportTrendPoint(label: 'Jan', value: 22.0, target: 20.0),
        FinanceReportTrendPoint(label: 'Feb', value: 21.2, target: 19.0),
        FinanceReportTrendPoint(label: 'Mar', value: 20.5, target: 18.0),
        FinanceReportTrendPoint(label: 'Apr', value: 19.8, target: 17.0),
        FinanceReportTrendPoint(label: 'May', value: 18.9, target: 16.0),
        FinanceReportTrendPoint(label: 'Jun', value: 18.6, target: 15.0),
      ],
    );
  }

  @override
  Future<FinanceSettingsData> getSettings({
    required RepositoryQuery query,
  }) async {
    return _store.settings;
  }

  @override
  Future<FinanceFeeStructure> createFeeStructure({
    required RepositoryQuery query,
    required CreateFeeStructureRequest request,
  }) async {
    final structure = FinanceFeeStructure(
      id: _store.nextId('fee_'),
      name: request.name,
      academicYear: request.academicYear,
      totalAnnual: request.totalAnnual,
      classRange: request.classRange,
      categories: request.categories,
      status: request.status,
      installmentOptions: request.installmentOptions,
      // Cap 67 — real class/section binding; mock has no separate class/
      // section catalog to resolve a label against, so a label-only request
      // is stored as-is (best-effort demo continuity — the real backend does
      // the authoritative id-or-label resolution).
      classId: request.classId,
      className: request.className,
      sectionId: request.sectionId,
      sectionName: request.sectionName,
    );
    _store.feeStructures.insert(0, structure);
    return structure;
  }

  @override
  Future<FinanceFeeStructure> updateFeeStructure({
    required RepositoryQuery query,
    required String feeStructureId,
    required UpdateFeeStructureRequest request,
  }) async {
    final index =
        _store.feeStructures.indexWhere((item) => item.id == feeStructureId);
    if (index < 0) throw StateError('Fee structure not found: $feeStructureId');
    final current = _store.feeStructures[index];
    // Cap 67 — same "undefined on all four = unchanged, unbindClass = clear"
    // contract as the real backend's updateFeeStructure.
    final bindingProvided = request.classId != null ||
        request.className != null ||
        request.sectionId != null ||
        request.sectionName != null;
    final classId = request.unbindClass
        ? null
        : (bindingProvided ? request.classId : current.classId);
    final className = request.unbindClass
        ? null
        : (bindingProvided ? request.className : current.className);
    final sectionId = request.unbindClass
        ? null
        : (bindingProvided ? request.sectionId : current.sectionId);
    final sectionName = request.unbindClass
        ? null
        : (bindingProvided ? request.sectionName : current.sectionName);
    final updated = FinanceFeeStructure(
      id: current.id,
      name: request.name ?? current.name,
      academicYear: request.academicYear ?? current.academicYear,
      totalAnnual: request.totalAnnual ?? current.totalAnnual,
      classRange: request.classRange ?? current.classRange,
      categories: request.categories ?? current.categories,
      status: request.status ?? current.status,
      installmentOptions:
          request.installmentOptions ?? current.installmentOptions,
      classId: classId,
      className: className,
      sectionId: sectionId,
      sectionName: sectionName,
    );
    _store.feeStructures[index] = updated;
    return updated;
  }

  // #6 — soft-retire (status → inactive); mirrors updateFeeStructure's store
  // mutation, same as the real backend's archiveFeeStructure which is itself
  // just updateFeeStructure({status: 'inactive'}).
  @override
  Future<FinanceFeeStructure> archiveFeeStructure({
    required RepositoryQuery query,
    required String feeStructureId,
  }) {
    return updateFeeStructure(
      query: query,
      feeStructureId: feeStructureId,
      request: const UpdateFeeStructureRequest(status: FeeStructureStatus.inactive),
    );
  }

  @override
  Future<StudentFeeAccount> createStudentAccount({
    required RepositoryQuery query,
    required CreateStudentAccountRequest request,
  }) async {
    final structure = _store.findFeeStructure(request.feeStructureId);
    final planLabel = request.installmentPlanLabel.isNotEmpty
        ? request.installmentPlanLabel
        : _store.planLabel(request.installmentPlanId);
    final totalDue =
        request.totalDue.isNotEmpty ? request.totalDue : structure.totalAnnual;
    final accountId = _store.nextId('acct_');
    final account = StudentFeeAccount(
      id: accountId,
      studentName: request.studentName,
      admissionNumber: request.admissionNumber,
      classLabel: request.classLabel,
      feeStructureName: structure.name,
      totalDue: totalDue,
      totalPaid: '₹0',
      balance: totalDue,
      status: FeeAccountStatus.pending,
      lastPaymentDate: '—',
      installmentPlan: planLabel,
      // Mock has no separate assignment row — the account IS the assignment
      // (see _syncInvoiceForFeeAccount's `feeAssignmentId: account.id`), so
      // self-reference keeps cancelFeeAssignment targetable in mock mode too.
      feeAssignmentId: accountId,
    );
    _store.studentAccounts.insert(0, account);
    return account;
  }

  @override
  Future<StudentFeeAccount> updateStudentAccount({
    required RepositoryQuery query,
    required String accountId,
    required UpdateStudentAccountRequest request,
  }) async {
    final index =
        _store.studentAccounts.indexWhere((item) => item.id == accountId);
    if (index < 0) throw StateError('Student account not found: $accountId');
    final current = _store.studentAccounts[index];
    final structureName = request.feeStructureId != null
        ? _store.findFeeStructure(request.feeStructureId!).name
        : current.feeStructureName;
    final planLabel = request.installmentPlanId != null
        ? (request.installmentPlanLabel ??
            _store.planLabel(request.installmentPlanId!))
        : current.installmentPlan;
    final updated = StudentFeeAccount(
      id: current.id,
      studentName: current.studentName,
      admissionNumber: current.admissionNumber,
      classLabel: current.classLabel,
      feeStructureName: structureName,
      totalDue: request.totalDue ?? current.totalDue,
      totalPaid: request.totalPaid ?? current.totalPaid,
      balance: request.balance ?? current.balance,
      status: request.status ?? current.status,
      lastPaymentDate: current.lastPaymentDate,
      installmentPlan: planLabel,
      feeAssignmentId: current.feeAssignmentId,
    );
    _store.studentAccounts[index] = updated;
    return updated;
  }

  @override
  Future<StudentFeeAccount> assignFeePlan({
    required RepositoryQuery query,
    required AssignFeePlanRequest request,
  }) async {
    final structure = _store.findFeeStructure(request.feeStructureId);
    final proration = _computeMockProration(
      structure: structure,
      admissionDate: request.admissionDate,
      prorationPolicyOverride: request.prorationPolicyOverride,
      prorationOverrideReason: request.prorationOverrideReason,
    );
    final account = await createStudentAccount(
      query: query,
      request: CreateStudentAccountRequest(
        studentName: request.studentName,
        admissionNumber: request.admissionNumber,
        classLabel: request.classLabel,
        feeStructureId: request.feeStructureId,
        installmentPlanId: request.installmentPlanId,
        totalDue: _formatFinanceAmount(proration.chargedAmount),
        installmentPlanLabel: _store.planLabel(request.installmentPlanId),
      ),
    );
    final withProration = _attachProration(account, proration);
    _replaceStoredAccount(withProration);
    _syncInvoiceForFeeAccount(withProration);
    return withProration;
  }

  /// Cap 73 (owner decision #5) — mock-mode mid-year admission proration.
  /// Uses the SAME month-basis calculation as the real backend
  /// (finance_fee_proration.dart mirrors finance_fee_proration.ts exactly),
  /// but has no real academic-years catalog to resolve bounds from — it
  /// derives an April-start window from the structure's `academicYear` label
  /// (best-effort, demo-only; falls back to full_annual, same as the server,
  /// when that can't be parsed). Mock has no finance_settings-equivalent
  /// wiring for ANY other setting either, so — unlike the real backend —
  /// there is no "school-configured default" here: proration only ever
  /// applies via an explicit per-call override, otherwise full_annual.
  FeeProrationResult _computeMockProration({
    required FinanceFeeStructure structure,
    required String? admissionDate,
    required FeeProrationPolicy? prorationPolicyOverride,
    required String? prorationOverrideReason,
  }) {
    if (prorationPolicyOverride != null &&
        (prorationOverrideReason == null ||
            prorationOverrideReason.trim().isEmpty)) {
      throw FeeProrationOverrideReasonRequiredError();
    }
    final policy = prorationPolicyOverride ?? FeeProrationPolicy.fullAnnual;
    final referenceDate =
        (admissionDate != null && admissionDate.isNotEmpty)
            ? admissionDate
            : DateTime.now().toIso8601String().substring(0, 10);
    return computeFeeProration(
      policy: policy,
      annualAmount: _parseFinanceAmount(structure.totalAnnual),
      referenceDate: referenceDate,
      yearBounds: deriveAprilStartYearBounds(structure.academicYear),
      isOverride: prorationPolicyOverride != null,
      overrideReason: prorationOverrideReason,
    );
  }

  FeeProrationInfo _toProrationInfo(FeeProrationResult result) {
    return FeeProrationInfo(
      policy: result.policy,
      basis: 'month',
      totalMonths: result.totalMonths,
      monthsCharged: result.monthsCharged,
      referenceDate: result.referenceDate,
      annualAmount: _formatFinanceAmount(result.annualAmount),
      chargedAmount: _formatFinanceAmount(result.chargedAmount),
      isOverride: result.isOverride,
      fallbackReason: result.fallbackReason,
      overrideReason: result.overrideReason,
    );
  }

  StudentFeeAccount _attachProration(
    StudentFeeAccount account,
    FeeProrationResult proration,
  ) {
    return StudentFeeAccount(
      id: account.id,
      studentName: account.studentName,
      admissionNumber: account.admissionNumber,
      classLabel: account.classLabel,
      feeStructureName: account.feeStructureName,
      totalDue: account.totalDue,
      totalPaid: account.totalPaid,
      balance: account.balance,
      status: account.status,
      lastPaymentDate: account.lastPaymentDate,
      installmentPlan: account.installmentPlan,
      feeAssignmentId: account.feeAssignmentId,
      proration: _toProrationInfo(proration),
    );
  }

  void _replaceStoredAccount(StudentFeeAccount account) {
    final idx = _store.studentAccounts.indexWhere((a) => a.id == account.id);
    if (idx >= 0) _store.studentAccounts[idx] = account;
  }

  // PRC-A gap fix — bulk/class-wide fee-structure assignment. The mock has no
  // per-student-id-keyed account row (accounts are display-string based, not
  // UUID-joined to a real student), so duplicate detection here is a local
  // (studentId, feeStructureId, academicYear) set rather than a real DB
  // lookup — good enough for offline/demo continuity. The important,
  // certified skip-a-duplicate/abort-on-real-error semantics live server-side
  // and are proven in finance_assignments_repository_test.ts.
  //
  // Cap 67 — the real API auto-resolves an empty studentIds[] from the fee
  // structure's class/section binding; the mock has no separate SIS roster
  // to resolve against here, so an empty list is a clear, explicit error
  // rather than a silent no-op — the app's own bulk-assign screen always
  // resolves and sends a concrete list before calling this (see
  // finance_bulk_assign_dialog.dart), so this path isn't exercised in
  // practice, only guarded against.
  @override
  Future<BulkFeeAssignmentResult> bulkAssignFeeStructure({
    required RepositoryQuery query,
    required BulkAssignFeePlanRequest request,
  }) async {
    if (request.studentIds.isEmpty) {
      throw StateError(
        'Bulk assign requires an explicit student list in mock/offline mode',
      );
    }
    final structure = _store.findFeeStructure(request.feeStructureId);
    final proration = _computeMockProration(
      structure: structure,
      admissionDate: request.admissionDate,
      prorationPolicyOverride: request.prorationPolicyOverride,
      prorationOverrideReason: request.prorationOverrideReason,
    );
    final chargedAmountLabel = _formatFinanceAmount(proration.chargedAmount);
    final assigned = <StudentFeeAccount>[];
    final skipped = <BulkFeeAssignmentSkip>[];

    for (final studentId in request.studentIds) {
      final key =
          '$studentId|${request.feeStructureId}|${request.academicYear}';
      if (!_bulkAssignedKeys.add(key)) {
        skipped.add(
          BulkFeeAssignmentSkip(
            studentId: studentId,
            reason: 'already_assigned',
          ),
        );
        continue;
      }
      final accountId = _store.nextId('acct_');
      final account = StudentFeeAccount(
        id: accountId,
        studentName: 'Student $studentId',
        admissionNumber: studentId,
        classLabel: '',
        feeStructureName: structure.name,
        totalDue: chargedAmountLabel,
        totalPaid: '₹0',
        balance: chargedAmountLabel,
        status: FeeAccountStatus.pending,
        lastPaymentDate: '—',
        installmentPlan: '',
        feeAssignmentId: accountId,
        proration: _toProrationInfo(proration),
      );
      _store.studentAccounts.insert(0, account);
      _syncInvoiceForFeeAccount(account);
      assigned.add(account);
    }

    return BulkFeeAssignmentResult(
      assigned: assigned,
      skipped: skipped,
      total: request.studentIds.length,
    );
  }

  // #6 — mirrors the real cancelAssignment: closes the account (mock has no
  // separate assignment row, so feeAssignmentId == account.id here).
  @override
  Future<StudentFeeAccount> cancelFeeAssignment({
    required RepositoryQuery query,
    required String feeAssignmentId,
  }) async {
    final index = _store.studentAccounts.indexWhere(
      (item) => item.id == feeAssignmentId ||
          item.feeAssignmentId == feeAssignmentId,
    );
    if (index < 0) {
      throw StateError('Fee assignment not found: $feeAssignmentId');
    }
    final current = _store.studentAccounts[index];
    final updated = StudentFeeAccount(
      id: current.id,
      studentName: current.studentName,
      admissionNumber: current.admissionNumber,
      classLabel: current.classLabel,
      feeStructureName: current.feeStructureName,
      totalDue: current.totalDue,
      totalPaid: current.totalPaid,
      balance: current.balance,
      status: FeeAccountStatus.closed,
      lastPaymentDate: current.lastPaymentDate,
      installmentPlan: current.installmentPlan,
      feeAssignmentId: current.feeAssignmentId,
    );
    _store.studentAccounts[index] = updated;
    return updated;
  }

  void _syncInvoiceForFeeAccount(StudentFeeAccount account) {
    final numericTotal = account.totalDue.replaceAll(RegExp(r'[₹,\s]'), '');
    final invoiceId = _store.nextId('inv_');
    _store.invoices.insert(
      0,
      FinanceInvoice(
        id: invoiceId,
        studentId: account.id,
        feeAssignmentId: account.id,
        academicYear: '2026-27',
        invoiceNumber:
            'INV-2026-${account.admissionNumber.replaceAll(RegExp(r'[^A-Z0-9]'), '')}',
        invoiceDate: '2026-06-10',
        dueDate: '2026-07-10',
        subtotalAmount: numericTotal,
        discountAmount: '0',
        totalAmount: numericTotal,
        outstandingAmount: numericTotal,
        paidAmount: '0',
        invoiceStatus: InvoiceStatus.issued,
        termLabel: account.installmentPlan,
        createdBy: 'finance_staff',
        createdAt: '2026-06-10T00:00:00.000Z',
        updatedAt: '2026-06-10T00:00:00.000Z',
      ),
    );
    _store.invoiceIdByFeeAccountId[account.id] = invoiceId;
  }

  @override
  Future<RefundRequest> createRefund({
    required RepositoryQuery query,
    required CreateRefundRequest request,
  }) async {
    final account = _store.findStudentAccount(request.feeAccountId);
    final refund = RefundRequest(
      id: _store.nextId('ref_'),
      studentName: request.studentName.isNotEmpty
          ? request.studentName
          : account.studentName,
      admissionNumber: request.admissionNumber.isNotEmpty
          ? request.admissionNumber
          : account.admissionNumber,
      classLabel: request.classLabel.isNotEmpty
          ? request.classLabel
          : account.classLabel,
      amount: request.amount,
      reason: request.reason,
      requestedAt: 'Today',
      status: RefundStatus.pending,
      approver: 'Finance Manager',
      feeAccountId: request.feeAccountId,
      originalReceipt: request.originalReceipt,
      collectionId: request.collectionId,
      invoiceId: '',
    );
    _store.refundRequests.insert(0, refund);
    return refund;
  }

  @override
  Future<RefundRequest> approveRefund({
    required RepositoryQuery query,
    required String refundId,
    ApproveRefundRequest request = const ApproveRefundRequest(),
  }) async {
    final index =
        _store.refundRequests.indexWhere((item) => item.id == refundId);
    if (index < 0) throw StateError('Refund not found: $refundId');
    final current = _store.refundRequests[index];
    if (current.status != RefundStatus.pending) {
      throw StateError(
          'Cannot approve refund in status: ${current.status.name}');
    }

    final refundAmount = _parseFinanceAmount(current.amount);
    _applyRefundReversal(current, refundAmount);

    final updated = RefundRequest(
      id: current.id,
      studentName: current.studentName,
      admissionNumber: current.admissionNumber,
      classLabel: current.classLabel,
      amount: current.amount,
      reason: current.reason,
      requestedAt: current.requestedAt,
      status: RefundStatus.processed,
      approver: request.approver,
      feeAccountId: current.feeAccountId,
      originalReceipt: current.originalReceipt,
      collectionId: current.collectionId,
      invoiceId: current.invoiceId,
    );
    _store.refundRequests[index] = updated;
    return updated;
  }

  @override
  Future<RefundRequest> rejectRefund({
    required RepositoryQuery query,
    required String refundId,
  }) async {
    final index =
        _store.refundRequests.indexWhere((item) => item.id == refundId);
    if (index < 0) throw StateError('Refund not found: $refundId');
    final current = _store.refundRequests[index];
    final updated = RefundRequest(
      id: current.id,
      studentName: current.studentName,
      admissionNumber: current.admissionNumber,
      classLabel: current.classLabel,
      amount: current.amount,
      reason: current.reason,
      requestedAt: current.requestedAt,
      status: RefundStatus.rejected,
      approver: current.approver,
      feeAccountId: current.feeAccountId,
      originalReceipt: current.originalReceipt,
      collectionId: current.collectionId,
      invoiceId: current.invoiceId,
    );
    _store.refundRequests[index] = updated;
    return updated;
  }

  void _applyRefundReversal(RefundRequest refund, double refundAmount) {
    if (refundAmount <= 0) return;

    final collectionIndex = refund.collectionId.isNotEmpty
        ? _store.payments.indexWhere((item) => item.id == refund.collectionId)
        : _store.payments.indexWhere(
            (item) => item.receiptNumber == refund.originalReceipt,
          );
    if (collectionIndex >= 0) {
      final payment = _store.payments[collectionIndex];
      if (payment.status != CollectionStatus.refunded) {
        final collectionAmount = _parseFinanceAmount(payment.amount);
        _store.payments[collectionIndex] = CollectionPayment(
          id: payment.id,
          receiptNumber: payment.receiptNumber,
          studentName: payment.studentName,
          admissionNumber: payment.admissionNumber,
          amount: payment.amount,
          mode: payment.mode,
          collectedAt: payment.collectedAt,
          collectedBy: payment.collectedBy,
          status: refundAmount >= collectionAmount
              ? CollectionStatus.refunded
              : payment.status,
          classLabel: payment.classLabel,
        );
      }
    }

    if (refund.invoiceId.isNotEmpty) {
      final invoiceIndex =
          _store.invoices.indexWhere((item) => item.id == refund.invoiceId);
      if (invoiceIndex >= 0) {
        final invoice = _store.invoices[invoiceIndex];
        final outstanding =
            _parseFinanceAmount(invoice.outstandingAmount) + refundAmount;
        final total = _parseFinanceAmount(invoice.totalAmount);
        final newStatus = outstanding <= 0
            ? InvoiceStatus.paid
            : (outstanding < total
                ? InvoiceStatus.partiallyPaid
                : InvoiceStatus.issued);
        _store.invoices[invoiceIndex] = invoice.copyWith(
          outstandingAmount: outstanding.toStringAsFixed(0),
          invoiceStatus: newStatus,
        );
      }
    }

    final accountIndex = _store.studentAccounts.indexWhere(
      (item) => item.id == refund.feeAccountId,
    );
    if (accountIndex >= 0) {
      final account = _store.studentAccounts[accountIndex];
      final paid = _parseFinanceAmount(account.totalPaid) - refundAmount;
      final balance = _parseFinanceAmount(account.balance) + refundAmount;
      _store.studentAccounts[accountIndex] = StudentFeeAccount(
        id: account.id,
        studentName: account.studentName,
        admissionNumber: account.admissionNumber,
        classLabel: account.classLabel,
        feeStructureName: account.feeStructureName,
        totalDue: account.totalDue,
        totalPaid: _formatFinanceAmount(paid),
        balance: _formatFinanceAmount(balance),
        status: account.status,
        lastPaymentDate: account.lastPaymentDate,
        installmentPlan: account.installmentPlan,
        feeAssignmentId: account.feeAssignmentId,
      );
    }
  }

  @override
  Future<FinanceReceiptDetail?> getReceipt({
    required RepositoryQuery query,
    required String receiptId,
  }) async {
    for (final payment in _store.payments) {
      if (payment.id == receiptId || payment.receiptNumber == receiptId) {
        return FinanceReceiptDetail(
          id: payment.id,
          receiptNumber: payment.receiptNumber,
          amount: payment.amount,
          receiptDate: payment.collectedAt,
          collectionId: payment.id,
          invoiceId: '',
          studentAccountId: _accountIdForAdmission(payment.admissionNumber),
        );
      }
    }
    return null;
  }

  @override
  Future<PaginatedResult<FinanceInvoice>> getInvoices({
    required RepositoryQuery query,
  }) async {
    return paginateList(_store.invoices, query);
  }

  @override
  Future<FinanceInvoice?> getInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) async {
    for (final invoice in _store.invoices) {
      if (invoice.id == invoiceId) return invoice;
    }
    return null;
  }

  // ── FIN-6: invoice installment / due schedule ──────────────────────────────
  @override
  Future<List<InstallmentScheduleEntry>> getInvoiceInstallments({
    required RepositoryQuery query,
    required String invoiceId,
  }) async {
    final invoice = _store.invoices.cast<FinanceInvoice?>().firstWhere(
          (item) => item?.id == invoiceId,
          orElse: () => null,
        );
    if (invoice == null) return const [];
    // Representative 3-term schedule that sums to the invoice total.
    final total = _parseFinanceAmount(invoice.totalAmount);
    final outstanding = _parseFinanceAmount(invoice.outstandingAmount);
    final paid = (total - outstanding).clamp(0.0, total);
    final per = total / 3;
    final terms = <InstallmentScheduleEntry>[];
    var cumulative = 0.0;
    for (var i = 0; i < 3; i++) {
      final amount = i == 2 ? (total - cumulative) : per;
      cumulative += amount;
      final status = cumulative <= paid
          ? 'paid'
          : (i == 0 ? 'due' : 'pending');
      terms.add(
        InstallmentScheduleEntry(
          id: '${invoice.id}_t${i + 1}',
          termNo: i + 1,
          termLabel: 'Term ${i + 1}',
          dueDate: invoice.dueDate,
          amount: _formatFinanceAmount(amount),
          status: status,
        ),
      );
    }
    return terms;
  }

  // ── FIN-9: head-wise dues analytics ────────────────────────────────────────
  @override
  Future<List<HeadWiseDue>> getHeadWiseDues({
    required RepositoryQuery query,
  }) async {
    // Representative rollup keyed by common fee heads.
    return const [
      HeadWiseDue(
        feeHead: 'tuition:Tuition',
        category: 'tuition',
        label: 'Tuition',
        dues: '184000',
      ),
      HeadWiseDue(
        feeHead: 'transport:Transport',
        category: 'transport',
        label: 'Transport',
        dues: '62000',
      ),
      HeadWiseDue(
        feeHead: 'lab:Laboratory',
        category: 'lab',
        label: 'Laboratory',
        dues: '28500',
      ),
    ];
  }

  @override
  Future<FinanceInvoice> issueInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) async {
    final index = _store.invoices.indexWhere((item) => item.id == invoiceId);
    if (index < 0) throw StateError('Invoice not found: $invoiceId');
    final current = _store.invoices[index];
    if (current.invoiceStatus != InvoiceStatus.draft) {
      throw StateError(
          'Cannot issue invoice in status: ${current.invoiceStatus.name}');
    }
    final updated = current.copyWith(
      invoiceStatus: InvoiceStatus.issued,
      invoiceDate: '2026-06-10',
      dueDate: '2026-07-10',
      updatedAt: '2026-06-10T00:00:00.000Z',
    );
    _store.invoices[index] = updated;
    return updated;
  }

  @override
  Future<FinanceInvoice> cancelInvoice({
    required RepositoryQuery query,
    required String invoiceId,
  }) async {
    final index = _store.invoices.indexWhere((item) => item.id == invoiceId);
    if (index < 0) throw StateError('Invoice not found: $invoiceId');
    final current = _store.invoices[index];
    if (current.invoiceStatus == InvoiceStatus.paid ||
        current.invoiceStatus == InvoiceStatus.cancelled) {
      throw StateError(
          'Cannot cancel invoice in status: ${current.invoiceStatus.name}');
    }
    final updated = current.copyWith(
      invoiceStatus: InvoiceStatus.cancelled,
      outstandingAmount: '0',
      updatedAt: '2026-06-10T00:00:00.000Z',
    );
    _store.invoices[index] = updated;
    return updated;
  }

  @override
  Future<ScholarshipCatalogItem> createScholarship({
    required RepositoryQuery query,
    required CreateScholarshipRequest request,
  }) async {
    final scholarship = ScholarshipCatalogItem(
      id: _store.nextId('sch_'),
      name: request.name,
      type: request.type,
      maxDiscount: request.maxDiscount,
      eligibility: request.eligibility,
      activeAssignments: 0,
    );
    _store.scholarships.insert(0, scholarship);
    return scholarship;
  }

  @override
  Future<ScholarshipCatalogItem> updateScholarship({
    required RepositoryQuery query,
    required String scholarshipId,
    required UpdateScholarshipRequest request,
  }) async {
    final index =
        _store.scholarships.indexWhere((item) => item.id == scholarshipId);
    if (index < 0) throw StateError('Scholarship not found: $scholarshipId');
    final current = _store.scholarships[index];
    final updated = ScholarshipCatalogItem(
      id: current.id,
      name: request.name ?? current.name,
      type: request.type ?? current.type,
      maxDiscount: request.maxDiscount ?? current.maxDiscount,
      eligibility: request.eligibility ?? current.eligibility,
      activeAssignments: current.activeAssignments,
    );
    _store.scholarships[index] = updated;
    return updated;
  }

  @override
  Future<DiscountRule> createDiscountRule({
    required RepositoryQuery query,
    required CreateDiscountRuleRequest request,
  }) async {
    final rule = DiscountRule(
      id: _store.nextId('rule_'),
      name: request.name,
      discountPercent: request.discountPercent,
      appliesTo: request.appliesTo,
      status: DiscountApprovalStatus.pending,
    );
    _store.discountRules.insert(0, rule);
    return rule;
  }

  @override
  Future<DiscountRule> updateDiscountRule({
    required RepositoryQuery query,
    required String ruleId,
    required UpdateDiscountRuleRequest request,
  }) async {
    final index =
        _store.discountRules.indexWhere((item) => item.id == ruleId);
    if (index < 0) throw StateError('Discount rule not found: $ruleId');
    final current = _store.discountRules[index];
    final updated = DiscountRule(
      id: current.id,
      name: request.name ?? current.name,
      discountPercent: request.discountPercent ?? current.discountPercent,
      appliesTo: request.appliesTo ?? current.appliesTo,
      status: request.status ?? current.status,
    );
    _store.discountRules[index] = updated;
    return updated;
  }

  @override
  Future<FinanceSettingsData> updateSettings({
    required RepositoryQuery query,
    required UpdateFinanceSettingsRequest request,
  }) async {
    _store.settings = _store.copySettings(
      _store.settings,
      academicYear: request.academicYear,
      updates: request.updates,
    );
    return _store.settings;
  }

  @override
  Future<FinanceCopilotData> getFinanceCopilot(
          {required RepositoryQuery query}) async =>
      const FinanceCopilotData(
        feeCollectionForecast: 842000,
        forecastConfidence: 82,
        monthlyRevenueForecast: 810000,
        defaulterPredictions: [
          FinanceDefaulterPrediction(
            studentId: 'stu_1',
            studentName: 'Rahul Sharma',
            className: '8-A',
            outstandingAmount: 12500,
            riskScore: 88,
            daysOverdue: 45,
          ),
        ],
        collectionTrend: [
          FinanceCollectionTrendPoint(
              month: '2026-01', collected: 720000, expected: 756000),
          FinanceCollectionTrendPoint(
              month: '2026-02', collected: 780000, expected: 819000),
        ],
        riskAlerts: [
          FinanceCollectionRiskAlert(
            id: 'alert_1',
            severity: 'medium',
            title: 'Term 2 pace below target',
            detail: 'Follow up with 12 pending accounts',
          ),
        ],
        generatedAt: '2026-06-10T00:00:00Z',
      );

  @override
  Future<FinanceExecutiveData> getFinanceExecutiveDashboard({
    required RepositoryQuery query,
  }) async =>
      const FinanceExecutiveData(
        expectedCollections: 420000,
        outstandingCollections: 185000,
        collectionHealthScore: 78,
        riskStudents: [
          FinanceDefaulterPrediction(
            studentId: 'stu_1',
            studentName: 'Rahul Sharma',
            className: '8-A',
            outstandingAmount: 12500,
            riskScore: 88,
            daysOverdue: 45,
          ),
        ],
        generatedAt: '2026-06-10T00:00:00Z',
      );

  String _accountIdForAdmission(String admissionNumber) =>
      switch (admissionNumber) {
        'ADM-2026-0138' => 'acct_1',
        'ADM-2026-0142' => 'acct_2',
        'ADM-2026-0135' => 'acct_3',
        'ADM-2025-0092' => 'acct_4',
        _ => 'acct_unknown',
      };

  String _balanceForAdmission(String admissionNumber) =>
      switch (admissionNumber) {
        'ADM-2026-0138' => '₹1,23,000',
        'ADM-2026-0142' => '₹2,15,000',
        'ADM-2026-0135' => '₹2,55,000',
        'ADM-2025-0092' => '₹65,000',
        _ => '—',
      };

  // ── FIN-R1..R5: fee-recovery CRM ───────────────────────────────────────────
  @override
  Future<RecoveryContact> logRecoveryContact({
    required RepositoryQuery query,
    required LogRecoveryContactRequest request,
  }) async {
    final contact = RecoveryContact(
      id: 'rc_${_recoverySeq++}',
      studentId: request.studentId,
      channel: switch (request.channel) {
        RecoveryChannel.call => 'call',
        RecoveryChannel.whatsapp => 'whatsapp',
        RecoveryChannel.sms => 'sms',
        RecoveryChannel.visit => 'visit',
        RecoveryChannel.email => 'email',
        RecoveryChannel.other => 'other',
      },
      outcome: switch (request.outcome) {
        RecoveryOutcome.reached => 'reached',
        RecoveryOutcome.noAnswer => 'no_answer',
        RecoveryOutcome.promised => 'promised',
        RecoveryOutcome.refused => 'refused',
        RecoveryOutcome.wrongNumber => 'wrong_number',
        RecoveryOutcome.partialPaid => 'partial_paid',
        RecoveryOutcome.other => 'other',
      },
      notes: request.notes,
      contactedBy: 'finance_demo',
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
    _contacts.putIfAbsent(request.studentId, () => []).insert(0, contact);
    return contact;
  }

  @override
  Future<List<RecoveryContact>> listRecoveryContacts({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    return List<RecoveryContact>.unmodifiable(_contacts[studentId] ?? const []);
  }

  @override
  Future<PromiseToPay> createPromiseToPay({
    required RepositoryQuery query,
    required CreatePromiseToPayRequest request,
  }) async {
    final promise = PromiseToPay(
      id: 'ptp_${_recoverySeq++}',
      studentId: request.studentId,
      studentName: _promiseStudentName(request.studentId),
      amount: request.amount.startsWith('₹') ? request.amount : '₹${request.amount}',
      promiseDate: request.promiseDate,
      status: PromiseToPayStatus.pending,
      notes: request.notes,
      createdAt: DateTime.now().toUtc().toIso8601String().split('T').first,
    );
    _promises.insert(0, promise);
    return promise;
  }

  @override
  Future<List<PromiseToPay>> listPromisesToPay({
    required RepositoryQuery query,
    PromiseToPayStatus? status,
  }) async {
    if (status == null) return List<PromiseToPay>.unmodifiable(_promises);
    return List<PromiseToPay>.unmodifiable(
      _promises.where((p) => p.status == status),
    );
  }

  @override
  Future<PromiseToPay> resolvePromiseToPay({
    required RepositoryQuery query,
    required String promiseId,
    required ResolvePromiseToPayRequest request,
  }) async {
    final index = _promises.indexWhere((p) => p.id == promiseId);
    if (index == -1) {
      throw StateError('Promise to pay not found: $promiseId');
    }
    final existing = _promises[index];
    final updated = PromiseToPay(
      id: existing.id,
      studentId: existing.studentId,
      studentName: existing.studentName,
      amount: existing.amount,
      promiseDate: existing.promiseDate,
      status: request.status,
      notes: existing.notes,
      createdAt: existing.createdAt,
      resolvedAt: DateTime.now().toUtc().toIso8601String().split('T').first,
    );
    _promises[index] = updated;
    return updated;
  }

  @override
  Future<RecoveryDashboardData> getRecoveryDashboard({
    required RepositoryQuery query,
  }) async {
    final pending =
        _promises.where((p) => p.status == PromiseToPayStatus.pending).length;
    final kept =
        _promises.where((p) => p.status == PromiseToPayStatus.kept).length;
    final broken =
        _promises.where((p) => p.status == PromiseToPayStatus.broken).length;
    final contactsCount =
        _contacts.values.fold<int>(0, (sum, list) => sum + list.length);
    return RecoveryDashboardData(
      period: '2026-07',
      ptpPending: pending,
      ptpDueToday: 1,
      ptpOverdue: 1,
      ptpKept: kept,
      ptpBroken: broken,
      contactsThisMonth: contactsCount,
      recoveredThisMonth: '71667.00',
      collectorPerformance: [
        _collectorWithTarget(
          collectorId: 'user_finance_1',
          collectorName: 'Finance Admin',
          contactsMade: 12,
          promisesObtained: 5,
          collectionsCount: 3,
          amountRecovered: '95000.00',
        ),
        _collectorWithTarget(
          collectorId: 'user_finance_2',
          collectorName: 'Recovery Officer',
          contactsMade: 8,
          promisesObtained: 3,
          collectionsCount: 2,
          amountRecovered: '48000.00',
        ),
      ],
    );
  }

  /// FIN-R6: build a collector row, layering in any target set for them and the
  /// resulting attainment%.
  CollectorPerformance _collectorWithTarget({
    required String collectorId,
    required String collectorName,
    required int contactsMade,
    required int promisesObtained,
    required int collectionsCount,
    required String amountRecovered,
  }) {
    final target = _recoveryTargets[collectorId];
    final targetVal = double.tryParse(target ?? '');
    final recoveredVal = double.tryParse(amountRecovered) ?? 0;
    return CollectorPerformance(
      collectorId: collectorId,
      collectorName: collectorName,
      contactsMade: contactsMade,
      promisesObtained: promisesObtained,
      collectionsCount: collectionsCount,
      amountRecovered: amountRecovered,
      target: target,
      attainmentPct: (targetVal != null && targetVal > 0)
          ? (recoveredVal / targetVal * 100).round()
          : null,
    );
  }

  @override
  Future<RecoveryDashboardData> setCollectionTarget({
    required RepositoryQuery query,
    required SetCollectionTargetRequest request,
  }) async {
    _recoveryTargets[request.collectorUserId] = request.target;
    return getRecoveryDashboard(query: query);
  }

  @override
  Future<List<CallQueueEntry>> getCallQueue({
    required RepositoryQuery query,
  }) async {
    // FIN-R2: the call queue rides the SAME defaulter source as the defaulters
    // list (no duplicate data), enriched with the session's logged promises /
    // contacts so the queue re-orders live as a telecaller works it — mirroring
    // the backend ranking.
    final dash = await getDefaultersDashboard(query: query);
    final todayIso = DateTime.now().toUtc().toIso8601String().split('T').first;
    final entries = <CallQueueEntry>[];
    for (final d in dash.defaulters) {
      final pending = _promises
          .where((p) =>
              p.studentId == d.id && p.status == PromiseToPayStatus.pending)
          .map((p) => p.promiseDate)
          .toList()
        ..sort();
      final pendingDate = pending.isNotEmpty ? pending.first : '';
      final broken = _promises.any(
        (p) => p.studentId == d.id && p.status == PromiseToPayStatus.broken,
      );
      final logged = _contacts[d.id] ?? const <RecoveryContact>[];
      final lastContact = logged.isNotEmpty ? logged.first.timestamp : '';
      entries.add(CallQueueEntry(
        studentId: d.id,
        studentName: d.studentName,
        admissionNumber: d.admissionNumber,
        classLabel: d.classLabel,
        outstanding: d.overdueAmount,
        daysOverdue: d.daysOverdue,
        guardianPhone: d.guardianPhone,
        feeAccountId: d.feeAccountId,
        lastContact: lastContact,
        pendingPromiseDate: pendingDate,
        hasBrokenPromise: broken,
        priority: _callQueuePriority(
          daysOverdue: d.daysOverdue,
          hasBroken: broken,
          pendingDate: pendingDate,
          lastContactIso: lastContact,
          todayIso: todayIso,
        ),
        reason: _callQueueReason(
          daysOverdue: d.daysOverdue,
          hasBroken: broken,
          pendingDate: pendingDate,
          lastContactIso: lastContact,
          todayIso: todayIso,
        ),
      ));
    }
    entries.sort((a, b) =>
        a.priority != b.priority
            ? a.priority.compareTo(b.priority)
            : b.daysOverdue.compareTo(a.daysOverdue));
    return List<CallQueueEntry>.unmodifiable(entries);
  }

  int _daysSince(String fromIso, String todayIso) {
    final a = DateTime.tryParse(fromIso.split('T').first);
    final b = DateTime.tryParse(todayIso);
    if (a == null || b == null) return 0;
    return b.difference(a).inDays;
  }

  int _callQueuePriority({
    required int daysOverdue,
    required bool hasBroken,
    required String pendingDate,
    required String lastContactIso,
    required String todayIso,
  }) {
    if (hasBroken) return 0;
    if (pendingDate.isNotEmpty) {
      return pendingDate.compareTo(todayIso) <= 0 ? 1 : 5;
    }
    if (lastContactIso.isEmpty) return daysOverdue > 0 ? 2 : 4;
    return _daysSince(lastContactIso, todayIso) >= 7 ? 3 : 4;
  }

  String _callQueueReason({
    required int daysOverdue,
    required bool hasBroken,
    required String pendingDate,
    required String lastContactIso,
    required String todayIso,
  }) {
    if (hasBroken) return 'Promise broken — follow up';
    if (pendingDate.isNotEmpty) {
      return pendingDate.compareTo(todayIso) <= 0
          ? 'Promise due — confirm payment'
          : 'Promised — awaiting date';
    }
    if (lastContactIso.isEmpty) {
      return daysOverdue > 0 ? 'Not yet contacted' : 'Follow up';
    }
    return _daysSince(lastContactIso, todayIso) >= 7
        ? 'No contact in 7+ days'
        : 'Recently contacted';
  }

  String _promiseStudentName(String studentId) => switch (studentId) {
        'def_1' => 'Priya Sharma',
        'def_2' => 'Ananya Reddy',
        'def_3' => 'Kavya Iyer',
        _ => 'Student',
      };
}

class _FinanceMutableStore {
  _FinanceMutableStore()
      : feeStructures = List.of(_seedFeeStructures),
        studentAccounts = List.of(_seedStudentAccounts),
        refundRequests = List.of(_seedRefundRequests),
        scholarships = List.of(_seedScholarships),
        discountRules = List.of(_seedDiscountRules),
        invoices = List.of(_seedInvoices),
        payments = List.of(_seedPayments),
        offlinePayments = List.of(_seedOfflinePayments),
        pendingOfflinePaymentQueue = _seedOfflinePayments
            .where(
              (item) =>
                  item.status == OfflinePaymentStatus.pendingReconciliation,
            )
            .map((item) => item.id)
            .toList(),
        qrPaymentSessions = <QrPaymentSession>[],
        feeReductions = <FeeReduction>[],
        settings = _seedSettings;

  List<FinanceFeeStructure> feeStructures;
  List<StudentFeeAccount> studentAccounts;
  List<RefundRequest> refundRequests;
  List<ScholarshipCatalogItem> scholarships;
  List<DiscountRule> discountRules;
  List<FinanceInvoice> invoices;
  List<CollectionPayment> payments;
  List<OfflinePaymentRecord> offlinePayments;
  List<String> pendingOfflinePaymentQueue;
  List<QrPaymentSession> qrPaymentSessions;
  // STEP-5 — fee reductions (scholarship awards + discount applications).
  List<FeeReduction> feeReductions;
  FinanceSettingsData settings;
  final Map<String, String> invoiceIdByFeeAccountId = {};
  int _counter = 100;

  String nextId(String prefix) => '$prefix${_counter++}';

  List<FinanceFeeStructure> feeStructuresForYear(String academicYear) {
    return feeStructures
        .where(
          (structure) =>
              structure.academicYear == academicYear ||
              structure.status == FeeStructureStatus.inactive,
        )
        .toList(growable: false);
  }

  FinanceFeeStructure findFeeStructure(String id) {
    return feeStructures.firstWhere(
      (structure) => structure.id == id,
      orElse: () => throw StateError('Fee structure not found: $id'),
    );
  }

  StudentFeeAccount findStudentAccount(String id) {
    return studentAccounts.firstWhere(
      (account) => account.id == id,
      orElse: () => throw StateError('Student account not found: $id'),
    );
  }

  String planLabel(String planId) => switch (planId) {
        'plan_quarterly' => '3-term quarterly',
        'plan_termly' => '4-term termly',
        'plan_monthly' => '10-month monthly',
        'plan_annual' => 'Annual single payment',
        _ => 'Custom plan',
      };

  DiscountsDashboardData get discountsDashboard => DiscountsDashboardData(
        kpis: const [
          FinanceKpi(
            id: 'active_scholarships',
            value: '8',
            label: 'Active scholarships',
            icon: Icons.school_outlined,
            accentName: 'primary',
          ),
          FinanceKpi(
            id: 'assigned',
            value: '24',
            label: 'Student assignments',
            icon: Icons.people_outline,
            accentName: 'success',
          ),
          FinanceKpi(
            id: 'pending_approval',
            value: '3',
            label: 'Pending approval',
            icon: Icons.pending_actions_outlined,
            accentName: 'warning',
          ),
          FinanceKpi(
            id: 'impact',
            value: '₹4.2L',
            label: 'Discount impact (YTD)',
            icon: Icons.savings_outlined,
            accentName: 'neutral',
          ),
        ],
        scholarships: scholarships,
        rules: List.unmodifiable(discountRules),
        assignments: const [
          StudentDiscountAssignment(
            id: 'asgn_1',
            studentName: 'Arjun Patel',
            admissionNumber: 'ADM-2026-0138',
            scholarshipName: 'Merit Scholarship',
            discountAmount: '₹46,250',
            status: DiscountApprovalStatus.active,
            impactOnFees: '25% off tuition',
          ),
          StudentDiscountAssignment(
            id: 'asgn_2',
            studentName: 'Emma Thomas',
            admissionNumber: 'ADM-2026-0135',
            scholarshipName: 'Sports Excellence',
            discountAmount: '₹27,000',
            status: DiscountApprovalStatus.approved,
            impactOnFees: '15% off annual fee',
          ),
          StudentDiscountAssignment(
            id: 'asgn_3',
            studentName: 'Ananya Reddy',
            admissionNumber: 'ADM-2026-0142',
            scholarshipName: 'Sibling Discount',
            discountAmount: '₹21,500',
            status: DiscountApprovalStatus.pending,
            impactOnFees: '10% off — pending docs',
          ),
        ],
        impactSummary:
            'Discounts reduced gross collections by ₹4.2L YTD. Merit scholarships account for 48% of total impact.',
      );

  FinanceSettingsData copySettings(
    FinanceSettingsData current, {
    String? academicYear,
    List<FinanceSettingUpdate> updates = const [],
  }) {
    final sections = [
      for (final section in current.sections)
        FinanceSettingsSection(
          id: section.id,
          title: section.title,
          items: [
            for (final item in section.items)
              FinanceSettingItem(
                id: item.id,
                label: item.label,
                value: _valueForUpdate(
                  sectionId: section.id,
                  itemId: item.id,
                  current: item.value,
                  updates: updates,
                ),
                description: item.description,
                editable: item.editable,
              ),
          ],
        ),
    ];
    return FinanceSettingsData(
      academicYear: academicYear ?? current.academicYear,
      sections: sections,
    );
  }

  String _valueForUpdate({
    required String sectionId,
    required String itemId,
    required String current,
    required List<FinanceSettingUpdate> updates,
  }) {
    for (final update in updates) {
      if (update.sectionId == sectionId && update.itemId == itemId) {
        return update.value;
      }
    }
    return current;
  }

  static final List<FinanceFeeStructure> _seedFeeStructures = [
    const FinanceFeeStructure(
      id: 'fee_std',
      name: 'Standard CBSE',
      academicYear: '2026-27',
      totalAnnual: '₹1,85,000',
      classRange: 'Nursery – 12',
      status: FeeStructureStatus.active,
      installmentOptions: [3, 4],
      categories: [
        FeeCategoryLine(
          category: FeeStructureCategory.tuition,
          label: 'Tuition',
          amount: '₹1,45,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.activity,
          label: 'Activity & Labs',
          amount: '₹40,000',
        ),
      ],
    ),
    const FinanceFeeStructure(
      id: 'fee_premium',
      name: 'Premium + Transport',
      academicYear: '2026-27',
      totalAnnual: '₹2,15,000',
      classRange: '1 – 12',
      status: FeeStructureStatus.active,
      installmentOptions: [3, 4],
      categories: [
        FeeCategoryLine(
          category: FeeStructureCategory.tuition,
          label: 'Tuition',
          amount: '₹1,55,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.transport,
          label: 'Transport',
          amount: '₹30,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.activity,
          label: 'Activity',
          amount: '₹30,000',
        ),
      ],
    ),
    const FinanceFeeStructure(
      id: 'fee_hostel',
      name: 'Boarding Package',
      academicYear: '2026-27',
      totalAnnual: '₹3,40,000',
      classRange: '5 – 12',
      status: FeeStructureStatus.active,
      installmentOptions: [4, 6],
      categories: [
        FeeCategoryLine(
          category: FeeStructureCategory.tuition,
          label: 'Tuition',
          amount: '₹1,80,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.hostel,
          label: 'Hostel',
          amount: '₹1,20,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.transport,
          label: 'Transport',
          amount: '₹25,000',
        ),
        FeeCategoryLine(
          category: FeeStructureCategory.activity,
          label: 'Activity',
          amount: '₹15,000',
        ),
      ],
    ),
    const FinanceFeeStructure(
      id: 'fee_legacy',
      name: 'Legacy 2024 Plan',
      academicYear: '2024-25',
      totalAnnual: '₹1,65,000',
      classRange: 'Nursery – 12',
      status: FeeStructureStatus.inactive,
      installmentOptions: [3],
      categories: [
        FeeCategoryLine(
          category: FeeStructureCategory.tuition,
          label: 'Tuition',
          amount: '₹1,65,000',
        ),
      ],
    ),
  ];

  static final List<StudentFeeAccount> _seedStudentAccounts = [
    const StudentFeeAccount(
      id: 'acct_1',
      studentName: 'Arjun Patel',
      admissionNumber: 'ADM-2026-0138',
      classLabel: '10',
      feeStructureName: 'Standard CBSE',
      totalDue: '₹1,85,000',
      totalPaid: '₹62,000',
      balance: '₹1,23,000',
      status: FeeAccountStatus.active,
      lastPaymentDate: 'Today',
      installmentPlan: '3-term quarterly',
      // STEP-5 — joins finance_fee_reductions' invoice lookup the same way the
      // real backend does: invoice.feeAssignmentId == account.feeAssignmentId.
      // Linked to inv_1 (issued, open) so the award dialog has a real student
      // with a real open invoice in mock/demo mode.
      feeAssignmentId: 'assign_1',
    ),
    const StudentFeeAccount(
      id: 'acct_2',
      studentName: 'Ananya Reddy',
      admissionNumber: 'ADM-2026-0142',
      classLabel: '5',
      feeStructureName: 'Premium + Transport',
      totalDue: '₹2,15,000',
      totalPaid: '₹0',
      balance: '₹2,15,000',
      status: FeeAccountStatus.pending,
      lastPaymentDate: '—',
      installmentPlan: '3-term quarterly',
      // Linked to inv_4 (issued, open, unpaid) — a second open-invoice example.
      feeAssignmentId: 'assign_4',
    ),
    const StudentFeeAccount(
      id: 'acct_3',
      studentName: 'Emma Thomas',
      admissionNumber: 'ADM-2026-0135',
      classLabel: '7',
      feeStructureName: 'Boarding Package',
      totalDue: '₹3,40,000',
      totalPaid: '₹85,000',
      balance: '₹2,55,000',
      status: FeeAccountStatus.active,
      lastPaymentDate: '2 days ago',
      installmentPlan: '4-term termly',
      // Linked to inv_3 (draft — NOT open) so the picker demonstrates the
      // "no open invoices for this student" case.
      feeAssignmentId: 'assign_3',
    ),
    const StudentFeeAccount(
      id: 'acct_4',
      studentName: 'Priya Sharma',
      admissionNumber: 'ADM-2025-0092',
      classLabel: '8',
      feeStructureName: 'Standard CBSE',
      totalDue: '₹1,85,000',
      totalPaid: '₹1,20,000',
      balance: '₹65,000',
      status: FeeAccountStatus.overdue,
      lastPaymentDate: '45 days ago',
      installmentPlan: '3-term quarterly',
      // Linked to inv_2 (fully paid — NOT open) — another "no open invoices"
      // example.
      feeAssignmentId: 'assign_2',
    ),
  ];

  static final List<RefundRequest> _seedRefundRequests = [
    const RefundRequest(
      id: 'ref_1',
      studentName: 'Kavya Iyer',
      admissionNumber: 'ADM-2025-0101',
      classLabel: '6',
      amount: '₹52,000',
      reason: 'Withdrawal — family relocation',
      requestedAt: '4 Jun 2026',
      status: RefundStatus.pending,
      approver: 'Finance Manager',
      feeAccountId: 'acct_5',
      originalReceipt: 'RCP-2026-8836',
    ),
    const RefundRequest(
      id: 'ref_2',
      studentName: 'Rohan Mehta',
      admissionNumber: 'ADM-2025-0114',
      classLabel: '9',
      amount: '₹12,500',
      reason: 'Transport fee overcharge',
      requestedAt: '2 Jun 2026',
      status: RefundStatus.approved,
      approver: 'Principal Sharma',
      feeAccountId: 'acct_6',
      originalReceipt: 'RCP-2026-8820',
      collectionId: '',
      invoiceId: '',
    ),
    const RefundRequest(
      id: 'ref_3',
      studentName: 'Divya Iyer',
      admissionNumber: 'ADM-2025-0088',
      classLabel: '4',
      amount: '₹8,000',
      reason: 'Activity fee duplicate payment',
      requestedAt: '28 May 2026',
      status: RefundStatus.processed,
      approver: 'Finance Manager',
      feeAccountId: 'acct_7',
      originalReceipt: 'RCP-2026-8795',
      collectionId: 'col_6',
      invoiceId: 'inv_2',
    ),
    const RefundRequest(
      id: 'ref_4',
      studentName: 'Rohan Mehta',
      admissionNumber: 'ADM-2025-0114',
      classLabel: '9',
      amount: '₹38,500',
      reason: 'Transport fee overcharge',
      requestedAt: '3 Jun 2026',
      status: RefundStatus.pending,
      approver: 'Finance Manager',
      feeAccountId: 'acct_1',
      originalReceipt: 'RCP-2026-8839',
      collectionId: 'col_3',
      invoiceId: 'inv_1',
    ),
  ];

  static final List<DiscountRule> _seedDiscountRules = [
    const DiscountRule(
      id: 'rule_1',
      name: 'Early bird payment',
      discountPercent: '5%',
      appliesTo: 'Annual fee — paid before 30 Apr',
      status: DiscountApprovalStatus.active,
    ),
    const DiscountRule(
      id: 'rule_2',
      name: 'Staff child waiver',
      discountPercent: '50%',
      appliesTo: 'Tuition component only',
      status: DiscountApprovalStatus.active,
    ),
    const DiscountRule(
      id: 'rule_3',
      name: 'Need-based aid',
      discountPercent: 'Up to 40%',
      appliesTo: 'Management approval required',
      status: DiscountApprovalStatus.pending,
    ),
  ];

  static final List<ScholarshipCatalogItem> _seedScholarships = [
    const ScholarshipCatalogItem(
      id: 'sch_1',
      name: 'Merit Scholarship',
      type: ScholarshipType.merit,
      maxDiscount: '25%',
      eligibility: 'Top 10% academic performance',
      activeAssignments: 8,
    ),
    const ScholarshipCatalogItem(
      id: 'sch_2',
      name: 'Sibling Discount',
      type: ScholarshipType.sibling,
      maxDiscount: '10%',
      eligibility: 'Second child enrolled',
      activeAssignments: 12,
    ),
    const ScholarshipCatalogItem(
      id: 'sch_3',
      name: 'Sports Excellence',
      type: ScholarshipType.sports,
      maxDiscount: '15%',
      eligibility: 'State-level sports achievement',
      activeAssignments: 4,
    ),
  ];

  static const List<FinanceInvoice> _seedInvoices = [
    FinanceInvoice(
      id: 'inv_1',
      studentId: 'stu_1',
      feeAssignmentId: 'assign_1',
      academicYear: '2026-27',
      invoiceNumber: 'INV-2026-A1B2C3D4',
      invoiceDate: '2026-06-01',
      dueDate: '2026-07-01',
      subtotalAmount: '185000',
      discountAmount: '0',
      totalAmount: '185000',
      outstandingAmount: '50000',
      paidAmount: '135000',
      invoiceStatus: InvoiceStatus.issued,
      termLabel: 'Annual',
      createdBy: 'staff_1',
      createdAt: '2026-06-01T00:00:00.000Z',
      updatedAt: '2026-06-01T00:00:00.000Z',
    ),
    FinanceInvoice(
      id: 'inv_2',
      studentId: 'stu_2',
      feeAssignmentId: 'assign_2',
      academicYear: '2026-27',
      invoiceNumber: 'INV-2026-E5F6G7H8',
      invoiceDate: '2026-06-01',
      dueDate: '2026-06-15',
      subtotalAmount: '150000',
      discountAmount: '0',
      totalAmount: '150000',
      outstandingAmount: '0',
      paidAmount: '150000',
      invoiceStatus: InvoiceStatus.paid,
      termLabel: 'Annual',
      createdBy: 'staff_1',
      createdAt: '2026-06-01T00:00:00.000Z',
      updatedAt: '2026-06-05T00:00:00.000Z',
    ),
    FinanceInvoice(
      id: 'inv_3',
      studentId: 'stu_3',
      feeAssignmentId: 'assign_3',
      academicYear: '2026-27',
      invoiceNumber: 'INV-2026-I9J0K1L2',
      invoiceDate: '2026-06-10',
      dueDate: '2026-07-10',
      subtotalAmount: '120000',
      discountAmount: '0',
      totalAmount: '120000',
      outstandingAmount: '120000',
      paidAmount: '0',
      invoiceStatus: InvoiceStatus.draft,
      termLabel: 'Annual',
      createdBy: 'staff_1',
      createdAt: '2026-06-10T00:00:00.000Z',
      updatedAt: '2026-06-10T00:00:00.000Z',
    ),
    // STEP-5 — a second open (issued, unpaid) invoice so the fee-reduction
    // award dialog has more than one real student/invoice pairing in
    // mock/demo mode (linked to acct_2 via feeAssignmentId).
    FinanceInvoice(
      id: 'inv_4',
      studentId: 'stu_4',
      feeAssignmentId: 'assign_4',
      academicYear: '2026-27',
      invoiceNumber: 'INV-2026-M3N4O5P6',
      invoiceDate: '2026-06-01',
      dueDate: '2026-07-15',
      subtotalAmount: '215000',
      discountAmount: '0',
      totalAmount: '215000',
      outstandingAmount: '215000',
      paidAmount: '0',
      invoiceStatus: InvoiceStatus.issued,
      termLabel: 'Annual',
      createdBy: 'staff_1',
      createdAt: '2026-06-01T00:00:00.000Z',
      updatedAt: '2026-06-01T00:00:00.000Z',
    ),
  ];

  static const List<CollectionPayment> _seedPayments = [
    CollectionPayment(
      id: 'col_1',
      receiptNumber: 'RCP-2026-8841',
      studentName: 'Arjun Patel',
      admissionNumber: 'ADM-2026-0138',
      amount: '₹62,000',
      mode: 'UPI',
      collectedAt: 'Today, 10:42',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.completed,
      classLabel: '10',
    ),
    CollectionPayment(
      id: 'col_2',
      receiptNumber: 'RCP-2026-8840',
      studentName: 'Priya Sharma',
      admissionNumber: 'ADM-2025-0092',
      amount: '₹45,000',
      mode: 'Cash',
      collectedAt: 'Today, 09:15',
      collectedBy: 'S. Nair',
      status: CollectionStatus.completed,
      classLabel: '8',
    ),
    CollectionPayment(
      id: 'col_3',
      receiptNumber: 'RCP-2026-8839',
      studentName: 'Rohan Mehta',
      admissionNumber: 'ADM-2025-0114',
      amount: '₹38,500',
      mode: 'Card',
      collectedAt: 'Today, 08:30',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.completed,
      classLabel: '9',
    ),
    CollectionPayment(
      id: 'col_4',
      receiptNumber: 'RCP-2026-8838',
      studentName: 'Ananya Reddy',
      admissionNumber: 'ADM-2026-0142',
      amount: '₹71,500',
      mode: 'UPI',
      collectedAt: 'Yesterday',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.pending,
      classLabel: '5',
    ),
    CollectionPayment(
      id: 'col_5',
      receiptNumber: 'RCP-2026-8837',
      studentName: 'Emma Thomas',
      admissionNumber: 'ADM-2026-0135',
      amount: '₹85,000',
      mode: 'Bank Transfer',
      collectedAt: 'Yesterday',
      collectedBy: 'S. Nair',
      status: CollectionStatus.completed,
      classLabel: '7',
    ),
    CollectionPayment(
      id: 'col_6',
      receiptNumber: 'RCP-2026-8836',
      studentName: 'Kavya Iyer',
      admissionNumber: 'ADM-2025-0101',
      amount: '₹52,000',
      mode: 'UPI',
      collectedAt: '2 days ago',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.refunded,
      classLabel: '6',
    ),
  ];

  static const List<OfflinePaymentRecord> _seedOfflinePayments = [
    OfflinePaymentRecord(
      id: 'op_1',
      invoiceId: 'inv_1',
      studentName: 'Arjun Patel',
      amount: '15000',
      method: OfflinePaymentMethod.cash,
      referenceNumber: 'CASH-1001',
      recordedAt: '2026-06-11',
      status: OfflinePaymentStatus.pendingReconciliation,
    ),
    OfflinePaymentRecord(
      id: 'op_2',
      invoiceId: 'inv_2',
      studentName: 'Priya Sharma',
      amount: '8000',
      method: OfflinePaymentMethod.cheque,
      referenceNumber: 'CHQ-2099',
      recordedAt: '2026-06-09',
      status: OfflinePaymentStatus.reconciled,
      collectionId: 'col_2',
    ),
  ];

  static const FinanceSettingsData _seedSettings = FinanceSettingsData(
    academicYear: '2026-27',
    sections: [
      FinanceSettingsSection(
        id: 'academic',
        title: 'Academic year setup',
        items: [
          FinanceSettingItem(
            id: 'year',
            label: 'Active academic year',
            value: '2026-27',
            description: 'Fee structures and assignments use this year',
            editable: true,
          ),
          FinanceSettingItem(
            id: 'term_dates',
            label: 'Term dates',
            value: 'Apr – Mar (3 terms)',
            description: 'Installment due dates derived from term calendar',
            editable: true,
          ),
        ],
      ),
      FinanceSettingsSection(
        id: 'receipts',
        title: 'Receipt numbering',
        items: [
          FinanceSettingItem(
            id: 'prefix',
            label: 'Receipt prefix',
            value: 'RCP-2026-',
            description: 'Auto-incremented per transaction (PA-11)',
            editable: true,
          ),
          FinanceSettingItem(
            id: 'next_number',
            label: 'Next receipt number',
            value: '8842',
            description: 'Last issued: RCP-2026-8841',
            editable: false,
          ),
        ],
      ),
      FinanceSettingsSection(
        id: 'gateway',
        title: 'Payment gateway',
        items: [
          FinanceSettingItem(
            id: 'upi',
            label: 'UPI gateway',
            value: 'Razorpay (sandbox)',
            description: 'Parent App payment flow (PA-10)',
            editable: true,
          ),
          FinanceSettingItem(
            id: 'card',
            label: 'Card payments',
            value: 'Disabled',
            description: 'Enable for online card collection',
            editable: true,
          ),
        ],
      ),
      FinanceSettingsSection(
        id: 'workflow',
        title: 'Finance workflow',
        items: [
          FinanceSettingItem(
            id: 'handoff',
            label: 'Admissions handoff',
            value: 'Auto-queue on approval',
            description: 'AD-08 → FN-04 fee assignment',
            editable: true,
          ),
          FinanceSettingItem(
            id: 'refund_approval',
            label: 'Refund approval',
            value: 'Principal + Finance',
            description: 'Dual approval for refunds > ₹25,000',
            editable: true,
          ),
        ],
      ),
      FinanceSettingsSection(
        id: 'reminders',
        title: 'Reminder settings',
        items: [
          FinanceSettingItem(
            id: 'due_reminder',
            label: 'Due date reminder',
            value: '3 days before',
            description: 'Push + WhatsApp via Parent App',
            editable: true,
          ),
          FinanceSettingItem(
            id: 'overdue',
            label: 'Overdue escalation',
            value: '7 / 15 / 30 days',
            description: 'Escalation ladder for defaulters (FN-07)',
            editable: true,
          ),
        ],
      ),
      FinanceSettingsSection(
        id: 'policy',
        title: 'Collection policy',
        items: [
          FinanceSettingItem(
            id: 'late_fee',
            label: 'Late fee',
            value: '₹500 / month',
            description: 'Applied after 15-day grace period',
            editable: true,
          ),
          FinanceSettingItem(
            id: 'min_payment',
            label: 'Minimum partial payment',
            value: '25% of installment',
            description: 'Allowed for hardship cases',
            editable: true,
          ),
        ],
      ),
    ],
  );
}
