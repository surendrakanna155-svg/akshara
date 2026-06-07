import '../../../../../features/finance/finance_requests.dart';

class CreateStudentAccountRequestDto {
  const CreateStudentAccountRequestDto({required this.raw});

  factory CreateStudentAccountRequestDto.fromDomain(
    CreateStudentAccountRequest request,
  ) {
    return CreateStudentAccountRequestDto(
      raw: {
        'student_name': request.studentName,
        'admission_number': request.admissionNumber,
        'class_label': request.classLabel,
        'fee_structure_id': request.feeStructureId,
        'installment_plan_id': request.installmentPlanId,
        if (request.totalDue.isNotEmpty) 'total_due': request.totalDue,
        if (request.installmentPlanLabel.isNotEmpty)
          'installment_plan': request.installmentPlanLabel,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
