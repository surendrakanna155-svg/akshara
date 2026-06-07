import '../../admissions/dto/api_envelope_dto.dart';
import '../../admissions/dto/pagination_dto.dart';

class StudentFeeAccountDto {
  const StudentFeeAccountDto({required this.raw});

  factory StudentFeeAccountDto.fromJson(Map<String, dynamic> json) {
    return StudentFeeAccountDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class StudentFeeAccountsResponseDto {
  const StudentFeeAccountsResponseDto({
    required this.items,
    this.pagination,
  });

  factory StudentFeeAccountsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return StudentFeeAccountsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          StudentFeeAccountDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<StudentFeeAccountDto> items;
  final PaginationDto? pagination;
}
