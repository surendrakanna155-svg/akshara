import 'api_envelope_dto.dart';

class AdmissionsDashboardDto {
  const AdmissionsDashboardDto({required this.raw});

  factory AdmissionsDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AdmissionsDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
