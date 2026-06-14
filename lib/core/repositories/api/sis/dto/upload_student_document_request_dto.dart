import '../../../../../features/sis/sis_requests.dart';

class UploadStudentDocumentRequestDto {
  const UploadStudentDocumentRequestDto({required this.raw});

  factory UploadStudentDocumentRequestDto.fromDomain(
    UploadStudentDocumentRequest request,
  ) {
    return UploadStudentDocumentRequestDto(
      raw: {
        'type': request.type,
        'fileName': request.fileName,
        'status': request.status,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
