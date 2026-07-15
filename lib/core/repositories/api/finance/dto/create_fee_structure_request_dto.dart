import '../../../../../features/finance/finance_models.dart';
import '../../../../../features/finance/finance_requests.dart';
import '../../../academic/academic_catalog_placement.dart';
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
        ...catalogPlacementJson(
          AcademicCatalogPlacement(
            academicYearId: request.academicYearId,
            classId: request.classId,
            sectionId: request.sectionId,
          ),
        ),
        // Cap 67 — label-based binding (catalogPlacementJson only carries
        // resolved ids; the label path is finance-specific).
        if (request.className?.isNotEmpty ?? false) ...{
          'class_name': request.className,
          'className': request.className,
        },
        if (request.sectionName?.isNotEmpty ?? false) ...{
          'section_name': request.sectionName,
          'sectionName': request.sectionName,
        },
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
