import '../../admissions/dto/api_envelope_dto.dart';

class SisDashboardDto {
  const SisDashboardDto({required this.raw});

  factory SisDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return SisDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
