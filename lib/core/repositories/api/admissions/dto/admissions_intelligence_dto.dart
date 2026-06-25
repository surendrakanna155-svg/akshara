import 'api_envelope_dto.dart';

/// Raw envelope wrapper for GET /admissions/intelligence (B4).
class AdmissionsIntelligenceDto {
  const AdmissionsIntelligenceDto({required this.raw});

  factory AdmissionsIntelligenceDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AdmissionsIntelligenceDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
