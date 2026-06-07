import '../../admissions/dto/api_envelope_dto.dart';

class DefaultersDashboardDto {
  const DefaultersDashboardDto({required this.raw});

  factory DefaultersDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return DefaultersDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
