import 'package:flutter/material.dart';

import '../admissions/admissions_models.dart';

/// Finance sub-module destinations (FN-01 → FN-11).
enum FinanceScreen {
  dashboard,
  feeStructures,
  studentAccounts,
  feeAssignment,
  collections,
  offlinePayments,
  collectionDetail,
  defaulters,
  refunds,
  discounts,
  reports,
  reconciliation,
  settings,
  intelligence,
  executiveDashboard;

  String get label => switch (this) {
        FinanceScreen.dashboard => 'Dashboard',
        FinanceScreen.feeStructures => 'Fee Structures',
        FinanceScreen.studentAccounts => 'Student Accounts',
        FinanceScreen.feeAssignment => 'Fee Assignment',
        FinanceScreen.collections => 'Collections',
        FinanceScreen.offlinePayments => 'Offline Payments',
        FinanceScreen.collectionDetail => 'Collection Detail',
        FinanceScreen.defaulters => 'Defaulters',
        FinanceScreen.refunds => 'Refunds',
        FinanceScreen.discounts => 'Discounts',
        FinanceScreen.reports => 'Reports',
        FinanceScreen.reconciliation => 'Reconciliation',
        FinanceScreen.settings => 'Settings',
        FinanceScreen.intelligence => 'Finance Copilot',
        FinanceScreen.executiveDashboard => 'Executive Dashboard',
      };
}

enum FeeStructureCategory { tuition, transport, hostel, activity }

enum FeeStructureStatus { active, inactive }

enum FeeAccountStatus { active, overdue, closed, pending }

enum CollectionStatus { completed, pending, failed, refunded }

enum QrPaymentSessionStatus { pending, confirmed, expired }

enum InstallmentPlanType { quarterly, termly, monthly, annual }

// FIN-R7: pdc = post-dated cheque (instrumentDate carries the cheque date).
enum OfflinePaymentMethod { cash, cheque, dd, pdc }

// FIN-R7: bounced = terminal state for a dishonoured instrument (tracking-only,
// no money reversed — Finance is the sole payment engine).
enum OfflinePaymentStatus { pendingReconciliation, reconciled, bounced }

@immutable
class FinanceKpi {
  const FinanceKpi({
    required this.id,
    required this.value,
    required this.label,
    required this.icon,
    required this.accentName,
    this.detail,
  });

  final String id;
  final String value;
  final String label;
  final IconData icon;
  final String accentName;
  final String? detail;
}

@immutable
class CollectionTrendPoint {
  const CollectionTrendPoint({
    required this.label,
    required this.amountLakhs,
    required this.targetLakhs,
  });

  final String label;
  final double amountLakhs;
  final double targetLakhs;
}

