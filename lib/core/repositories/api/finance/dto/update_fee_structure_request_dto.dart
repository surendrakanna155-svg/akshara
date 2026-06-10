import '../../../academic/academic_catalog_placement.dart';
import '../../../../../features/finance/finance_models.dart';
import '../../../../../features/finance/finance_requests.dart';
import 'finance_enum_codec.dart';

class UpdateFeeStructureRequestDto {
  const UpdateFeeStructureRequestDto({required this.raw});

  factory UpdateFeeStructureRequestDto.fromDomain(UpdateFeeStructureRequest request) {
    final raw = <String, dynamic>{};
    if (request.name != null) raw['name'] = request.name;
    if (request.academicYear != null) raw['academic_year'] = request.academicYear;
    if (request.totalAnnual != null) raw['total_annual'] = request.totalAnnual;
    if (request.classRange != null) raw['class_range'] = request.classRange;
    if (request.status != null) {
      raw['status'] = _statusToApi(request.status!);
    }
    if (request.installmentOptions != null) {
      raw['installment_options'] = request.installmentOptions;
    }
    raw.addAll(
      catalogPlacementJson(
        AcademicCatalogPlacement(academicYearId: request.academicYearId),
      ),
    );
    if (request.categories != null) {
      raw['categories'] = [
        for (final line in request.categories!)
          {
            'category': FinanceEnumCodec.feeStructureCategoryToApi(line.category),
            'label': line.label,
            'amount': line.amount,
          },
      ];
    }
    return UpdateFeeStructureRequestDto(raw: raw);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;

  static String _statusToApi(FeeStructureStatus status) => switch (status) {
        FeeStructureStatus.active => 'active',
        FeeStructureStatus.inactive => 'inactive',
      };
}
