import '../../admissions/dto/api_envelope_dto.dart';

class DiscountsDashboardDto {
  const DiscountsDashboardDto({required this.raw});

  factory DiscountsDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return DiscountsDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

/// A single discount-rule resource (already unwrapped from the envelope by the
/// remote datasource).
class DiscountRuleDto {
  const DiscountRuleDto({required this.raw});

  factory DiscountRuleDto.fromJson(Map<String, dynamic> json) {
    return DiscountRuleDto(raw: json);
  }

  final Map<String, dynamic> raw;
}
