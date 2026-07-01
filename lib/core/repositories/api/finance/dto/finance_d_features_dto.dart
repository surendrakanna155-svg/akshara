import '../../admissions/dto/api_envelope_dto.dart';

// FIN-D1 / FIN-D3 / FIN-D5 / FIN-2 — response DTOs for the additive finance
// features. Each holds the raw JSON map; the mapper reads camelCase keys the
// backend emits.

// ── FIN-D3: cancelled register ───────────────────────────────────────────────
class CancelledCollectionDto {
  const CancelledCollectionDto({required this.raw});

  factory CancelledCollectionDto.fromJson(Map<String, dynamic> json) {
    return CancelledCollectionDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class CancelledCollectionsResponseDto {
  const CancelledCollectionsResponseDto({required this.items});

  factory CancelledCollectionsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return CancelledCollectionsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          CancelledCollectionDto.fromJson(item),
      ],
    );
  }

  final List<CancelledCollectionDto> items;
}

// ── FIN-D5: late-fee accrual result ──────────────────────────────────────────
class LateFeeAccrualResultDto {
  const LateFeeAccrualResultDto({required this.raw});

  factory LateFeeAccrualResultDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return LateFeeAccrualResultDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

// ── FIN-D1: day-close entries ────────────────────────────────────────────────
class DayCloseEntryDto {
  const DayCloseEntryDto({required this.raw});

  factory DayCloseEntryDto.fromJson(Map<String, dynamic> json) {
    return DayCloseEntryDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class DayCloseEntriesResponseDto {
  const DayCloseEntriesResponseDto({required this.items});

  factory DayCloseEntriesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return DayCloseEntriesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          DayCloseEntryDto.fromJson(item),
      ],
    );
  }

  final List<DayCloseEntryDto> items;
}

// ── FIN-2: printable student ledger ──────────────────────────────────────────
class StudentLedgerDto {
  const StudentLedgerDto({required this.raw});

  factory StudentLedgerDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return StudentLedgerDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

// ── FIN-6: invoice installment schedule ──────────────────────────────────────
class InstallmentScheduleEntryDto {
  const InstallmentScheduleEntryDto({required this.raw});

  factory InstallmentScheduleEntryDto.fromJson(Map<String, dynamic> json) {
    return InstallmentScheduleEntryDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class InstallmentScheduleResponseDto {
  const InstallmentScheduleResponseDto({required this.items});

  factory InstallmentScheduleResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return InstallmentScheduleResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          InstallmentScheduleEntryDto.fromJson(item),
      ],
    );
  }

  final List<InstallmentScheduleEntryDto> items;
}

// ── FIN-9: head-wise dues analytics ──────────────────────────────────────────
class HeadWiseDueDto {
  const HeadWiseDueDto({required this.raw});

  factory HeadWiseDueDto.fromJson(Map<String, dynamic> json) {
    return HeadWiseDueDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class HeadWiseDuesResponseDto {
  const HeadWiseDuesResponseDto({required this.items});

  factory HeadWiseDuesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HeadWiseDuesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          HeadWiseDueDto.fromJson(item),
      ],
    );
  }

  final List<HeadWiseDueDto> items;
}
