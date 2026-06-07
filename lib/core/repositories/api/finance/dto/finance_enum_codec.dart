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

  static DiscountApprovalStatus parseDiscountApprovalStatus(String? raw) =>
      switch (raw) {
        'pending' => DiscountApprovalStatus.pending,
        'approved' => DiscountApprovalStatus.approved,
        'rejected' => DiscountApprovalStatus.rejected,
        'active' => DiscountApprovalStatus.active,
        _ => DiscountApprovalStatus.pending,
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
}
