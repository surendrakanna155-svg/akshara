import '../../../../../features/sis/sis_requests.dart';

/// SIS-3 — request body for PATCH /sis/students/{id}/documents/{docId}/verify.
/// Backend contract: `{ status: 'verified' | 'rejected', note? }`.
class VerifyStudentDocumentRequestDto {
  const VerifyStudentDocumentRequestDto({required this.raw});

  factory VerifyStudentDocumentRequestDto.fromDomain(
    VerifyStudentDocumentRequest request,
  ) {
    final note = request.note?.trim();
    return VerifyStudentDocumentRequestDto(
      raw: {
        'status': request.decision.name,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
