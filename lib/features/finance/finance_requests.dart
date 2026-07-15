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
    this.classId,
    this.className,
    this.sectionId,
    this.sectionName,
  });

  final String name;
  final String academicYear;
  final String totalAnnual;
  final String classRange;
  final List<FeeCategoryLine> categories;
  final List<int> installmentOptions;
  final FeeStructureStatus status;
  final String? academicYearId;

  // Cap 67 — OPTIONAL class/section binding; either an id (resolves
  // directly) or a label (resolved server-side against the academic year,
  // same id-or-label contract as academicYearId/academicYear). Both omitted
  // = unbound, exactly today's behaviour.
  final String? classId;
  final String? className;
  final String? sectionId;
  final String? sectionName;
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
    this.classId,
    this.className,
    this.sectionId,
    this.sectionName,
    this.unbindClass = false,
  });

  final String? name;
  final String? academicYear;
  final String? totalAnnual;
  final String? classRange;
  final List<FeeCategoryLine>? categories;
  final List<int>? installmentOptions;
  final FeeStructureStatus? status;
  final String? academicYearId;

  // Cap 67 — see CreateFeeStructureRequest. Null on ALL FOUR = binding left
  // untouched. [unbindClass] explicitly clears an existing binding (mutually
  // exclusive with the four fields above — set one or the other).
  final String? classId;
  final String? className;
  final String? sectionId;
  final String? sectionName;
  final bool unbindClass;
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
    this.admissionDate,
    this.prorationPolicyOverride,
    this.prorationOverrideReason,
  });

  final String handoffId;
  final String feeStructureId;
  final String installmentPlanId;
  final bool includeTransport;
  final bool includeHostel;
  final String studentName;
  final String admissionNumber;
  final String classLabel;

  // Cap 73 (owner decision #5) — the admission/assignment reference date
  // proration is computed against ('YYYY-MM-DD'); defaults server-side to
  // today when omitted. [prorationPolicyOverride] lets an authorized user
  // override the school's configured policy for THIS ONE assignment —
  // [prorationOverrideReason] is REQUIRED whenever an override is set (the
  // server rejects an override with no reason; both are preserved for audit
  // alongside the acting user and timestamp).
  final String? admissionDate;
  final FeeProrationPolicy? prorationPolicyOverride;
  final String? prorationOverrideReason;
}

/// PRC-A gap fix — bulk/class-wide fee-structure assignment
/// (`POST /finance/fee-assignments/bulk`). Applies [feeStructureId] +
/// [academicYear] across every id in [studentIds], reusing the exact same
/// per-student assignment math as [AssignFeePlanRequest]'s single-student
/// flow; a student who already has this structure for this year is reported
/// back as skipped, not treated as an error.
///
/// Cap 67 — [studentIds] may be EMPTY when the target fee structure is class/
/// section-bound: the server then auto-resolves the roster FROM that
/// binding. A non-empty list is always authoritative (explicit path
/// unchanged).
class BulkAssignFeePlanRequest {
  const BulkAssignFeePlanRequest({
    required this.feeStructureId,
    required this.academicYear,
    required this.studentIds,
    this.admissionDate,
    this.prorationPolicyOverride,
    this.prorationOverrideReason,
  });

  final String feeStructureId;
  final String academicYear;
  final List<String> studentIds;

  // Cap 73 — see AssignFeePlanRequest; applied uniformly across the batch.
  final String? admissionDate;
  final FeeProrationPolicy? prorationPolicyOverride;
  final String? prorationOverrideReason;
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
    this.instrumentDate,
    this.bankName,
  });

  final String invoiceId;
  final String studentName;
  final String amount;
  final OfflinePaymentMethod method;
  final String referenceNumber;
  final String recordedAt;

  /// FIN-R7: cheque/DD/PDC date (a PDC's future maturity date). ISO-8601 date.
  final String? instrumentDate;
  final String? bankName;
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

/// FIN-R7: domain request to mark a pending instrument (cheque/DD/PDC) as
/// bounced/dishonoured. Tracking-only — reverses no money.
class BounceOfflinePaymentRequest {
  const BounceOfflinePaymentRequest({this.reason, this.bouncedAt});

  final String? reason;
  final String? bouncedAt;
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

/// Create a discount rule (e.g. "Early bird payment — 5% off annual fee").
class CreateDiscountRuleRequest {
  const CreateDiscountRuleRequest({
    required this.name,
    required this.discountPercent,
    required this.appliesTo,
  });

  final String name;
  final String discountPercent;
  final String appliesTo;
}

/// Edit an existing discount rule; null fields are left unchanged.
class UpdateDiscountRuleRequest {
  const UpdateDiscountRuleRequest({
    this.name,
    this.discountPercent,
    this.appliesTo,
    this.status,
  });

  final String? name;
  final String? discountPercent;
  final String? appliesTo;
  final DiscountApprovalStatus? status;
}

/// FIN-R6 — set a collector's monthly collection target. [periodMonth] is
/// `YYYY-MM`; [target] is a whole-rupee amount string. Principal-only action.
class SetCollectionTargetRequest {
  const SetCollectionTargetRequest({
    required this.collectorUserId,
    required this.periodMonth,
    required this.target,
  });

  final String collectorUserId;
  final String periodMonth;
  final String target;
}

/// FIN-R4 — log a recovery contact attempt against a defaulter.
class LogRecoveryContactRequest {
  const LogRecoveryContactRequest({
    required this.studentId,
    required this.channel,
    required this.outcome,
    this.feeAccountId,
    this.notes = '',
  });

  final String studentId;
  final RecoveryChannel channel;
  final RecoveryOutcome outcome;
  final String? feeAccountId;
  final String notes;
}

/// FIN-R3 — record a student's promise to pay.
class CreatePromiseToPayRequest {
  const CreatePromiseToPayRequest({
    required this.studentId,
    required this.amount,
    required this.promiseDate,
    this.feeAccountId,
    this.notes = '',
  });

  final String studentId;
  final String amount;

  /// YYYY-MM-DD.
  final String promiseDate;
  final String? feeAccountId;
  final String notes;
}

/// FIN-R3 — resolve a pending promise to pay.
class ResolvePromiseToPayRequest {
  const ResolvePromiseToPayRequest({required this.status});

  /// One of kept | broken | cancelled.
  final PromiseToPayStatus status;
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
