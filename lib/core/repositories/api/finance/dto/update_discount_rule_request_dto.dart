import '../../../../../features/finance/finance_requests.dart';
import 'finance_enum_codec.dart';

class UpdateDiscountRuleRequestDto {
  const UpdateDiscountRuleRequestDto({required this.raw});

  factory UpdateDiscountRuleRequestDto.fromDomain(
    UpdateDiscountRuleRequest request,
  ) {
    final raw = <String, dynamic>{};
    if (request.name != null) raw['name'] = request.name;
    if (request.discountPercent != null) {
      raw['discount_percent'] = request.discountPercent;
    }
    if (request.appliesTo != null) raw['applies_to'] = request.appliesTo;
    if (request.status != null) {
      raw['status'] =
          FinanceEnumCodec.discountApprovalStatusToApi(request.status!);
    }
    return UpdateDiscountRuleRequestDto(raw: raw);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
