import '../../admissions/dto/api_envelope_dto.dart';

class CollectionPaymentDto {
  const CollectionPaymentDto({required this.raw});

  factory CollectionPaymentDto.fromJson(Map<String, dynamic> json) {
    return CollectionPaymentDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class FinanceCollectionsResponseDto {
  const FinanceCollectionsResponseDto({required this.items});

  factory FinanceCollectionsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return FinanceCollectionsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          CollectionPaymentDto.fromJson(item),
      ],
    );
  }

  final List<CollectionPaymentDto> items;
}

class DailyCollectionSummaryDto {
  const DailyCollectionSummaryDto({required this.raw});

  factory DailyCollectionSummaryDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return DailyCollectionSummaryDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class CollectionDetailDto {
  const CollectionDetailDto({required this.raw});

  factory CollectionDetailDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return CollectionDetailDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
