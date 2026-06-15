import '../../admissions/dto/api_envelope_dto.dart';

class ManagementDashboardDto {
  const ManagementDashboardDto({required this.raw});

  factory ManagementDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ManagementDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ManagementAnalyticsResponseDto {
  const ManagementAnalyticsResponseDto({required this.raw});

  factory ManagementAnalyticsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ManagementAnalyticsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ManagementAdmissionsFunnelResponseDto {
  const ManagementAdmissionsFunnelResponseDto({required this.raw});

  factory ManagementAdmissionsFunnelResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ManagementAdmissionsFunnelResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ManagementFinancialHealthResponseDto {
  const ManagementFinancialHealthResponseDto({required this.raw});

  factory ManagementFinancialHealthResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ManagementFinancialHealthResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ManagementAcademicHealthResponseDto {
  const ManagementAcademicHealthResponseDto({required this.raw});

  factory ManagementAcademicHealthResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ManagementAcademicHealthResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ManagementPerformanceResponseDto {
  const ManagementPerformanceResponseDto({required this.raw});

  factory ManagementPerformanceResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ManagementPerformanceResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ManagementTasksResponseDto {
  const ManagementTasksResponseDto({required this.raw});

  factory ManagementTasksResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ManagementTasksResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ManagementSettingsResponseDto {
  const ManagementSettingsResponseDto({required this.raw});

  factory ManagementSettingsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ManagementSettingsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ManagementApprovalResponseDto {
  const ManagementApprovalResponseDto({required this.raw});

  final Map<String, dynamic> raw;
}
