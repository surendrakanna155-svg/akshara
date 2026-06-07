import '../../admissions/dto/api_envelope_dto.dart';

class FinanceReportsDto {
  const FinanceReportsDto({required this.raw});

  factory FinanceReportsDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return FinanceReportsDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
