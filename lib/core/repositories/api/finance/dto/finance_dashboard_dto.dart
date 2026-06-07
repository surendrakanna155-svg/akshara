import '../../admissions/dto/api_envelope_dto.dart';

class FinanceDashboardDto {
  const FinanceDashboardDto({required this.raw});

  factory FinanceDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return FinanceDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
