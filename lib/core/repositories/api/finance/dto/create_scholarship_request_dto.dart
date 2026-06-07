import '../../../../../features/finance/finance_requests.dart';
import 'finance_enum_codec.dart';

class CreateScholarshipRequestDto {
  const CreateScholarshipRequestDto({required this.raw});

  factory CreateScholarshipRequestDto.fromDomain(CreateScholarshipRequest request) {
    return CreateScholarshipRequestDto(
      raw: {
        'name': request.name,
        'type': FinanceEnumCodec.scholarshipTypeToApi(request.type),
        'max_discount': request.maxDiscount,
        'eligibility': request.eligibility,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
