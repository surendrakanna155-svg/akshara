import '../../admissions/dto/api_envelope_dto.dart';
import '../../admissions/dto/pagination_dto.dart';

class SisStudentDto {
  const SisStudentDto({required this.raw});

  factory SisStudentDto.fromJson(Map<String, dynamic> json) {
    return SisStudentDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class SisStudentsResponseDto {
  const SisStudentsResponseDto({
    required this.items,
    this.pagination,
  });

  factory SisStudentsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return SisStudentsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          SisStudentDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<SisStudentDto> items;
  final PaginationDto? pagination;
}
