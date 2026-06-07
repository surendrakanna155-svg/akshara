import '../../admissions/dto/api_envelope_dto.dart';
import '../../admissions/dto/pagination_dto.dart';

class HrDashboardDto {
  const HrDashboardDto({required this.raw});

  factory HrDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HrEmployeeDto {
  const HrEmployeeDto({required this.raw});

  factory HrEmployeeDto.fromJson(Map<String, dynamic> json) {
    return HrEmployeeDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class HrEmployeesResponseDto {
  const HrEmployeesResponseDto({
    required this.items,
    this.pagination,
  });

  factory HrEmployeesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrEmployeesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          HrEmployeeDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<HrEmployeeDto> items;
  final PaginationDto? pagination;
}

class HrEmployeeDetailDto {
  const HrEmployeeDetailDto({required this.raw});

  factory HrEmployeeDetailDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrEmployeeDetailDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HrAttendanceResponseDto {
  const HrAttendanceResponseDto({required this.raw});

  factory HrAttendanceResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrAttendanceResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HrLeaveResponseDto {
  const HrLeaveResponseDto({required this.raw});

  factory HrLeaveResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrLeaveResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HrPayrollResponseDto {
  const HrPayrollResponseDto({required this.raw});

  factory HrPayrollResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrPayrollResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HrRecruitmentResponseDto {
  const HrRecruitmentResponseDto({required this.raw});

  factory HrRecruitmentResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrRecruitmentResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HrPerformanceResponseDto {
  const HrPerformanceResponseDto({required this.raw});

  factory HrPerformanceResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrPerformanceResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HrSettingsResponseDto {
  const HrSettingsResponseDto({required this.raw});

  factory HrSettingsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrSettingsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
