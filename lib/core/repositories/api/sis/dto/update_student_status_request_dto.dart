import '../../../../../features/sis/sis_requests.dart';
import 'sis_enum_codec.dart';

class UpdateStudentStatusRequestDto {
  const UpdateStudentStatusRequestDto({required this.raw});

  factory UpdateStudentStatusRequestDto.fromDomain(
    UpdateStudentStatusRequest request,
  ) {
    return UpdateStudentStatusRequestDto(
      raw: {
        'status': SisEnumCodec.studentStatusToApi(request.status),
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
