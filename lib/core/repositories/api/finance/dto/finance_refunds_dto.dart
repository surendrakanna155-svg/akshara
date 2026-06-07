import '../../admissions/dto/api_envelope_dto.dart';

class RefundRequestDto {
  const RefundRequestDto({required this.raw});

  factory RefundRequestDto.fromJson(Map<String, dynamic> json) {
    return RefundRequestDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class RefundRequestsResponseDto {
  const RefundRequestsResponseDto({required this.items});

  factory RefundRequestsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return RefundRequestsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          RefundRequestDto.fromJson(item),
      ],
    );
  }

  final List<RefundRequestDto> items;
}
