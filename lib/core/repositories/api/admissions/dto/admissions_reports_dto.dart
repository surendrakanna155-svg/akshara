import 'api_envelope_dto.dart';

class AdmissionsReportsDto {
  const AdmissionsReportsDto({required this.raw});

  factory AdmissionsReportsDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AdmissionsReportsDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
