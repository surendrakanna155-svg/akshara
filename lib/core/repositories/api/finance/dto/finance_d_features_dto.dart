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
