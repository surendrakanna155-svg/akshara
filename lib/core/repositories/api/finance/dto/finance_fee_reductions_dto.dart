import '../../admissions/dto/api_envelope_dto.dart';

/// A single fee-reduction resource (scholarship award / discount application),
/// already unwrapped from the envelope by the remote datasource. Mirrors
/// `feeReductionToApi` in `finance_fee_reductions_repository.ts`.
class FeeReductionDto {
  const FeeReductionDto({required this.raw});

  factory FeeReductionDto.fromJson(Map<String, dynamic> json) {
    return FeeReductionDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class FeeReductionsResponseDto {
  const FeeReductionsResponseDto({required this.items});

  factory FeeReductionsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return FeeReductionsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          FeeReductionDto.fromJson(item),
      ],
    );
  }

  final List<FeeReductionDto> items;
}
