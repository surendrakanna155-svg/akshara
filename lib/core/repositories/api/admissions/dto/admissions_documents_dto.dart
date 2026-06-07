import 'api_envelope_dto.dart';
import 'pagination_dto.dart';

class StudentDocumentDto {
  const StudentDocumentDto({required this.raw});

  factory StudentDocumentDto.fromJson(Map<String, dynamic> json) {
    return StudentDocumentDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class AdmissionsDocumentsResponseDto {
  const AdmissionsDocumentsResponseDto({
    required this.items,
    this.pagination,
  });

  factory AdmissionsDocumentsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AdmissionsDocumentsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          StudentDocumentDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<StudentDocumentDto> items;
  final PaginationDto? pagination;
}
