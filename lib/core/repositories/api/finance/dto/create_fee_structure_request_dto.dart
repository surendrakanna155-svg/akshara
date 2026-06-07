import '../../../../../features/finance/finance_models.dart';
import '../../../../../features/finance/finance_requests.dart';
import 'finance_enum_codec.dart';

class CreateFeeStructureRequestDto {
  const CreateFeeStructureRequestDto({required this.raw});

  factory CreateFeeStructureRequestDto.fromDomain(CreateFeeStructureRequest request) {
    return CreateFeeStructureRequestDto(
      raw: {
        'name': request.name,
        'academic_year': request.academicYear,
        'total_annual': request.totalAnnual,
        'class_range': request.classRange,
        'status': _statusToApi(request.status),
        'installment_options': request.installmentOptions,
        'categories': [
          for (final line in request.categories)
            {
              'category': FinanceEnumCodec.feeStructureCategoryToApi(line.category),
              'label': line.label,
              'amount': line.amount,
            },
        ],
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;

  static String _statusToApi(FeeStructureStatus status) => switch (status) {
        FeeStructureStatus.active => 'active',
        FeeStructureStatus.inactive => 'inactive',
      };
}
