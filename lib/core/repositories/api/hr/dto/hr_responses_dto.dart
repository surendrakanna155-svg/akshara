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

class HrLeaveRequestDto {
  const HrLeaveRequestDto({required this.raw});

  factory HrLeaveRequestDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrLeaveRequestDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HrPayrollRunDto {
  const HrPayrollRunDto({required this.raw});

  factory HrPayrollRunDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrPayrollRunDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

/// MOD-2 — POST /hr/payroll/structures response ({structure, structures}).
class HrSalaryStructureDto {
  const HrSalaryStructureDto({required this.raw});

  factory HrSalaryStructureDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrSalaryStructureDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

/// MOD-2 — POST /hr/payroll/run/generate response ({run, entries}).
class HrGeneratedPayrollRunDto {
  const HrGeneratedPayrollRunDto({required this.raw});

  factory HrGeneratedPayrollRunDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HrGeneratedPayrollRunDto(raw: envelope.requireData());
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

// --- HR reporting / export reads (HR-1/2/4/5/6/7) --------------------------
// Each report unwraps the {data, error} envelope to a `raw` map/list the mapper
// projects into a report view-model.

class HrSalaryRegisterDto {
  const HrSalaryRegisterDto({required this.raw});

  factory HrSalaryRegisterDto.fromJson(Map<String, dynamic> json) {
    return HrSalaryRegisterDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

class HrPayslipsDto {
  const HrPayslipsDto({required this.raw});

  factory HrPayslipsDto.fromJson(Map<String, dynamic> json) {
    return HrPayslipsDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

class HrAttendanceMusterDto {
  const HrAttendanceMusterDto({required this.raw});

  factory HrAttendanceMusterDto.fromJson(Map<String, dynamic> json) {
    return HrAttendanceMusterDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

class HrLeaveBalancesDto {
  const HrLeaveBalancesDto({required this.raw});

  factory HrLeaveBalancesDto.fromJson(Map<String, dynamic> json) {
    return HrLeaveBalancesDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

class HrHeadcountDto {
  const HrHeadcountDto({required this.raw});

  factory HrHeadcountDto.fromJson(Map<String, dynamic> json) {
    return HrHeadcountDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

class HrEmployeeDirectoryDto {
  const HrEmployeeDirectoryDto({required this.raw});

  factory HrEmployeeDirectoryDto.fromJson(Map<String, dynamic> json) {
    return HrEmployeeDirectoryDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

// --- Final HR slice (HR-3 / HR-D1 / HR-D2) --------------------------------

class HrBatchLeaveDecisionDto {
  const HrBatchLeaveDecisionDto({required this.raw});

  factory HrBatchLeaveDecisionDto.fromJson(Map<String, dynamic> json) {
    return HrBatchLeaveDecisionDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

class HrExpiringDocumentsDto {
  const HrExpiringDocumentsDto({required this.raw});

  factory HrExpiringDocumentsDto.fromJson(Map<String, dynamic> json) {
    return HrExpiringDocumentsDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}

class HrProbationEndingDto {
  const HrProbationEndingDto({required this.raw});

  factory HrProbationEndingDto.fromJson(Map<String, dynamic> json) {
    return HrProbationEndingDto(raw: ApiEnvelopeDto.fromJson(json).requireData());
  }

  final Map<String, dynamic> raw;
}
