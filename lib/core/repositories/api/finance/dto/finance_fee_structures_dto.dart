import '../../admissions/dto/api_envelope_dto.dart';

export 'finance_fee_assignment_dto.dart';

class FinanceFeeStructureDto {
  const FinanceFeeStructureDto({required this.raw});

  factory FinanceFeeStructureDto.fromJson(Map<String, dynamic> json) {
    return FinanceFeeStructureDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class FinanceFeeStructuresResponseDto {
  const FinanceFeeStructuresResponseDto({required this.items});

  factory FinanceFeeStructuresResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return FinanceFeeStructuresResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          FinanceFeeStructureDto.fromJson(item),
      ],
    );
  }

  final List<FinanceFeeStructureDto> items;
}

class FinanceAcademicYearsResponseDto {
  const FinanceAcademicYearsResponseDto({required this.items});

  factory FinanceAcademicYearsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    final data = envelope.requireData();
    final yearsField = data['years'] ?? data['items'];
    if (yearsField is List) {
      return FinanceAcademicYearsResponseDto(
        items: [
          for (final item in yearsField)
            if (item is String) item,
        ],
      );
    }
    return FinanceAcademicYearsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          item['year'] as String? ?? item['label'] as String? ?? '',
      ],
    );
  }

  final List<String> items;
}
