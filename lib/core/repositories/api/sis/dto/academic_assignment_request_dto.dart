import '../../../../../features/sis/sis_requests.dart';
import 'enrollment_request_dto.dart';

/// @deprecated Prefer [EnrollmentCreateRequestDto] for deployed `/sis/enrollments`.
class AcademicAssignmentRequestDto {
  const AcademicAssignmentRequestDto({required this.raw});

  factory AcademicAssignmentRequestDto.fromDomain(
    AcademicAssignmentRequest request,
  ) {
    return AcademicAssignmentRequestDto(
      raw: EnrollmentCreateRequestDto.fromAcademicAssignment(request).raw,
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
