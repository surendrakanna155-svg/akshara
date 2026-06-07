import 'api_envelope_dto.dart';
import 'pagination_dto.dart';

class PendingEnrollmentDto {
  const PendingEnrollmentDto({required this.raw});

  factory PendingEnrollmentDto.fromJson(Map<String, dynamic> json) {
    return PendingEnrollmentDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class AdmissionsEnrollmentsResponseDto {
  const AdmissionsEnrollmentsResponseDto({
    required this.items,
    this.pagination,
  });

  factory AdmissionsEnrollmentsResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AdmissionsEnrollmentsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          PendingEnrollmentDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<PendingEnrollmentDto> items;
  final PaginationDto? pagination;
}

class EnrollmentPrefillDto {
  const EnrollmentPrefillDto({required this.raw});

  factory EnrollmentPrefillDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return EnrollmentPrefillDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
