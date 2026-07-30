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
        // PRA-P1-19 — the real stored object path (omitted when confirming
        // through the presign flow supplies it separately).
        if (request.storagePath != null) 'storage_path': request.storagePath,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
