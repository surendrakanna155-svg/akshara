import '../../../../../features/transport/transport_models.dart';
import '../dto/transport_enum_codec.dart';
import '../dto/transport_responses_dto.dart';

/// Maps Transport API DTOs to domain models.
class TransportMapper {
  const TransportMapper();

  TransportDashboardData toDashboard(TransportDashboardDto dto) {
    final raw = dto.raw;
    return TransportDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      vehicleAssignments: _mapVehicleAssignments(
        raw['vehicleAssignments'] as List<dynamic>? ?? const [],
      ),
      activeDelays: _stringList(raw['activeDelays']),
      routePerformance: _mapRoutePerformance(
        raw['routePerformance'] as List<dynamic>? ?? const [],
      ),
      occupancy: toOccupancyMetrics(
        OccupancyMetricsDto(
          raw: raw['occupancy'] as Map<String, dynamic>? ?? const {},
        ),
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  List<TransportRoute> toRoutes(TransportRoutesResponseDto dto) {
    return [for (final item in dto.items) toRoute(item)];
  }

  TransportRoute toRoute(TransportRouteDto dto) {
    final raw = dto.raw;
    return TransportRoute(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      stopCount: raw['stopCount'] as int? ?? 0,
      distanceKm: raw['distanceKm'] as String? ?? '',
      amDeparture: raw['amDeparture'] as String? ?? '',
      pmDeparture: raw['pmDeparture'] as String? ?? '',
      assignedBus: raw['assignedBus'] as String? ?? '',
      studentCount: raw['studentCount'] as int? ?? 0,
      status: TransportEnumCodec.parseRouteStatus(raw['status'] as String?),
      stops: _mapStops(raw['stops'] as List<dynamic>? ?? const []),
      shift: TransportEnumCodec.parseShift(raw['shift'] as String?),
    );
  }

  List<TransportVehicle> toVehicles(TransportVehiclesResponseDto dto) {
    return [for (final item in dto.items) toVehicle(item)];
  }

  TransportVehicle toVehicle(TransportVehicleDto dto) {
    final raw = dto.raw;
    return TransportVehicle(
      id: raw['id'] as String? ?? '',
      busNumber: raw['busNumber'] as String? ?? '',
      registration: raw['registration'] as String? ?? '',
      capacity: raw['capacity'] as int? ?? 0,
      routeName: raw['routeName'] as String? ?? '',
      gpsDeviceId: raw['gpsDeviceId'] as String? ?? '',
      insuranceExpiry: raw['insuranceExpiry'] as String? ?? '',
      fitnessExpiry: raw['fitnessExpiry'] as String? ?? '',
      status: TransportEnumCodec.parseVehicleStatus(raw['status'] as String?),
      occupancyPercent: raw['occupancyPercent'] as int? ?? 0,
    );
  }

  List<TransportDriver> toDrivers(TransportDriversResponseDto dto) {
    return [for (final item in dto.items) toDriver(item)];
  }

  TransportDriver toDriver(TransportDriverDto dto) {
    final raw = dto.raw;
    return TransportDriver(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      licenseNumber: raw['licenseNumber'] as String? ?? '',
      licenseExpiry: raw['licenseExpiry'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      assignedBus: raw['assignedBus'] as String? ?? '',
      attendancePercent: raw['attendancePercent'] as String? ?? '',
      rating: raw['rating'] as String? ?? '',
      status: TransportEnumCodec.parseDriverStatus(raw['status'] as String?),
    );
  }

  List<StudentTransportAllocation> toAllocations(
    TransportAllocationsResponseDto dto,
  ) {
    return [for (final item in dto.items) toAllocation(item)];
  }

  StudentTransportAllocation toAllocation(TransportAllocationDto dto) {
    final raw = dto.raw;
    return StudentTransportAllocation(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      admissionNumber: raw['admissionNumber'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      pickupStop: raw['pickupStop'] as String? ?? '',
      dropStop: raw['dropStop'] as String? ?? '',
      routeId: raw['routeId'] as String? ?? '',
      routeName: raw['routeName'] as String? ?? '',
      busNumber: raw['busNumber'] as String? ?? '',
      shift: TransportEnumCodec.parseShift(raw['shift'] as String?),
      sisStudentId: raw['sisStudentId'] as String? ?? '',
    );
  }

  List<TransportAttendanceRecord> toAttendanceRecords(
    TransportAttendanceResponseDto dto,
  ) {
    return [for (final item in dto.items) toAttendanceRecord(item)];
  }

  TransportAttendanceRecord toAttendanceRecord(TransportAttendanceRecordDto dto) {
    final raw = dto.raw;
    return TransportAttendanceRecord(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      stopName: raw['stopName'] as String? ?? '',
      routeName: raw['routeName'] as String? ?? '',
      scheduledTime: raw['scheduledTime'] as String? ?? '',
      actualTime: raw['actualTime'] as String? ?? '',
      status: TransportEnumCodec.parseAttendanceStatus(
        raw['status'] as String?,
      ),
      parentNotified: raw['parentNotified'] as bool? ?? false,
      shift: TransportEnumCodec.parseShift(raw['shift'] as String?),
    );
  }

  TransportDelayNotificationResult toDelayNotification(
    TransportDelayNotificationDto dto,
  ) {
    final raw = dto.raw;
    return TransportDelayNotificationResult(
      routeName: raw['routeName'] as String? ?? '',
      recipientCount: (raw['recipientCount'] as num?)?.toInt() ?? 0,
    );
  }

  TransportTrackingPlaceholderData toTrackingPlaceholder(TransportTrackingDto dto) {
    final raw = dto.raw;
    return TransportTrackingPlaceholderData(
      mapPlaceholderLabel: raw['mapPlaceholderLabel'] as String? ?? '',
      integrationNote: raw['integrationNote'] as String? ?? '',
      parentAppRoute: raw['parentAppRoute'] as String? ?? '',
      vehicles: _mapTrackingVehicles(
        raw['vehicles'] as List<dynamic>? ?? const [],
      ),
    );
  }

  TransportReportsData toReports(TransportReportsDto dto) {
    final raw = dto.raw;
    return TransportReportsData(
      catalog: _mapReportCatalog(raw['catalog'] as List<dynamic>? ?? const []),
      onTimeTrend: _mapTrendPoints(
        raw['onTimeTrend'] as List<dynamic>? ?? const [],
      ),
      delayByRoute: _mapSegments(
        raw['delayByRoute'] as List<dynamic>? ?? const [],
      ),
      fuelTrend: _mapTrendPoints(
        raw['fuelTrend'] as List<dynamic>? ?? const [],
      ),
    );
  }

  TransportSettingsData toSettings(TransportSettingsDto dto) {
    final raw = dto.raw;
    return TransportSettingsData(
      defaultShift: TransportEnumCodec.parseShift(
        raw['defaultShift'] as String?,
      ),
      sections: _mapSettingsSections(
        raw['sections'] as List<dynamic>? ?? const [],
      ),
    );
  }

  OccupancyMetrics toOccupancyMetrics(OccupancyMetricsDto dto) {
    final raw = dto.raw;
    return OccupancyMetrics(
      totalCapacity: raw['totalCapacity'] as int? ?? 0,
      allocatedSeats: raw['allocatedSeats'] as int? ?? 0,
      unassignedStudents: raw['unassignedStudents'] as int? ?? 0,
      utilizationPercent: raw['utilizationPercent'] as int? ?? 0,
    );
  }

  List<TransportKpi> _mapKpis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TransportKpi(
            id: item['id'] as String? ?? '',
            value: item['value'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: TransportEnumCodec.iconForKpi(
              item['icon'] as String?,
              item['accentName'] as String?,
              item['id'] as String?,
            ),
            accentName: item['accentName'] as String? ?? 'neutral',
            detail: item['detail'] as String?,
          ),
    ];
  }

  List<VehicleAssignment> _mapVehicleAssignments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          VehicleAssignment(
            id: item['id'] as String? ?? '',
            busNumber: item['busNumber'] as String? ?? '',
            routeName: item['routeName'] as String? ?? '',
            driverName: item['driverName'] as String? ?? '',
            shift: TransportEnumCodec.parseShift(item['shift'] as String?),
            studentCount: item['studentCount'] as int? ?? 0,
            trackingStatus: TransportEnumCodec.parseTrackingStatus(
              item['trackingStatus'] as String?,
            ),
            etaLabel: item['etaLabel'] as String? ?? '',
          ),
    ];
  }

  List<RoutePerformance> _mapRoutePerformance(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          RoutePerformance(
            routeName: item['routeName'] as String? ?? '',
            onTimePercent: item['onTimePercent'] as String? ?? '',
            avgDelayMinutes: item['avgDelayMinutes'] as int? ?? 0,
            utilizationPercent: item['utilizationPercent'] as int? ?? 0,
            incidents: item['incidents'] as int? ?? 0,
          ),
    ];
  }

