import '../../../../../features/finance/finance_requests.dart';
import 'finance_enum_codec.dart';

class UpdateScholarshipRequestDto {
  const UpdateScholarshipRequestDto({required this.raw});

  factory UpdateScholarshipRequestDto.fromDomain(UpdateScholarshipRequest request) {
    final raw = <String, dynamic>{};
    if (request.name != null) raw['name'] = request.name;
    if (request.type != null) {
      raw['type'] = FinanceEnumCodec.scholarshipTypeToApi(request.type!);
    }
    if (request.maxDiscount != null) raw['max_discount'] = request.maxDiscount;
    if (request.eligibility != null) raw['eligibility'] = request.eligibility;
    return UpdateScholarshipRequestDto(raw: raw);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
