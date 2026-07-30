import '../../../../../features/finance/finance_requests.dart';

class AssignFeePlanRequestDto {
  const AssignFeePlanRequestDto({required this.raw});

  factory AssignFeePlanRequestDto.fromDomain(AssignFeePlanRequest request) {
    return AssignFeePlanRequestDto(
      raw: {
        'handoff_id': request.handoffId,
        'fee_structure_id': request.feeStructureId,
        'installment_plan_id': request.installmentPlanId,
        'include_transport': request.includeTransport,
        'include_hostel': request.includeHostel,
        if (request.studentName.isNotEmpty) 'student_name': request.studentName,
        if (request.admissionNumber.isNotEmpty)
          'admission_number': request.admissionNumber,
        if (request.classLabel.isNotEmpty) 'class_label': request.classLabel,
        // Cap 73 — mid-year admission proration inputs.
        if (request.admissionDate?.isNotEmpty ?? false)
          'admission_date': request.admissionDate,
        if (request.prorationPolicyOverride != null)
          'proration_policy_override':
              request.prorationPolicyOverride!.apiValue,
        if (request.prorationOverrideReason?.isNotEmpty ?? false)
          'proration_override_reason': request.prorationOverrideReason,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
