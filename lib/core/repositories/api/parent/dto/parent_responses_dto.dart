import '../../admissions/dto/api_envelope_dto.dart';
import '../../admissions/dto/pagination_dto.dart';

class ParentDashboardDto {
  const ParentDashboardDto({required this.raw});

  factory ParentDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ParentAttendanceResponseDto {
  const ParentAttendanceResponseDto({required this.raw});

  factory ParentAttendanceResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentAttendanceResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ParentHomeworkResponseDto {
  const ParentHomeworkResponseDto({required this.raw});

  factory ParentHomeworkResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentHomeworkResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ParentExamsResponseDto {
  const ParentExamsResponseDto({required this.raw});

  factory ParentExamsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentExamsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ParentTimetableResponseDto {
  const ParentTimetableResponseDto({required this.raw});

  factory ParentTimetableResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentTimetableResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ParentFeesResponseDto {
  const ParentFeesResponseDto({required this.raw});

  factory ParentFeesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentFeesResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ParentReceiptDto {
  const ParentReceiptDto({required this.raw});

  factory ParentReceiptDto.fromJson(Map<String, dynamic> json) {
    return ParentReceiptDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class ParentReceiptsResponseDto {
  const ParentReceiptsResponseDto({
    required this.items,
    this.pagination,
  });

  factory ParentReceiptsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentReceiptsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          ParentReceiptDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<ParentReceiptDto> items;
  final PaginationDto? pagination;
}

/// PAR-D3 — the fee certificate is a single-object envelope (`{ data: {...} }`).
class ParentFeeCertificateResponseDto {
  const ParentFeeCertificateResponseDto({required this.raw});

  factory ParentFeeCertificateResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentFeeCertificateResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ParentNoticeDto {
  const ParentNoticeDto({required this.raw});

  factory ParentNoticeDto.fromJson(Map<String, dynamic> json) {
    return ParentNoticeDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class ParentNoticesResponseDto {
  const ParentNoticesResponseDto({
    required this.items,
    this.pagination,
  });

  factory ParentNoticesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentNoticesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          ParentNoticeDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<ParentNoticeDto> items;
  final PaginationDto? pagination;
}

class ParentEventsResponseDto {
  const ParentEventsResponseDto({required this.raw});

  factory ParentEventsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentEventsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ParentLeaveRequestDto {
  const ParentLeaveRequestDto({required this.raw});

  factory ParentLeaveRequestDto.fromJson(Map<String, dynamic> json) {
    return ParentLeaveRequestDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class ParentLeaveResponseDto {
  const ParentLeaveResponseDto({
    required this.items,
    this.pagination,
  });

  factory ParentLeaveResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentLeaveResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          ParentLeaveRequestDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<ParentLeaveRequestDto> items;
  final PaginationDto? pagination;
}

class ParentProfileResponseDto {
  const ParentProfileResponseDto({required this.raw});

  factory ParentProfileResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentProfileResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ParentPaymentSummaryResponseDto {
  const ParentPaymentSummaryResponseDto({required this.raw});

  factory ParentPaymentSummaryResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ParentPaymentSummaryResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
