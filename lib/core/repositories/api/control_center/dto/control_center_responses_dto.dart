import '../../admissions/dto/api_envelope_dto.dart';
import '../../admissions/dto/pagination_dto.dart';

class ControlCenterDashboardDto {
  const ControlCenterDashboardDto({required this.raw});

  factory ControlCenterDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ControlCenterDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class PlatformSchoolDto {
  const PlatformSchoolDto({required this.raw});

  factory PlatformSchoolDto.fromJson(Map<String, dynamic> json) {
    return PlatformSchoolDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class PlatformSchoolsResponseDto {
  const PlatformSchoolsResponseDto({
    required this.items,
    this.pagination,
  });

  factory PlatformSchoolsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return PlatformSchoolsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          PlatformSchoolDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<PlatformSchoolDto> items;
  final PaginationDto? pagination;
}

class ControlCenterSubscriptionsResponseDto {
  const ControlCenterSubscriptionsResponseDto({required this.raw});

  factory ControlCenterSubscriptionsResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ControlCenterSubscriptionsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ControlCenterBillingResponseDto {
  const ControlCenterBillingResponseDto({required this.raw});

  factory ControlCenterBillingResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ControlCenterBillingResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ControlCenterCrmResponseDto {
  const ControlCenterCrmResponseDto({required this.raw});

  factory ControlCenterCrmResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ControlCenterCrmResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class SupportTicketDto {
  const SupportTicketDto({required this.raw});

  factory SupportTicketDto.fromJson(Map<String, dynamic> json) {
    return SupportTicketDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class SupportTicketsResponseDto {
  const SupportTicketsResponseDto({
    required this.items,
    this.pagination,
  });

  factory SupportTicketsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return SupportTicketsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          SupportTicketDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<SupportTicketDto> items;
  final PaginationDto? pagination;
}

class ControlCenterSuccessResponseDto {
  const ControlCenterSuccessResponseDto({required this.raw});

  factory ControlCenterSuccessResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ControlCenterSuccessResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class WhiteLabelConfigDto {
  const WhiteLabelConfigDto({required this.raw});

  factory WhiteLabelConfigDto.fromJson(Map<String, dynamic> json) {
    return WhiteLabelConfigDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class WhiteLabelConfigsResponseDto {
  const WhiteLabelConfigsResponseDto({
    required this.items,
    this.pagination,
  });

  factory WhiteLabelConfigsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return WhiteLabelConfigsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          WhiteLabelConfigDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<WhiteLabelConfigDto> items;
  final PaginationDto? pagination;
}

class ControlCenterAnalyticsResponseDto {
  const ControlCenterAnalyticsResponseDto({required this.raw});

  factory ControlCenterAnalyticsResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ControlCenterAnalyticsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ControlCenterMonitoringResponseDto {
  const ControlCenterMonitoringResponseDto({required this.raw});

  factory ControlCenterMonitoringResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ControlCenterMonitoringResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ControlCenterRolesResponseDto {
  const ControlCenterRolesResponseDto({required this.raw});

  factory ControlCenterRolesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ControlCenterRolesResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class ControlCenterSettingsResponseDto {
  const ControlCenterSettingsResponseDto({required this.raw});

  factory ControlCenterSettingsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return ControlCenterSettingsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
