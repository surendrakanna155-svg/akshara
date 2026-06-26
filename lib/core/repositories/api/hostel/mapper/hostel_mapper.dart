import '../../../../../features/hostel/hostel_models.dart';
import '../dto/hostel_enum_codec.dart';
import '../dto/hostel_responses_dto.dart';

/// Maps Hostel API DTOs to domain models.
class HostelMapper {
  const HostelMapper();

  HostelDashboardData toDashboard(HostelDashboardDto dto) {
    final raw = dto.raw;
    return HostelDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      blockOccupancy: _mapBlockOccupancy(
        raw['blockOccupancy'] as List<dynamic>? ?? const [],
      ),
      sessionAttendance: _mapSessionAttendance(
        raw['sessionAttendance'] as List<dynamic>? ?? const [],
      ),
      activeVisitorCount: raw['activeVisitorCount'] as int? ?? 0,
      healthAlerts: _stringList(raw['healthAlerts']),
      missingStudents: _stringList(raw['missingStudents']),
      occupancy: toOccupancyMetrics(
        HostelOccupancyMetricsDto(
          raw: raw['occupancy'] as Map<String, dynamic>? ?? const {},
        ),
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  List<HostelStudent> toStudents(HostelStudentsResponseDto dto) {
    return [for (final item in dto.items) toStudent(item)];
  }

  HostelStudent toStudent(HostelStudentDto dto) {
    final raw = dto.raw;
    return HostelStudent(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      admissionNumber: raw['admissionNumber'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      block: raw['block'] as String? ?? '',
      room: raw['room'] as String? ?? '',
      bed: raw['bed'] as String? ?? '',
      sisStudentId: raw['sisStudentId'] as String? ?? '',
      status: HostelEnumCodec.parseStudentStatus(raw['status'] as String?),
      feePending: raw['feePending'] as String? ?? '',
      parentAppLinked: raw['parentAppLinked'] as bool? ?? false,
    );
  }

  List<HostelRoom> toRooms(HostelRoomsResponseDto dto) {
    return [for (final item in dto.items) toRoom(item)];
  }

  HostelRoom toRoom(HostelRoomDto dto) {
    final raw = dto.raw;
    return HostelRoom(
      id: raw['id'] as String? ?? '',
      block: raw['block'] as String? ?? '',
      roomNumber: raw['roomNumber'] as String? ?? '',
      floor: raw['floor'] as int? ?? 0,
      type: HostelEnumCodec.parseRoomType(raw['type'] as String?),
      totalBeds: raw['totalBeds'] as int? ?? 0,
      occupiedBeds: raw['occupiedBeds'] as int? ?? 0,
      status: HostelEnumCodec.parseRoomStatus(raw['status'] as String?),
      facilities: raw['facilities'] as String? ?? '',
    );
  }

  List<HostelAttendanceRecord> toAttendanceRecords(
    HostelAttendanceResponseDto dto,
  ) {
    return [for (final item in dto.items) toAttendanceRecord(item)];
  }

  HostelAttendanceRecord toAttendanceRecord(HostelAttendanceRecordDto dto) {
    final raw = dto.raw;
    return HostelAttendanceRecord(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      room: raw['room'] as String? ?? '',
      rollNumber: raw['rollNumber'] as String? ?? '',
      morning: HostelEnumCodec.parseAttendanceStatus(
        raw['morning'] as String?,
      ),
      evening: HostelEnumCodec.parseAttendanceStatus(
        raw['evening'] as String?,
      ),
      night: HostelEnumCodec.parseAttendanceStatus(raw['night'] as String?),
      overallStatus: HostelEnumCodec.parseAttendanceStatus(
        raw['overallStatus'] as String?,
      ),
      remark: raw['remark'] as String? ?? '',
      parentNotified: raw['parentNotified'] as bool? ?? false,
      sisStudentId: raw['sisStudentId'] as String? ?? '',
    );
  }

  List<HostelLeaveRequest> toLeaveRequests(HostelLeaveResponseDto dto) {
    return [for (final item in dto.items) toLeaveRequest(item)];
  }

  HostelLeaveRequest toLeaveRequest(HostelLeaveRequestDto dto) {
    final raw = dto.raw;
    return HostelLeaveRequest(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      room: raw['room'] as String? ?? '',
      fromDate: raw['fromDate'] as String? ?? '',
      toDate: raw['toDate'] as String? ?? '',
      days: raw['days'] as int? ?? 0,
      reason: raw['reason'] as String? ?? '',
      parentContact: raw['parentContact'] as String? ?? '',
      status: HostelEnumCodec.parseLeaveStatus(raw['status'] as String?),
      gatePassId: raw['gatePassId'] as String?,
      sisStudentId: raw['sisStudentId'] as String? ?? '',
      parentAppRoute: raw['parentAppRoute'] as String? ?? '',
    );
  }

  HostelMessData toMessData(HostelMessResponseDto dto) {
    final raw = dto.raw;
    return HostelMessData(
      weeklyMenus: _mapMealMenus(
        raw['weeklyMenus'] as List<dynamic>? ?? const [],
      ),
      consumptionTrend: _mapTrendPoints(
        raw['consumptionTrend'] as List<dynamic>? ?? const [],
      ),
      costMtd: raw['costMtd'] as String? ?? '',
      financeIntegrationNote: raw['financeIntegrationNote'] as String? ?? '',
    );
  }

  HostelVisitorsData toVisitors(HostelVisitorsResponseDto dto) {
    final raw = dto.raw;
    return HostelVisitorsData(
      activeVisitors: _mapVisitors(
        raw['activeVisitors'] as List<dynamic>? ?? const [],
      ),
      visitorLog: _mapVisitors(
        raw['visitorLog'] as List<dynamic>? ?? const [],
      ),
      qrPlaceholderLabel: raw['qrPlaceholderLabel'] as String? ?? '',
      parentAppRoute: raw['parentAppRoute'] as String? ?? '',
    );
  }

  HostelReportsData toReports(HostelReportsResponseDto dto) {
    final raw = dto.raw;
    return HostelReportsData(
      catalog: _mapReportCatalog(raw['catalog'] as List<dynamic>? ?? const []),
      occupancyTrend: _mapTrendPoints(
        raw['occupancyTrend'] as List<dynamic>? ?? const [],
      ),
      attendanceByBlock: _mapSegments(
        raw['attendanceByBlock'] as List<dynamic>? ?? const [],
      ),
      messCostTrend: _mapTrendPoints(
        raw['messCostTrend'] as List<dynamic>? ?? const [],
      ),
    );
  }

  HostelOccupancyMetrics toOccupancyMetrics(HostelOccupancyMetricsDto dto) {
    final raw = dto.raw;
    return HostelOccupancyMetrics(
      totalBeds: raw['totalBeds'] as int? ?? 0,
      occupiedBeds: raw['occupiedBeds'] as int? ?? 0,
      vacantBeds: raw['vacantBeds'] as int? ?? 0,
      utilizationPercent: raw['utilizationPercent'] as int? ?? 0,
    );
  }

  List<HostelKpi> _mapKpis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HostelKpi(
            id: item['id'] as String? ?? '',
            value: item['value'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: HostelEnumCodec.iconForKpi(
              item['icon'] as String?,
              item['accentName'] as String?,
              item['id'] as String?,
            ),
            accentName: item['accentName'] as String? ?? 'neutral',
            detail: item['detail'] as String?,
          ),
    ];
  }

  List<HostelTrendPoint> _mapTrendPoints(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HostelTrendPoint(
            label: item['label'] as String? ?? '',
            amountLakhs: (item['amountLakhs'] as num?)?.toDouble() ?? 0,
            targetLakhs: (item['targetLakhs'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<HostelSegment> _mapSegments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HostelSegment(
            label: item['label'] as String? ?? '',
            value: (item['value'] as num?)?.toDouble() ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<HostelBlockOccupancy> _mapBlockOccupancy(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HostelBlockOccupancy(
            block: item['block'] as String? ?? '',
            occupied: item['occupied'] as int? ?? 0,
            total: item['total'] as int? ?? 0,
            percent: item['percent'] as int? ?? 0,
          ),
    ];
  }

  List<HostelSessionAttendance> _mapSessionAttendance(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HostelSessionAttendance(
            session: HostelEnumCodec.parseAttendanceSession(
              item['session'] as String?,
            ),
            present: item['present'] as int? ?? 0,
            absent: item['absent'] as int? ?? 0,
            onLeave: item['onLeave'] as int? ?? 0,
          ),
    ];
  }

  HostelMealMenu toMealMenu(HostelMealMenuDto dto) => _mapMealMenu(dto.raw);

  List<HostelMealMenu> _mapMealMenus(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) _mapMealMenu(item),
    ];
  }

  HostelMealMenu _mapMealMenu(Map<String, dynamic> item) {
    return HostelMealMenu(
      day: item['day'] as String? ?? '',
      mealType: HostelEnumCodec.parseMealType(item['mealType'] as String?),
      items: item['items'] as String? ?? '',
      dietaryTags: _stringList(item['dietaryTags']),
    );
  }

  HostelVisitor toVisitor(HostelVisitorDto dto) => _mapVisitor(dto.raw);

  List<HostelVisitor> _mapVisitors(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) _mapVisitor(item),
    ];
  }

  HostelVisitor _mapVisitor(Map<String, dynamic> item) {
    return HostelVisitor(
      id: item['id'] as String? ?? '',
      visitorName: item['visitorName'] as String? ?? '',
      relation: item['relation'] as String? ?? '',
      studentName: item['studentName'] as String? ?? '',
      sisStudentId: item['sisStudentId'] as String? ?? '',
      checkIn: item['checkIn'] as String? ?? '',
      checkOut: item['checkOut'] as String?,
      passId: item['passId'] as String? ?? '',
      status: HostelEnumCodec.parseVisitorStatus(
        item['status'] as String?,
      ),
    );
  }

  List<HostelReportCatalogItem> _mapReportCatalog(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HostelReportCatalogItem(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            description: item['description'] as String? ?? '',
            lastGenerated: item['lastGenerated'] as String? ?? '',
          ),
    ];
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item != null) '$item',
    ];
  }
}
