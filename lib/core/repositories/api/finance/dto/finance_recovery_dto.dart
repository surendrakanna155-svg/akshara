import '../../admissions/dto/api_envelope_dto.dart';

/// FIN-R4 — a single recovery contact log entry.
class RecoveryContactDto {
  const RecoveryContactDto({required this.raw});

  factory RecoveryContactDto.fromJson(Map<String, dynamic> json) {
    return RecoveryContactDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

/// FIN-R4 — `{items: [...]}` list of recovery contacts for a student.
class RecoveryContactsResponseDto {
  const RecoveryContactsResponseDto({required this.items});

  factory RecoveryContactsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return RecoveryContactsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          RecoveryContactDto.fromJson(item),
      ],
    );
  }

  final List<RecoveryContactDto> items;
}

/// FIN-R3 — a single promise-to-pay entry.
class PromiseToPayDto {
  const PromiseToPayDto({required this.raw});

  factory PromiseToPayDto.fromJson(Map<String, dynamic> json) {
    return PromiseToPayDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

/// FIN-R3 — `{items: [...]}` list of promises-to-pay.
class PromisesToPayResponseDto {
  const PromisesToPayResponseDto({required this.items});

  factory PromisesToPayResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return PromisesToPayResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          PromiseToPayDto.fromJson(item),
      ],
    );
  }

  final List<PromiseToPayDto> items;
}

/// FIN-R1/R5 — recovery dashboard aggregates + collector performance.
class RecoveryDashboardDto {
  const RecoveryDashboardDto({required this.raw});

  factory RecoveryDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return RecoveryDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
