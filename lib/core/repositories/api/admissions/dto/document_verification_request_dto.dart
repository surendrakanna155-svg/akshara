import '../../../../../features/admissions/admissions_models.dart';
import '../../../../../features/admissions/admissions_requests.dart';

class DocumentUploadRequestDto {
  const DocumentUploadRequestDto({required this.raw});

  factory DocumentUploadRequestDto.fromDomain(DocumentUploadRequest request) {
    return DocumentUploadRequestDto(
      raw: {
        'lead_id': request.leadId,
        'document_type': _documentTypeToApi(request.documentType),
        'file_name': request.fileName,
        'student_name': request.studentName,
        'class_label': request.classLabel,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;

  static String _documentTypeToApi(DocumentType type) => switch (type) {
        DocumentType.birthCertificate => 'birth_certificate',
        DocumentType.aadhaar => 'aadhaar',
        DocumentType.marksMemo => 'marks_memo',
        DocumentType.transferCertificate => 'transfer_certificate',
        DocumentType.photos => 'photos',
        DocumentType.medical => 'medical',
      };
}

class DocumentVerificationRequestDto {
  const DocumentVerificationRequestDto({required this.raw});

  factory DocumentVerificationRequestDto.fromDomain(
    DocumentVerificationRequest request,
  ) {
    return DocumentVerificationRequestDto(raw: {'note': request.note});
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
