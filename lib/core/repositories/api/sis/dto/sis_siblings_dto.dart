import '../../admissions/dto/api_envelope_dto.dart';

/// SIS-4 — one raw sibling summary row from GET /sis/students/:id/siblings.
class SisSiblingDto {
  const SisSiblingDto({required this.raw});

  factory SisSiblingDto.fromJson(Map<String, dynamic> json) {
    return SisSiblingDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

/// SIS-4 — envelope for GET /sis/students/:id/siblings. The backend returns
/// `{ data: { siblings: [...] } }`; older/alternate shapes exposing `items` are
/// tolerated so the mapping stays resilient.
class SisSiblingsResponseDto {
  const SisSiblingsResponseDto({required this.items});

  factory SisSiblingsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    final data = envelope.data;
    final rawList = (data is Map<String, dynamic>)
        ? (data['siblings'] ?? data['items'])
        : null;
    final list = rawList is List ? rawList : const [];
    return SisSiblingsResponseDto(
      items: [
        for (final item in list)
          if (item is Map<String, dynamic>) SisSiblingDto.fromJson(item),
      ],
    );
  }

  final List<SisSiblingDto> items;
}
