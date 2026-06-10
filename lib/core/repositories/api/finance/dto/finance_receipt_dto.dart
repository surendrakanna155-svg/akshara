import '../../admissions/dto/api_envelope_dto.dart';

class FinanceReceiptDto {
  const FinanceReceiptDto({required this.raw});

  factory FinanceReceiptDto.fromJson(Map<String, dynamic> json) {
    return FinanceReceiptDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class FinanceReceiptResponseDto {
  const FinanceReceiptResponseDto({required this.raw});

  factory FinanceReceiptResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return FinanceReceiptResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
