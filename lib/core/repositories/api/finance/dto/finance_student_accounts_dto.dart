import '../../admissions/dto/api_envelope_dto.dart';

class StudentFeeAccountDto {
  const StudentFeeAccountDto({required this.raw});

  factory StudentFeeAccountDto.fromJson(Map<String, dynamic> json) {
    return StudentFeeAccountDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class StudentFeeAccountsResponseDto {
  const StudentFeeAccountsResponseDto({required this.items});

  factory StudentFeeAccountsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return StudentFeeAccountsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          StudentFeeAccountDto.fromJson(item),
      ],
    );
  }

  final List<StudentFeeAccountDto> items;
}
