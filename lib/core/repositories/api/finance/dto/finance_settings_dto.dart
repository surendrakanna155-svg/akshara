import '../../admissions/dto/api_envelope_dto.dart';

class FinanceSettingsDto {
  const FinanceSettingsDto({required this.raw});

  factory FinanceSettingsDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return FinanceSettingsDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
