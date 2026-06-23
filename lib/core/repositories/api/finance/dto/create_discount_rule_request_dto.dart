import '../../../../../features/finance/finance_requests.dart';

class CreateDiscountRuleRequestDto {
  const CreateDiscountRuleRequestDto({required this.raw});

  factory CreateDiscountRuleRequestDto.fromDomain(
    CreateDiscountRuleRequest request,
  ) {
    return CreateDiscountRuleRequestDto(
      raw: {
        'name': request.name,
        'discount_percent': request.discountPercent,
        'applies_to': request.appliesTo,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
