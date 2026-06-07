import 'api_envelope_dto.dart';
import 'pagination_dto.dart';

class AdmissionsApplicationDto {
  const AdmissionsApplicationDto({required this.raw});

  factory AdmissionsApplicationDto.fromJson(Map<String, dynamic> json) {
    return AdmissionsApplicationDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class AdmissionsApplicationsResponseDto {
  const AdmissionsApplicationsResponseDto({
    required this.items,
    this.pagination,
  });

  factory AdmissionsApplicationsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AdmissionsApplicationsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          AdmissionsApplicationDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<AdmissionsApplicationDto> items;
  final PaginationDto? pagination;
}
