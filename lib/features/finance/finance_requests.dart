import 'finance_models.dart';

/// Domain request to create a fee structure.
class CreateFeeStructureRequest {
  const CreateFeeStructureRequest({
    required this.name,
    required this.academicYear,
    required this.totalAnnual,
    required this.classRange,
    required this.categories,
    this.installmentOptions = const [3, 4],
    this.status = FeeStructureStatus.active,
    this.academicYearId,
  });

  final String name;
  final String academicYear;
  final String totalAnnual;
  final String classRange;
  final List<FeeCategoryLine> categories;
  final List<int> installmentOptions;
  final FeeStructureStatus status;
  final String? academicYearId;
}

/// Domain request to update an existing fee structure.
class UpdateFeeStructureRequest {
  const UpdateFeeStructureRequest({
    this.name,
    this.academicYear,
    this.totalAnnual,
    this.classRange,
    this.categories,
    this.installmentOptions,
    this.status,
    this.academicYearId,
  });

  final String? name;
  final String? academicYear;
  final String? totalAnnual;
  final String? classRange;
  final List<FeeCategoryLine>? categories;
  final List<int>? installmentOptions;
  final FeeStructureStatus? status;
  final String? academicYearId;
}

/// Domain request to create a student fee account.
class CreateStudentAccountRequest {
  const CreateStudentAccountRequest({
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.feeStructureId,
    required this.installmentPlanId,
    this.totalDue = '',
    this.installmentPlanLabel = '',
  });

  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String feeStructureId;
  final String installmentPlanId;
  final String totalDue;
  final String installmentPlanLabel;
}

/// Domain request to update a student fee account.
class UpdateStudentAccountRequest {
  const UpdateStudentAccountRequest({
    this.feeStructureId,
    this.installmentPlanId,
    this.totalDue,
    this.totalPaid,
    this.balance,
    this.status,
    this.installmentPlanLabel,
  });

  final String? feeStructureId;
  final String? installmentPlanId;
  final String? totalDue;
  final String? totalPaid;
  final String? balance;
  final FeeAccountStatus? status;
  final String? installmentPlanLabel;
}

/// Assigns a fee structure and installment plan to an admissions handoff.
class AssignFeePlanRequest {
  const AssignFeePlanRequest({
    required this.handoffId,
    required this.feeStructureId,
    required this.installmentPlanId,
    this.includeTransport = false,
    this.includeHostel = false,
    this.studentName = '',
    this.admissionNumber = '',
    this.classLabel = '',
  });

  final String handoffId;
  final String feeStructureId;
  final String installmentPlanId;
  final bool includeTransport;
  final bool includeHostel;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
}

/// Domain request to record a fee collection against an invoice.
class CreateCollectionRequest {
  const CreateCollectionRequest({
    required this.invoiceId,
    required this.amountCollected,
    required this.paymentMethod,
    this.referenceNumber,
    this.notes,
    this.collectionDate,
  });

  final String invoiceId;
  final String amountCollected;
  final String paymentMethod;
  final String? referenceNumber;
  final String? notes;
  final String? collectionDate;
}

/// Domain request to record an offline payment entry for reconciliation.
class RecordOfflinePaymentRequest {
  const RecordOfflinePaymentRequest({
    required this.invoiceId,
    required this.studentName,
    required this.amount,
    required this.method,
    required this.referenceNumber,
    required this.recordedAt,
  });

  final String invoiceId;
  final String studentName;
  final String amount;
  final OfflinePaymentMethod method;
  final String referenceNumber;
  final String recordedAt;
}

/// Domain request to reconcile a pending offline payment into collections.
class ReconcileOfflinePaymentRequest {
  const ReconcileOfflinePaymentRequest({
    this.reconciledAt,
    this.notes,
  });

  final String? reconciledAt;
  final String? notes;
}

/// Domain request to create a UPI QR payment session for an invoice.
class CreateQrPaymentSessionRequest {
  const CreateQrPaymentSessionRequest({
    required this.invoiceId,
    required this.amount,
  });

  final String invoiceId;
  final String amount;
}

/// Domain request to confirm a completed UPI QR payment session.
class ConfirmQrPaymentRequest {
  const ConfirmQrPaymentRequest({
    this.receiptNumber,
  });

  final String? receiptNumber;
}

/// Domain request to create a refund.
class CreateRefundRequest {
  const CreateRefundRequest({
    required this.feeAccountId,
    required this.amount,
    required this.reason,
    this.studentName = '',
    this.admissionNumber = '',
    this.classLabel = '',
    this.originalReceipt = '',
    this.collectionId = '',
  });

  final String feeAccountId;
  final String amount;
  final String reason;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String originalReceipt;
  final String collectionId;
}

/// Approves a pending refund request.
class ApproveRefundRequest {
  const ApproveRefundRequest({
    this.approver = 'Finance Manager',
    this.comment = '',
  });

  final String approver;
  final String comment;
}

/// Domain request to create a scholarship catalog entry.
class CreateScholarshipRequest {
  const CreateScholarshipRequest({
    required this.name,
    required this.type,
    required this.maxDiscount,
    required this.eligibility,
  });

  final String name;
  final ScholarshipType type;
  final String maxDiscount;
  final String eligibility;
}

/// Domain request to update a scholarship catalog entry.
class UpdateScholarshipRequest {
  const UpdateScholarshipRequest({
    this.name,
    this.type,
    this.maxDiscount,
    this.eligibility,
  });

  final String? name;
  final ScholarshipType? type;
  final String? maxDiscount;
  final String? eligibility;
}

/// Single setting value update within a section.
class FinanceSettingUpdate {
  const FinanceSettingUpdate({
    required this.sectionId,
    required this.itemId,
    required this.value,
  });

  final String sectionId;
  final String itemId;
  final String value;
}

/// Domain request to update finance module settings.
class UpdateFinanceSettingsRequest {
  const UpdateFinanceSettingsRequest({
    this.academicYear,
    this.updates = const [],
  });

  final String? academicYear;
  final List<FinanceSettingUpdate> updates;
}
