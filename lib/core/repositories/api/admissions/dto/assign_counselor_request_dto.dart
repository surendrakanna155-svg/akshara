import '../../../../../features/admissions/admissions_requests.dart';

class AssignCounselorRequestDto {
  const AssignCounselorRequestDto({required this.raw});

  factory AssignCounselorRequestDto.fromDomain(AssignCounselorRequest request) {
    return AssignCounselorRequestDto(
      raw: {'counselor': request.counselor},
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