  List<TransportStop> _mapStops(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TransportStop(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            sequence: item['sequence'] as int? ?? 0,
            scheduledTime: item['scheduledTime'] as String? ?? '',
            status: TransportEnumCodec.parseStopStatus(
              item['status'] as String?,
            ),
            latitude: (item['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (item['longitude'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<TrackingVehicleStatus> _mapTrackingVehicles(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TrackingVehicleStatus(
            busNumber: item['busNumber'] as String? ?? '',
            routeName: item['routeName'] as String? ?? '',
            driverName: item['driverName'] as String? ?? '',
            status: TransportEnumCodec.parseTrackingStatus(
              item['status'] as String?,
            ),
            speedKph: item['speedKph'] as int? ?? 0,
            lastPing: item['lastPing'] as String? ?? '',
            nextStop: item['nextStop'] as String? ?? '',
            studentCount: item['studentCount'] as int? ?? 0,
            etaMinutes: item['etaMinutes'] as int? ?? 0,
            latitude: (item['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (item['longitude'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<TransportReportCatalogItem> _mapReportCatalog(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TransportReportCatalogItem(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            description: item['description'] as String? ?? '',
            lastGenerated: item['lastGenerated'] as String? ?? '',
          ),
    ];
  }

  List<TransportTrendPoint> _mapTrendPoints(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TransportTrendPoint(
            label: item['label'] as String? ?? '',
            amountLakhs: (item['amountLakhs'] as num?)?.toDouble() ?? 0,
            targetLakhs: (item['targetLakhs'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<TransportSegment> _mapSegments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TransportSegment(
            label: item['label'] as String? ?? '',
            value: (item['value'] as num?)?.toDouble() ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<TransportSettingsSection> _mapSettingsSections(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TransportSettingsSection(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            items: _mapSettingItems(item['items'] as List<dynamic>? ?? const []),
          ),
    ];
  }

  List<TransportSettingItem> _mapSettingItems(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TransportSettingItem(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            value: item['value'] as String? ?? '',
            description: item['description'] as String? ?? '',
            editable: item['editable'] as bool? ?? false,
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
