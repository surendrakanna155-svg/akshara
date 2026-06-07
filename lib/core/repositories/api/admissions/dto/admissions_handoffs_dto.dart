import 'api_envelope_dto.dart';
import 'pagination_dto.dart';

class ApprovedStudentHandoffDto {
  const ApprovedStudentHandoffDto({required this.raw});

  factory ApprovedStudentHandoffDto.fromJson(Map<String, dynamic> json) {
    return ApprovedStudentHandoffDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class AdmissionsHandoffsResponseDto {
  const AdmissionsHandoffsResponseDto({
    required this.items,
    this.pagination,
  });

  factory AdmissionsHandoffsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AdmissionsHandoffsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          ApprovedStudentHandoffDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<ApprovedStudentHandoffDto> items;
  final PaginationDto? pagination;
}

class FeeStructureOptionDto {
  const FeeStructureOptionDto({required this.raw});

  factory FeeStructureOptionDto.fromJson(Map<String, dynamic> json) {
    return FeeStructureOptionDto(raw: json);
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class AdmissionsFeeStructuresResponseDto {
  const AdmissionsFeeStructuresResponseDto({
    required this.items,
    this.pagination,
  });

  factory AdmissionsFeeStructuresResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return AdmissionsFeeStructuresResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          FeeStructureOptionDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<FeeStructureOptionDto> items;
  final PaginationDto? pagination;
}