@immutable
class RecentPayment {
  const RecentPayment({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.amount,
    required this.mode,
    required this.receiptNumber,
    required this.collectedAt,
    required this.status,
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String amount;
  final String mode;
  final String receiptNumber;
  final String collectedAt;
  final CollectionStatus status;
}

@immutable
class FinanceDashboardData {
  const FinanceDashboardData({
    required this.kpis,
    required this.collectionTrend,
    required this.recentPayments,
    required this.aiInsight,
    required this.outstandingAmount,
    required this.defaultersCount,
  });

  final List<FinanceKpi> kpis;
  final List<CollectionTrendPoint> collectionTrend;
  final List<RecentPayment> recentPayments;
  final String aiInsight;
  final String outstandingAmount;
  final int defaultersCount;
}

@immutable
class FeeCategoryLine {
  const FeeCategoryLine({
    required this.category,
    required this.label,
    required this.amount,
  });

  final FeeStructureCategory category;
  final String label;
  final String amount;
}

@immutable
class FinanceFeeStructure {
  const FinanceFeeStructure({
    required this.id,
    required this.name,
    required this.academicYear,
    required this.totalAnnual,
    required this.categories,
    required this.status,
    required this.installmentOptions,
    required this.classRange,
    this.academicYearId,
  });

  final String id;
  final String name;
  final String academicYear;
  final String totalAnnual;
  final List<FeeCategoryLine> categories;
  final FeeStructureStatus status;
  final List<int> installmentOptions;
  final String classRange;
  final String? academicYearId;
}

@immutable
class InstallmentPlan {
  const InstallmentPlan({
    required this.id,
    required this.label,
    required this.installmentCount,
    required this.type,
  });

  final String id;
  final String label;
  final int installmentCount;
  final InstallmentPlanType type;
}

@immutable
class StudentFeeAccount {
  const StudentFeeAccount({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.feeStructureName,
    required this.totalDue,
    required this.totalPaid,
    required this.balance,
    required this.status,
    required this.lastPaymentDate,
    required this.installmentPlan,
    this.feeAssignmentId,
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String feeStructureName;
  final String totalDue;
  final String totalPaid;
  final String balance;
  final FeeAccountStatus status;
  final String lastPaymentDate;
  final String installmentPlan;

  /// #6 — the backing `finance_fee_assignments.id`, distinct from [id] (the
  /// student account id). Needed to target `PATCH .../fee-assignments/:id/
  /// cancel`; null when the account wasn't created via a real API assignment
  /// (e.g. mock/offline data has no separate assignment row).
  final String? feeAssignmentId;
}

/// PRC-A gap fix — outcome of a bulk/class-wide fee-structure assignment
/// (`POST /finance/fee-assignments/bulk`). [assigned] mirrors the
/// single-assign [StudentFeeAccount] shape for every student the assignment
/// actually succeeded for; [skipped] reports students who already had this
/// exact structure for this academic year — NOT an error, since a bulk call
/// over a whole class routinely includes some already-assigned students.
@immutable
class BulkFeeAssignmentResult {
  const BulkFeeAssignmentResult({
    required this.assigned,
    required this.skipped,
    required this.total,
  });

  final List<StudentFeeAccount> assigned;
  final List<BulkFeeAssignmentSkip> skipped;
  final int total;
}

@immutable
class BulkFeeAssignmentSkip {
  const BulkFeeAssignmentSkip({
    required this.studentId,
    required this.reason,
  });

  final String studentId;
  final String reason;
}

@immutable
class FeeAssignmentDraft {
  const FeeAssignmentDraft({
    required this.handoffId,
    required this.feeStructureId,
    required this.installmentPlanId,
    required this.includeTransport,
    required this.includeHostel,
  });

  final String handoffId;
  final String feeStructureId;
  final String installmentPlanId;
  final bool includeTransport;
  final bool includeHostel;
}

@immutable
class GeneratedFeeAccountPreview {
  const GeneratedFeeAccountPreview({
    required this.accountId,
    required this.studentName,
    required this.admissionNumber,
    required this.feeStructureName,
    required this.totalDue,
    required this.installmentSummary,
    required this.addOns,
    this.feeAssignmentId,
  });

  final String accountId;
  final String studentName;
  final String admissionNumber;
  final String feeStructureName;
  final String totalDue;
  final String installmentSummary;
  final List<String> addOns;

  /// #6 — the real backend fee-assignment id from the just-completed
  /// assignFeePlan call (null only if that call didn't return one, e.g. an
  /// unconfigured repository); needed to target the cancel action.
  final String? feeAssignmentId;
}

@immutable
class CollectionPayment {
  const CollectionPayment({
    required this.id,
    required this.receiptNumber,
    required this.studentName,
    required this.admissionNumber,
    required this.amount,
    required this.mode,
    required this.collectedAt,
    required this.collectedBy,
    required this.status,
    required this.classLabel,
  });

  final String id;
  final String receiptNumber;
  final String studentName;
  final String admissionNumber;
  final String amount;
  final String mode;
  final String collectedAt;
  final String collectedBy;
  final CollectionStatus status;
  final String classLabel;
}

@immutable
class QrPaymentSession {
  const QrPaymentSession({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.upiPayload,
    required this.status,
    required this.expiresAt,
    this.receiptNumber,
  });

  final String id;
  final String invoiceId;
  final String amount;
  final String upiPayload;
  final QrPaymentSessionStatus status;
  final DateTime expiresAt;
  final String? receiptNumber;
}

@immutable
class FinanceCollectionResult {
  const FinanceCollectionResult({
    required this.collectionId,
    required this.invoiceId,
    required this.studentAccountId,
    required this.receiptNumber,
    required this.amountCollected,
    required this.paymentMethod,
    required this.collectionDate,
    required this.receipt,
    required this.invoice,
    this.pendingSync = false,
  });

  final String collectionId;
  final String invoiceId;
  final String studentAccountId;
  final String receiptNumber;
  final String amountCollected;
  final String paymentMethod;
  final String collectionDate;
  final FinanceReceiptDetail receipt;
  final FinanceInvoice invoice;

  /// True when the collection was recorded offline and is waiting to sync
  /// (Data Reliability Platform, refinement R1). While pending, the amount is
  /// safely queued but the transaction is NOT server-confirmed — a final
  /// receipt must NOT be generated, printed or shared until [pendingSync] is
  /// false (i.e. the server confirmed it).
  final bool pendingSync;
}

@immutable
class OfflinePaymentRecord {
  const OfflinePaymentRecord({
    required this.id,
    required this.invoiceId,
    required this.studentName,
    required this.amount,
    required this.method,
    required this.referenceNumber,
    required this.recordedAt,
    required this.status,
    this.collectionId,
    this.instrumentDate,
    this.bankName,
    this.bouncedReason,
  });

  final String id;
  final String invoiceId;
  final String studentName;
  final String amount;
  final OfflinePaymentMethod method;
  final String referenceNumber;
  final String recordedAt;
  final OfflinePaymentStatus status;
  final String? collectionId;

  /// FIN-R7: cheque/DD/PDC date (for a PDC, the future maturity date).
  final String? instrumentDate;
  final String? bankName;

  /// FIN-R7: reason recorded when [status] is [OfflinePaymentStatus.bounced].
  final String? bouncedReason;
}

@immutable
class DailyCollectionSummary {
  const DailyCollectionSummary({
    required this.dateLabel,
    required this.totalCollected,
    required this.transactionCount,
    required this.cashAmount,
    required this.upiAmount,
    required this.pendingReconciliation,
  });

  final String dateLabel;
  final String totalCollected;
  final int transactionCount;
  final String cashAmount;
  final String upiAmount;
  final int pendingReconciliation;
}

@immutable
class FinanceHandoffQueueItem {
  const FinanceHandoffQueueItem({
    required this.handoff,
    required this.effectiveStatus,
  });

  final ApprovedStudentHandoff handoff;
  final FeeHandoffStatus effectiveStatus;
}

// --- Phase 2 models (FN-06 → FN-11) ---

enum DefaulterAgingBucket { current, days1to30, days31to60, days61to90, over90 }

enum RefundStatus { pending, approved, rejected, processed }

enum InvoiceStatus { draft, issued, partiallyPaid, paid, cancelled }

@immutable
class FinanceInvoice {
  const FinanceInvoice({
    required this.id,
    required this.studentId,
    required this.feeAssignmentId,
    required this.academicYear,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.outstandingAmount,
    required this.paidAmount,
    required this.invoiceStatus,
    required this.termLabel,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lateFeeAmount = '0',
    this.lateFeeAccruedAt = '',
  });

  final String id;
  final String studentId;
  final String feeAssignmentId;
  final String academicYear;
  final String invoiceNumber;
  final String invoiceDate;
  final String dueDate;
  final String subtotalAmount;
  final String discountAmount;
  final String totalAmount;
  final String outstandingAmount;
  final String paidAmount;
  final InvoiceStatus invoiceStatus;
  final String termLabel;
  final String createdBy;
  final String createdAt;
  final String updatedAt;

  /// FIN-D5: accrued late fee on this invoice ('0' when none accrued yet).
  final String lateFeeAmount;

  /// FIN-D5: when the late fee was accrued ('' when none).
  final String lateFeeAccruedAt;

  /// FIN-D5: true when a non-zero late fee has been accrued on this invoice.
  bool get hasLateFee {
    final v = double.tryParse(lateFeeAmount.replaceAll(RegExp(r'[^\d.-]'), ''));
    return v != null && v > 0;
  }

  FinanceInvoice copyWith({
    InvoiceStatus? invoiceStatus,
    String? invoiceDate,
    String? dueDate,
    String? outstandingAmount,
    String? paidAmount,
    String? updatedAt,
    String? lateFeeAmount,
    String? lateFeeAccruedAt,
  }) {
    return FinanceInvoice(
      id: id,
      studentId: studentId,
      feeAssignmentId: feeAssignmentId,
      academicYear: academicYear,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      subtotalAmount: subtotalAmount,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      invoiceStatus: invoiceStatus ?? this.invoiceStatus,
      termLabel: termLabel,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lateFeeAmount: lateFeeAmount ?? this.lateFeeAmount,
      lateFeeAccruedAt: lateFeeAccruedAt ?? this.lateFeeAccruedAt,
    );
  }
}

enum DiscountApprovalStatus { pending, approved, rejected, active }

enum ScholarshipType { merit, needBased, sibling, staffChild, sports }

@immutable
class PaymentTimelineEntry {
  const PaymentTimelineEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.timestamp,
    required this.status,
    required this.mode,
  });

  final String id;
  final String label;
  final String amount;
  final String timestamp;
  final CollectionStatus status;
  final String mode;
}

@immutable
class InstallmentHistoryEntry {
  const InstallmentHistoryEntry({
    required this.id,
    required this.termLabel,
    required this.dueDate,
    required this.amount,
    required this.paidAmount,
    required this.status,
  });

  final String id;
  final String termLabel;
  final String dueDate;
  final String amount;
  final String paidAmount;
  final CollectionStatus status;
}

@immutable
class ReceiptLink {
  const ReceiptLink({
    required this.receiptNumber,
    required this.amount,
    required this.dateLabel,
    required this.parentReceiptRoute,
  });

  final String receiptNumber;
  final String amount;
  final String dateLabel;
  final String parentReceiptRoute;
}

@immutable
class FinanceReceiptDetail {
  const FinanceReceiptDetail({
    required this.id,
    required this.receiptNumber,
    required this.amount,
    required this.receiptDate,
    required this.collectionId,
    required this.invoiceId,
    required this.studentAccountId,
  });

  final String id;
  final String receiptNumber;
  final String amount;
  final String receiptDate;
  final String collectionId;
  final String invoiceId;
  final String studentAccountId;
}

@immutable
class CollectionDetail {
  const CollectionDetail({
    required this.payment,
    required this.summaryKpis,
    required this.paymentTimeline,
    required this.installmentHistory,
    required this.receiptLinks,
    required this.feeAccountId,
    required this.aiInsight,
    this.invoiceId = '',
  });

  final CollectionPayment payment;
  final List<FinanceKpi> summaryKpis;
  final List<PaymentTimelineEntry> paymentTimeline;
  final List<InstallmentHistoryEntry> installmentHistory;
  final List<ReceiptLink> receiptLinks;
  final String feeAccountId;
  final String aiInsight;

  /// FIN-6: the invoice this collection was applied to (drives the installment
  /// schedule lookup). Empty when the backend doesn't supply one.
  final String invoiceId;
}

@immutable
class AgingBucketSummary {
  const AgingBucketSummary({
    required this.bucket,
    required this.label,
    required this.studentCount,
    required this.totalAmount,
  });

  final DefaulterAgingBucket bucket;
  final String label;
  final int studentCount;
  final String totalAmount;
}

@immutable
class ContactHistoryEntry {
  const ContactHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.channel,
    required this.outcome,
    required this.notes,
  });

