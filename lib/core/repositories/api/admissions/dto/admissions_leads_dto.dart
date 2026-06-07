import 'api_envelope_dto.dart';
import 'pagination_dto.dart';

class AdmissionsLeadDto {
  const AdmissionsLeadDto({required this.raw});

  factory AdmissionsLeadDto.fromJson(Map<String, dynamic> json) {
    return AdmissionsLeadDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class AdmissionsLeadsResponseDto {
  const AdmissionsLeadsResponseDto({
    required this.items,
    this.pagination,
  });

  factory AdmissionsLeadsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AdmissionsLeadsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          AdmissionsLeadDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<AdmissionsLeadDto> items;
  final PaginationDto? pagination;
}
