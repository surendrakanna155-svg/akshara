import '../../../../../features/finance/finance_requests.dart';

class UpdateStudentAccountRequestDto {
  const UpdateStudentAccountRequestDto({required this.raw});

  factory UpdateStudentAccountRequestDto.fromDomain(
    UpdateStudentAccountRequest request,
  ) {
    final raw = <String, dynamic>{};
    if (request.feeStructureId != null) {
      raw['fee_structure_id'] = request.feeStructureId;
    }
    if (request.installmentPlanId != null) {
      raw['installment_plan_id'] = request.installmentPlanId;
    }
    if (request.totalDue != null) raw['total_due'] = request.totalDue;
    if (request.totalPaid != null) raw['total_paid'] = request.totalPaid;
    if (request.balance != null) raw['balance'] = request.balance;
    if (request.status != null) raw['status'] = request.status!.name;
    if (request.installmentPlanLabel != null) {
      raw['installment_plan'] = request.installmentPlanLabel;
    }
    return UpdateStudentAccountRequestDto(raw: raw);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
