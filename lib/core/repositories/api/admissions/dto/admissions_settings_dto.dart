import 'api_envelope_dto.dart';

class AdmissionsSettingsDto {
  const AdmissionsSettingsDto({required this.raw});

  factory AdmissionsSettingsDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AdmissionsSettingsDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
