import '../../../../../features/finance/finance_models.dart';

/// Serializes finance enums to/from API snake_case strings.
class FinanceEnumCodec {
  const FinanceEnumCodec();

  static FeeStructureCategory parseFeeStructureCategory(String? raw) =>
      switch (raw) {
        'tuition' => FeeStructureCategory.tuition,
        'transport' => FeeStructureCategory.transport,
        'hostel' => FeeStructureCategory.hostel,
        'activity' => FeeStructureCategory.activity,
        _ => FeeStructureCategory.tuition,
      };

  static String feeStructureCategoryToApi(FeeStructureCategory category) =>
      switch (category) {
        FeeStructureCategory.tuition => 'tuition',
        FeeStructureCategory.transport => 'transport',
        FeeStructureCategory.hostel => 'hostel',
        FeeStructureCategory.activity => 'activity',
      };

  static FeeStructureStatus parseFeeStructureStatus(String? raw) =>
      switch (raw) {
        'active' => FeeStructureStatus.active,
        'inactive' => FeeStructureStatus.inactive,
        _ => FeeStructureStatus.active,
      };

  static FeeAccountStatus parseFeeAccountStatus(String? raw) => switch (raw) {
        'active' => FeeAccountStatus.active,
        'overdue' => FeeAccountStatus.overdue,
        'closed' => FeeAccountStatus.closed,
        'pending' => FeeAccountStatus.pending,
        _ => FeeAccountStatus.active,
      };

  static CollectionStatus parseCollectionStatus(String? raw) => switch (raw) {
        'completed' => CollectionStatus.completed,
        'pending' => CollectionStatus.pending,
        'failed' => CollectionStatus.failed,
        'refunded' => CollectionStatus.refunded,
        _ => CollectionStatus.completed,
      };

  static OfflinePaymentMethod parseOfflinePaymentMethod(String? raw) =>
      switch (raw) {
        'cash' => OfflinePaymentMethod.cash,
        'cheque' || 'check' => OfflinePaymentMethod.cheque,
        'dd' || 'demand_draft' || 'demandDraft' => OfflinePaymentMethod.dd,
        _ => OfflinePaymentMethod.cash,
      };

  static String offlinePaymentMethodToApi(OfflinePaymentMethod method) =>
      switch (method) {
        OfflinePaymentMethod.cash => 'cash',
        OfflinePaymentMethod.cheque => 'cheque',
        OfflinePaymentMethod.dd => 'dd',
      };

  static OfflinePaymentStatus parseOfflinePaymentStatus(String? raw) =>
      switch (raw) {
        'pending_reconciliation' ||
        'pendingReconciliation' =>
          OfflinePaymentStatus.pendingReconciliation,
        'reconciled' => OfflinePaymentStatus.reconciled,
        _ => OfflinePaymentStatus.pendingReconciliation,
      };

  static String offlinePaymentStatusToApi(OfflinePaymentStatus status) =>
      switch (status) {
        OfflinePaymentStatus.pendingReconciliation => 'pending_reconciliation',
        OfflinePaymentStatus.reconciled => 'reconciled',
      };

  static InstallmentPlanType parseInstallmentPlanType(String? raw) =>
      switch (raw) {
        'quarterly' => InstallmentPlanType.quarterly,
        'termly' => InstallmentPlanType.termly,
        'monthly' => InstallmentPlanType.monthly,
        'annual' => InstallmentPlanType.annual,
        _ => InstallmentPlanType.quarterly,
      };

  static DefaulterAgingBucket parseDefaulterAgingBucket(String? raw) =>
      switch (raw) {
        'current' => DefaulterAgingBucket.current,
        'days_1_to_30' || 'days1to30' => DefaulterAgingBucket.days1to30,
        'days_31_to_60' || 'days31to60' => DefaulterAgingBucket.days31to60,
        'days_61_to_90' || 'days61to90' => DefaulterAgingBucket.days61to90,
        'over_90' || 'over90' => DefaulterAgingBucket.over90,
        _ => DefaulterAgingBucket.current,
      };

  static RefundStatus parseRefundStatus(String? raw) => switch (raw) {
        'pending' => RefundStatus.pending,
        'approved' => RefundStatus.approved,
        'rejected' => RefundStatus.rejected,
        'processed' => RefundStatus.processed,
        _ => RefundStatus.pending,
      };

  static InvoiceStatus parseInvoiceStatus(String? raw) => switch (raw) {
        'draft' => InvoiceStatus.draft,
        'issued' => InvoiceStatus.issued,
        'partially_paid' || 'partiallyPaid' => InvoiceStatus.partiallyPaid,
        'paid' => InvoiceStatus.paid,
        'cancelled' || 'canceled' || 'void' => InvoiceStatus.cancelled,
        _ => InvoiceStatus.issued,
      };

  static String invoiceStatusToApi(InvoiceStatus status) => switch (status) {
        InvoiceStatus.draft => 'draft',
        InvoiceStatus.issued => 'issued',
        InvoiceStatus.partiallyPaid => 'partially_paid',
        InvoiceStatus.paid => 'paid',
        InvoiceStatus.cancelled => 'cancelled',
      };

