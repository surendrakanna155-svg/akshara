import '../../admissions/dto/api_envelope_dto.dart';
import '../../admissions/dto/pagination_dto.dart';

class SisConversionItemDto {
  const SisConversionItemDto({required this.raw});

  factory SisConversionItemDto.fromJson(Map<String, dynamic> json) {
    return SisConversionItemDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class SisConversionResponseDto {
  const SisConversionResponseDto({
    required this.items,
    this.pagination,
  });

  factory SisConversionResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    final data = envelope.requireData();
    final itemsField = data['items'] ?? data['queue'];
    if (itemsField is List) {
      return SisConversionResponseDto(
        items: [
          for (final item in itemsField)
            if (item is Map<String, dynamic>)
              SisConversionItemDto.fromJson(item),
        ],
        pagination: envelope.pagination,
      );
    }
    return SisConversionResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          SisConversionItemDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<SisConversionItemDto> items;
  final PaginationDto? pagination;
}
