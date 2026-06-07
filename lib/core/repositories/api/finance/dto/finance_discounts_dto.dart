import '../../admissions/dto/api_envelope_dto.dart';

class DiscountsDashboardDto {
  const DiscountsDashboardDto({required this.raw});

  factory DiscountsDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return DiscountsDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
