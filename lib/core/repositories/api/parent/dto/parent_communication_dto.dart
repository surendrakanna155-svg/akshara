import '../../admissions/dto/api_envelope_dto.dart';

class ParentCommunicationInboxResponseDto {
  const ParentCommunicationInboxResponseDto({required this.raw});

  factory ParentCommunicationInboxResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentCommunicationInboxResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;

  List<Map<String, dynamic>> get items {
    final list = raw['items'] as List<dynamic>? ?? raw['inbox'] as List<dynamic>?;
    if (list == null) return const [];
    return [
      for (final item in list)
        if (item is Map<String, dynamic>) item,
    ];
  }
}

class ParentCommunicationMessageResponseDto {
  const ParentCommunicationMessageResponseDto({required this.raw});

  factory ParentCommunicationMessageResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentCommunicationMessageResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
