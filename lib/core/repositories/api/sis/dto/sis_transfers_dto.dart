import '../../admissions/dto/api_envelope_dto.dart';
import '../../admissions/dto/pagination_dto.dart';

/// SIS-5 — one raw transfer / exit-log row from GET /sis/transfers.
class SisTransferDto {
  const SisTransferDto({required this.raw});

  factory SisTransferDto.fromJson(Map<String, dynamic> json) {
    return SisTransferDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

/// SIS-5 — paginated envelope for GET /sis/transfers (same shape as
/// /sis/students: `{ data: { items, pagination } }`).
class SisTransfersResponseDto {
  const SisTransfersResponseDto({
    required this.items,
    this.pagination,
  });

  factory SisTransfersResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return SisTransfersResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          SisTransferDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<SisTransferDto> items;
  final PaginationDto? pagination;
}