  final String id;
  final String timestamp;
  final String channel;
  final String outcome;
  final String notes;
}

@immutable
class DefaulterRecord {
  const DefaulterRecord({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.overdueAmount,
    required this.daysOverdue,
    required this.bucket,
    required this.lastContact,
    required this.collectionProbability,
    required this.contactHistory,
    required this.feeAccountId,
    this.guardianPhone = '',
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String overdueAmount;
  final int daysOverdue;
  final DefaulterAgingBucket bucket;
  final String lastContact;
  final int collectionProbability;
  final List<ContactHistoryEntry> contactHistory;
  final String feeAccountId;

  /// Guardian's WhatsApp/contact number (B5). Empty when the backend doesn't
  /// supply one — the WhatsApp affordance hides itself in that case.
  final String guardianPhone;
}

@immutable
class DefaultersDashboardData {
  const DefaultersDashboardData({
    required this.kpis,
    required this.agingBuckets,
    required this.defaulters,
    required this.aiInsight,
    required this.aiActionLabel,
  });

  final List<FinanceKpi> kpis;
  final List<AgingBucketSummary> agingBuckets;
  final List<DefaulterRecord> defaulters;
  final String aiInsight;
  final String aiActionLabel;
}

/// FIN-6 — one term of an invoice's informational installment / due schedule.
/// Purely for display + reminders; the invoice's single outstanding stays
/// authoritative (no per-term money movement).
@immutable
class InstallmentScheduleEntry {
  const InstallmentScheduleEntry({
    required this.id,
    required this.termNo,
    required this.termLabel,
    required this.dueDate,
    required this.amount,
    required this.status,
  });

  final String id;
  final int termNo;
  final String termLabel;
  final String dueDate;
  final String amount;

  /// 'pending' | 'due' | 'paid' (as emitted by the backend).
  final String status;
}

/// FIN-9 — outstanding dues rolled up per fee head across open invoices.
@immutable
class HeadWiseDue {
  const HeadWiseDue({
    required this.feeHead,
    required this.category,
    required this.label,
    required this.dues,
  });

  /// Raw "category:label" head key.
  final String feeHead;
  final String category;
  final String label;
  final String dues;
}

/// FIN-R3 — promise-to-pay commitment status.
enum PromiseToPayStatus { pending, kept, broken, cancelled }

/// FIN-R4 — recovery contact channel.
enum RecoveryChannel { call, whatsapp, sms, visit, email, other }

/// FIN-R4 — outcome of a recovery contact attempt.
enum RecoveryOutcome {
  reached,
  noAnswer,
  promised,
  refused,
  wrongNumber,
  partialPaid,
  other,
}

/// FIN-R4 — a logged recovery contact attempt returned by the backend.
@immutable
class RecoveryContact {
  const RecoveryContact({
    required this.id,
    required this.studentId,
    required this.channel,
    required this.outcome,
    required this.notes,
    required this.contactedBy,
    required this.timestamp,
  });

  final String id;
  final String studentId;
  final String channel;
  final String outcome;
  final String notes;
  final String contactedBy;
  final String timestamp;
}

/// FIN-R3 — a student's promise to pay by a given date.
@immutable
class PromiseToPay {
  const PromiseToPay({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.amount,
    required this.promiseDate,
    required this.status,
    required this.notes,
    required this.createdAt,
    this.resolvedAt = '',
  });

  final String id;
  final String studentId;
  final String studentName;
  final String amount;
  final String promiseDate;
  final PromiseToPayStatus status;
  final String notes;
  final String createdAt;
  final String resolvedAt;
}

/// FIN-R5 — per-collector recovery performance for the current period.
@immutable
class CollectorPerformance {
  const CollectorPerformance({
    required this.collectorId,
    required this.collectorName,
    required this.contactsMade,
    required this.promisesObtained,
    required this.collectionsCount,
    required this.amountRecovered,
    this.target,
    this.attainmentPct,
  });

  final String collectorId;
  final String collectorName;
  final int contactsMade;
  final int promisesObtained;
  final int collectionsCount;
  final String amountRecovered;

  /// FIN-R6: this month's collection target for the collector (null = unset).
  final String? target;

  /// FIN-R6: recovered ÷ target as a whole percent (null when no target set).
  final int? attainmentPct;
}

/// FIN-R2 — one entry in the telecaller call queue: a defaulter to call,
/// carrying the signals the queue is ranked on so the UI can show WHY it's here
/// ([reason]) and how urgent ([priority], lower = call sooner).
@immutable
class CallQueueEntry {
  const CallQueueEntry({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.outstanding,
    required this.daysOverdue,
    required this.guardianPhone,
    required this.feeAccountId,
    required this.lastContact,
    required this.pendingPromiseDate,
    required this.hasBrokenPromise,
    required this.priority,
    required this.reason,
  });

  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String outstanding;
  final int daysOverdue;
  final String guardianPhone;
  final String feeAccountId;

  /// ISO timestamp of the last contact ('' when never contacted).
  final String lastContact;

  /// Nearest pending promise date ('' when none).
  final String pendingPromiseDate;
  final bool hasBrokenPromise;

  /// 0 = call first. Server-authoritative ranking.
  final int priority;

  /// Human label for why this entry is prioritised (e.g. "Not yet contacted").
  final String reason;
}

/// FIN-R1/R5 — fee-recovery CRM dashboard aggregates.
@immutable
class RecoveryDashboardData {
  const RecoveryDashboardData({
    required this.period,
    required this.ptpPending,
    required this.ptpDueToday,
    required this.ptpOverdue,
    required this.ptpKept,
    required this.ptpBroken,
    required this.contactsThisMonth,
    required this.recoveredThisMonth,
    required this.collectorPerformance,
  });

  final String period;
  final int ptpPending;
  final int ptpDueToday;
  final int ptpOverdue;
  final int ptpKept;
  final int ptpBroken;
  final int contactsThisMonth;
  final String recoveredThisMonth;
  final List<CollectorPerformance> collectorPerformance;
}

@immutable
class RefundRequest {
  const RefundRequest({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.amount,
    required this.reason,
    required this.requestedAt,
    required this.status,
    required this.approver,
    required this.feeAccountId,
    required this.originalReceipt,
    this.collectionId = '',
    this.invoiceId = '',
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String amount;
  final String reason;
  final String requestedAt;
  final RefundStatus status;
  final String approver;
  final String feeAccountId;
  final String originalReceipt;
  final String collectionId;
  final String invoiceId;
}

@immutable
class ScholarshipCatalogItem {
  const ScholarshipCatalogItem({
    required this.id,
    required this.name,
    required this.type,
    required this.maxDiscount,
    required this.eligibility,
    required this.activeAssignments,
  });

  final String id;
  final String name;
  final ScholarshipType type;
  final String maxDiscount;
  final String eligibility;
  final int activeAssignments;
}

@immutable
class DiscountRule {
  const DiscountRule({
    required this.id,
    required this.name,
    required this.discountPercent,
    required this.appliesTo,
    required this.status,
  });

  final String id;
  final String name;
  final String discountPercent;
  final String appliesTo;
  final DiscountApprovalStatus status;
}

@immutable
class StudentDiscountAssignment {
  const StudentDiscountAssignment({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.scholarshipName,
    required this.discountAmount,
    required this.status,
    required this.impactOnFees,
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String scholarshipName;
  final String discountAmount;
  final DiscountApprovalStatus status;
  final String impactOnFees;
}

@immutable
class DiscountsDashboardData {
  const DiscountsDashboardData({
    required this.kpis,
    required this.scholarships,
    required this.rules,
    required this.assignments,
    required this.impactSummary,
  });

  final List<FinanceKpi> kpis;
  final List<ScholarshipCatalogItem> scholarships;
  final List<DiscountRule> rules;
  final List<StudentDiscountAssignment> assignments;
  final String impactSummary;
}

// STEP-5 — fee reductions (scholarship awards + discount applications) that
// ACTUALLY reduce a student's payable, but only through the two-person
// maker-checker on `finance_fee_reductions_{repository,handlers}.ts`. A
// reduction is born `pending` (no money moves) and only `approveFeeReduction`
// — by someone other than the proposer — applies it against the target
// INVOICE. Mirrors the backend's `FinanceFeeReductionRow` / `feeReductionToApi`
// shape exactly (see finance_fee_reductions_repository.ts).
enum FeeReductionSourceKind { scholarship, discount }

enum FeeReductionKind { percent, fixed }

enum FeeReductionStatus { pending, approved, rejected, reversed }

@immutable
class FeeReduction {
  const FeeReduction({
    required this.id,
    required this.sourceKind,
    this.scholarshipId = '',
    this.discountRuleId = '',
    required this.studentId,
    required this.invoiceId,
    this.studentAccountId = '',
    required this.reductionKind,
    this.percent = '',
    this.fixedAmount = '',
    this.appliedAmount = '0',
    required this.status,
    required this.reason,
    required this.createdBy,
    this.approvedBy = '',
    this.reversedBy = '',
    this.appliedAt = '',
    this.reversedAt = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final FeeReductionSourceKind sourceKind;
  final String scholarshipId;
  final String discountRuleId;
  final String studentId;
  final String invoiceId;
  final String studentAccountId;
  final FeeReductionKind reductionKind;
  final String percent;
  final String fixedAmount;
  final String appliedAmount;
  final FeeReductionStatus status;
  final String reason;
  final String createdBy;
  final String approvedBy;
  final String reversedBy;
  final String appliedAt;
  final String reversedAt;
  final String createdAt;
  final String updatedAt;

  FeeReduction copyWith({
    FeeReductionStatus? status,
    String? appliedAmount,
    String? approvedBy,
    String? reversedBy,
    String? appliedAt,
    String? reversedAt,
    String? updatedAt,
  }) {
    return FeeReduction(
      id: id,
      sourceKind: sourceKind,
      scholarshipId: scholarshipId,
      discountRuleId: discountRuleId,
      studentId: studentId,
      invoiceId: invoiceId,
      studentAccountId: studentAccountId,
      reductionKind: reductionKind,
      percent: percent,
      fixedAmount: fixedAmount,
      appliedAmount: appliedAmount ?? this.appliedAmount,
      status: status ?? this.status,
      reason: reason,
      createdBy: createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      reversedBy: reversedBy ?? this.reversedBy,
      appliedAt: appliedAt ?? this.appliedAt,
      reversedAt: reversedAt ?? this.reversedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum FinanceReportType {
  collection,
  outstanding,
  discount,
  refund,
}

@immutable
class FinanceReportCatalogItem {
  const FinanceReportCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.lastGenerated,
  });

  final String id;
  final String title;
  final String description;
  final FinanceReportType type;
  final String lastGenerated;
}

@immutable
class FinanceReportTrendPoint {
  const FinanceReportTrendPoint({
    required this.label,
    required this.value,
    required this.target,
  });

  final String label;
  final double value;
  final double target;
}

@immutable
class FinanceReportsData {
  const FinanceReportsData({
    required this.catalog,
    required this.collectionTrend,
    required this.outstandingTrend,
    required this.selectedReportId,
  });

  final List<FinanceReportCatalogItem> catalog;
  final List<FinanceReportTrendPoint> collectionTrend;
  final List<FinanceReportTrendPoint> outstandingTrend;
  final String selectedReportId;
}

@immutable
class FinanceSettingItem {
  const FinanceSettingItem({
    required this.id,
    required this.label,
    required this.value,
    required this.description,
    required this.editable,
  });

  final String id;
  final String label;
  final String value;
  final String description;
  final bool editable;
}

@immutable
class FinanceSettingsSection {
  const FinanceSettingsSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<FinanceSettingItem> items;
}

@immutable
class FinanceSettingsData {
  const FinanceSettingsData({
    required this.sections,
    required this.academicYear,
  });

  final List<FinanceSettingsSection> sections;
  final String academicYear;
}

// ── FIN-D3: cancelled register ───────────────────────────────────────────────
@immutable
class CancelledCollection {
  const CancelledCollection({
    required this.id,
    required this.receiptNumber,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.amount,
    required this.mode,
    required this.collectedAt,
    required this.reason,
    required this.cancelledBy,
    required this.cancelledByName,
    required this.cancelledAt,
  });

  final String id;
  final String receiptNumber;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String amount;
  final String mode;
  final String collectedAt;
  final String reason;
  final String cancelledBy;
  final String cancelledByName;
  final String cancelledAt;
}

// ── FIN-D5: late-fee accrual summary ─────────────────────────────────────────
@immutable
class LateFeeAccrualResult {
  const LateFeeAccrualResult({
    required this.accruedCount,
    required this.totalLateFee,
  });

  final int accruedCount;
  final String totalLateFee;
}

// ── FIN-D1: day-close entry ──────────────────────────────────────────────────
enum DayCloseStatus { open, closed }

@immutable
class DayCloseEntry {
  const DayCloseEntry({
    required this.id,
    required this.closeDate,
    required this.status,
    required this.closedBy,
    required this.closedAt,
    required this.reopenedBy,
    required this.reopenedAt,
  });

  final String id;
  final String closeDate;
  final DayCloseStatus status;
  final String closedBy;
  final String closedAt;
  final String reopenedBy;
  final String reopenedAt;

  bool get isClosed => status == DayCloseStatus.closed;
}

// ── FIN-2: printable student ledger / fee statement ──────────────────────────
@immutable
class StudentLedgerAccount {
  const StudentLedgerAccount({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.academicYear,
    required this.totalDue,
    required this.totalPaid,
    required this.balance,
    required this.status,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String academicYear;
  final String totalDue;
  final String totalPaid;
  final String balance;
  final String status;
}

@immutable
class StudentLedgerInvoice {
  const StudentLedgerInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.totalAmount,
    required this.outstandingAmount,
    required this.lateFeeAmount,
    required this.status,
  });

  final String id;
  final String invoiceNumber;
  final String invoiceDate;
  final String dueDate;
  final String totalAmount;
  final String outstandingAmount;
  final String lateFeeAmount;
  final String status;
}

@immutable
class StudentLedgerPayment {
  const StudentLedgerPayment({
    required this.id,
    required this.receiptNumber,
    required this.date,
    required this.mode,
    required this.amount,
    required this.status,
  });

  final String id;
  final String receiptNumber;
  final String date;
  final String mode;
  final String amount;
  final String status;
}

@immutable
class StudentLedgerEntry {
  const StudentLedgerEntry({
    required this.date,
    required this.kind,
    required this.reference,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final String date;
  final String kind; // 'invoice' | 'payment'
  final String reference;
  final String description;
  final String debit;
  final String credit;
  final String balance;
}

@immutable
class StudentLedger {
  const StudentLedger({
    required this.account,
    required this.invoices,
    required this.payments,
    required this.ledger,
  });

  final StudentLedgerAccount account;
  final List<StudentLedgerInvoice> invoices;
  final List<StudentLedgerPayment> payments;
  final List<StudentLedgerEntry> ledger;
}
