import '../../admissions/dto/api_envelope_dto.dart';

/// FN-04 Fee assignment plan item.
class FeeAssignmentPlanDto {
  const FeeAssignmentPlanDto({required this.raw});

  factory FeeAssignmentPlanDto.fromJson(Map<String, dynamic> json) {
    return FeeAssignmentPlanDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

/// FN-04 Fee assignment response (installment plans).
class FinanceFeeAssignmentResponseDto {
  const FinanceFeeAssignmentResponseDto({required this.items});

  factory FinanceFeeAssignmentResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return FinanceFeeAssignmentResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          FeeAssignmentPlanDto.fromJson(item),
      ],
    );
  }

  final List<FeeAssignmentPlanDto> items;
}

/// @deprecated Use [FeeAssignmentPlanDto].
typedef InstallmentPlanDto = FeeAssignmentPlanDto;

/// @deprecated Use [FinanceFeeAssignmentResponseDto].
typedef InstallmentPlansResponseDto = FinanceFeeAssignmentResponseDto;
