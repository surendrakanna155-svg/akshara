import '../../admissions/dto/api_envelope_dto.dart';

class HostelDashboardDto {
  const HostelDashboardDto({required this.raw});

  factory HostelDashboardDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HostelDashboardDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HostelStudentDto {
  const HostelStudentDto({required this.raw});

  factory HostelStudentDto.fromJson(Map<String, dynamic> json) {
    return HostelStudentDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class HostelStudentsResponseDto {
  const HostelStudentsResponseDto({required this.items});

  factory HostelStudentsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HostelStudentsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          HostelStudentDto.fromJson(item),
      ],
    );
  }

  final List<HostelStudentDto> items;
}

class HostelRoomDto {
  const HostelRoomDto({required this.raw});

  factory HostelRoomDto.fromJson(Map<String, dynamic> json) {
    return HostelRoomDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class HostelRoomsResponseDto {
  const HostelRoomsResponseDto({required this.items});

  factory HostelRoomsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HostelRoomsResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          HostelRoomDto.fromJson(item),
      ],
    );
  }

  final List<HostelRoomDto> items;
}

class HostelAttendanceRecordDto {
  const HostelAttendanceRecordDto({required this.raw});

  factory HostelAttendanceRecordDto.fromJson(Map<String, dynamic> json) {
    return HostelAttendanceRecordDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class HostelAttendanceResponseDto {
  const HostelAttendanceResponseDto({required this.items});

  factory HostelAttendanceResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HostelAttendanceResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          HostelAttendanceRecordDto.fromJson(item),
      ],
    );
  }

  final List<HostelAttendanceRecordDto> items;
}

class HostelLeaveRequestDto {
  const HostelLeaveRequestDto({required this.raw});

  factory HostelLeaveRequestDto.fromJson(Map<String, dynamic> json) {
    return HostelLeaveRequestDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class HostelLeaveResponseDto {
  const HostelLeaveResponseDto({required this.items});

  factory HostelLeaveResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HostelLeaveResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          HostelLeaveRequestDto.fromJson(item),
      ],
    );
  }

  final List<HostelLeaveRequestDto> items;
}

class HostelMessResponseDto {
  const HostelMessResponseDto({required this.raw});

  factory HostelMessResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HostelMessResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HostelVisitorsResponseDto {
  const HostelVisitorsResponseDto({required this.raw});

  factory HostelVisitorsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HostelVisitorsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HostelReportsResponseDto {
  const HostelReportsResponseDto({required this.raw});

  factory HostelReportsResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HostelReportsResponseDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

class HostelOccupancyMetricsDto {
  const HostelOccupancyMetricsDto({required this.raw});

  factory HostelOccupancyMetricsDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return HostelOccupancyMetricsDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}
