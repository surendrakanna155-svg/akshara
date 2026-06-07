import '../../admissions/dto/api_envelope_dto.dart';

class TransportDashboardDto {
  const TransportDashboardDto({required this.raw});

  factory TransportDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TransportDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class TransportRouteDto {
  const TransportRouteDto({required this.raw});

  factory TransportRouteDto.fromJson(Map<String, dynamic> json) {
    return TransportRouteDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TransportRoutesResponseDto {
  const TransportRoutesResponseDto({required this.items});

  factory TransportRoutesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TransportRoutesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          TransportRouteDto.fromJson(item),
      ],
    );
  }

  final List<TransportRouteDto> items;
}

class TransportVehicleDto {
  const TransportVehicleDto({required this.raw});

  factory TransportVehicleDto.fromJson(Map<String, dynamic> json) {
    return TransportVehicleDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TransportVehiclesResponseDto {
  const TransportVehiclesResponseDto({required this.items});

  factory TransportVehiclesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TransportVehiclesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          TransportVehicleDto.fromJson(item),
      ],
    );
  }

  final List<TransportVehicleDto> items;
}

class TransportDriverDto {
  const TransportDriverDto({required this.raw});

  factory TransportDriverDto.fromJson(Map<String, dynamic> json) {
    return TransportDriverDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TransportDriversResponseDto {
  const TransportDriversResponseDto({required this.items});

  factory TransportDriversResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TransportDriversResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          TransportDriverDto.fromJson(item),
      ],
    );
  }

  final List<TransportDriverDto> items;
}

class TransportAllocationDto {
  const TransportAllocationDto({required this.raw});

  factory TransportAllocationDto.fromJson(Map<String, dynamic> json) {
    return TransportAllocationDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TransportAllocationsResponseDto {
  const TransportAllocationsResponseDto({required this.items});

  factory TransportAllocationsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TransportAllocationsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          TransportAllocationDto.fromJson(item),
      ],
    );
  }

  final List<TransportAllocationDto> items;
}

class TransportAttendanceRecordDto {
  const TransportAttendanceRecordDto({required this.raw});

  factory TransportAttendanceRecordDto.fromJson(Map<String, dynamic> json) {
    return TransportAttendanceRecordDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class TransportAttendanceResponseDto {
  const TransportAttendanceResponseDto({required this.items});

  factory TransportAttendanceResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TransportAttendanceResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          TransportAttendanceRecordDto.fromJson(item),
      ],
    );
  }

  final List<TransportAttendanceRecordDto> items;
}

class TransportTrackingDto {
  const TransportTrackingDto({required this.raw});

  factory TransportTrackingDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TransportTrackingDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class TransportReportsDto {
  const TransportReportsDto({required this.raw});

  factory TransportReportsDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TransportReportsDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class TransportSettingsDto {
  const TransportSettingsDto({required this.raw});

  factory TransportSettingsDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return TransportSettingsDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class OccupancyMetricsDto {
  const OccupancyMetricsDto({required this.raw});

  factory OccupancyMetricsDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return OccupancyMetricsDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