  static CollectionStatus invoiceStatusToCollectionStatus(
          InvoiceStatus status) =>
      switch (status) {
        InvoiceStatus.paid => CollectionStatus.completed,
        InvoiceStatus.cancelled => CollectionStatus.refunded,
        InvoiceStatus.partiallyPaid => CollectionStatus.pending,
        InvoiceStatus.draft => CollectionStatus.pending,
        InvoiceStatus.issued => CollectionStatus.pending,
      };

  static DiscountApprovalStatus parseDiscountApprovalStatus(String? raw) =>
      switch (raw) {
        'pending' => DiscountApprovalStatus.pending,
        'approved' => DiscountApprovalStatus.approved,
        'rejected' => DiscountApprovalStatus.rejected,
        'active' => DiscountApprovalStatus.active,
        _ => DiscountApprovalStatus.pending,
      };

  static String discountApprovalStatusToApi(DiscountApprovalStatus status) =>
      switch (status) {
        DiscountApprovalStatus.pending => 'pending',
        DiscountApprovalStatus.approved => 'approved',
        DiscountApprovalStatus.rejected => 'rejected',
        DiscountApprovalStatus.active => 'active',
      };

  static ScholarshipType parseScholarshipType(String? raw) => switch (raw) {
        'merit' => ScholarshipType.merit,
        'need_based' || 'needBased' => ScholarshipType.needBased,
        'sibling' => ScholarshipType.sibling,
        'staff_child' || 'staffChild' => ScholarshipType.staffChild,
        'sports' => ScholarshipType.sports,
        _ => ScholarshipType.merit,
      };

  static String scholarshipTypeToApi(ScholarshipType type) => switch (type) {
        ScholarshipType.merit => 'merit',
        ScholarshipType.needBased => 'need_based',
        ScholarshipType.sibling => 'sibling',
        ScholarshipType.staffChild => 'staff_child',
        ScholarshipType.sports => 'sports',
      };

  static FinanceReportType parseFinanceReportType(String? raw) => switch (raw) {
        'collection' => FinanceReportType.collection,
        'outstanding' => FinanceReportType.outstanding,
        'discount' => FinanceReportType.discount,
        'refund' => FinanceReportType.refund,
        _ => FinanceReportType.collection,
      };

  static RecoveryChannel parseRecoveryChannel(String? raw) => switch (raw) {
        'call' => RecoveryChannel.call,
        'whatsapp' => RecoveryChannel.whatsapp,
        'sms' => RecoveryChannel.sms,
        'visit' => RecoveryChannel.visit,
        'email' => RecoveryChannel.email,
        _ => RecoveryChannel.other,
      };

  static String recoveryChannelToApi(RecoveryChannel channel) =>
      switch (channel) {
        RecoveryChannel.call => 'call',
        RecoveryChannel.whatsapp => 'whatsapp',
        RecoveryChannel.sms => 'sms',
        RecoveryChannel.visit => 'visit',
        RecoveryChannel.email => 'email',
        RecoveryChannel.other => 'other',
      };

  static RecoveryOutcome parseRecoveryOutcome(String? raw) => switch (raw) {
        'reached' => RecoveryOutcome.reached,
        'no_answer' || 'noAnswer' => RecoveryOutcome.noAnswer,
        'promised' => RecoveryOutcome.promised,
        'refused' => RecoveryOutcome.refused,
        'wrong_number' || 'wrongNumber' => RecoveryOutcome.wrongNumber,
        'partial_paid' || 'partialPaid' => RecoveryOutcome.partialPaid,
        _ => RecoveryOutcome.other,
      };

  static String recoveryOutcomeToApi(RecoveryOutcome outcome) =>
      switch (outcome) {
        RecoveryOutcome.reached => 'reached',
        RecoveryOutcome.noAnswer => 'no_answer',
        RecoveryOutcome.promised => 'promised',
        RecoveryOutcome.refused => 'refused',
        RecoveryOutcome.wrongNumber => 'wrong_number',
        RecoveryOutcome.partialPaid => 'partial_paid',
        RecoveryOutcome.other => 'other',
      };

  static PromiseToPayStatus parsePromiseToPayStatus(String? raw) =>
      switch (raw) {
        'pending' => PromiseToPayStatus.pending,
        'kept' => PromiseToPayStatus.kept,
        'broken' => PromiseToPayStatus.broken,
        'cancelled' || 'canceled' => PromiseToPayStatus.cancelled,
        _ => PromiseToPayStatus.pending,
      };

  static String promiseToPayStatusToApi(PromiseToPayStatus status) =>
      switch (status) {
        PromiseToPayStatus.pending => 'pending',
        PromiseToPayStatus.kept => 'kept',
        PromiseToPayStatus.broken => 'broken',
        PromiseToPayStatus.cancelled => 'cancelled',
      };
}
