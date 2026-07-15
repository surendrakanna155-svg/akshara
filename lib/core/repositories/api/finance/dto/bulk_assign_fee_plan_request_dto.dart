import '../../../../../features/finance/finance_requests.dart';

/// PRC-A gap fix — request body for `POST /finance/fee-assignments/bulk`.
class BulkAssignFeePlanRequestDto {
  const BulkAssignFeePlanRequestDto({required this.raw});

  factory BulkAssignFeePlanRequestDto.fromDomain(
    BulkAssignFeePlanRequest request,
  ) {
    return BulkAssignFeePlanRequestDto(
      raw: {
        'fee_structure_id': request.feeStructureId,
        'feeStructureId': request.feeStructureId,
        'academic_year': request.academicYear,
        'academicYear': request.academicYear,
        'student_ids': request.studentIds,
        'studentIds': request.studentIds,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
