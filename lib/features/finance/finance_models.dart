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

enum OfflinePaymentMethod { cash, cheque, dd }

enum OfflinePaymentStatus { pendingReconciliation, reconciled }

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
  });

  final String accountId;
  final String studentName;
  final String admissionNumber;
  final String feeStructureName;
  final String totalDue;
  final String installmentSummary;
  final List<String> addOns;
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

  FinanceInvoice copyWith({
    InvoiceStatus? invoiceStatus,
    String? invoiceDate,
    String? dueDate,
    String? outstandingAmount,
    String? paidAmount,
    String? updatedAt,
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
  });

  final CollectionPayment payment;
  final List<FinanceKpi> summaryKpis;
  final List<PaymentTimelineEntry> paymentTimeline;
  final List<InstallmentHistoryEntry> installmentHistory;
  final List<ReceiptLink> receiptLinks;
  final String feeAccountId;
  final String aiInsight;
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
