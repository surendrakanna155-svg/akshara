import 'package:akshara_erp/core/repositories/api/transport/dto/transport_enum_codec.dart';
import 'package:akshara_erp/features/transport/transport_models.dart';

/// Builds API-shaped JSON envelopes from Transport domain models for contract tests.
class TransportFixtureBuilder {
  const TransportFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> occupancyItem(OccupancyMetrics metrics) => {
        'totalCapacity': metrics.totalCapacity,
        'allocatedSeats': metrics.allocatedSeats,
        'unassignedStudents': metrics.unassignedStudents,
        'utilizationPercent': metrics.utilizationPercent,
      };

  Map<String, dynamic> dashboardEnvelope(TransportDashboardData data) {
    return envelope({
      'aiInsight': data.aiInsight,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'vehicleAssignments': [
        for (final assignment in data.vehicleAssignments)
          {
            'id': assignment.id,
            'busNumber': assignment.busNumber,
            'routeName': assignment.routeName,
            'driverName': assignment.driverName,
            'shift': TransportEnumCodec.shiftToApi(assignment.shift),
            'studentCount': assignment.studentCount,
            'trackingStatus':
                TransportEnumCodec.trackingStatusToApi(assignment.trackingStatus),
            'etaLabel': assignment.etaLabel,
          },
      ],
      'activeDelays': data.activeDelays,
      'routePerformance': [
        for (final performance in data.routePerformance)
          {
            'routeName': performance.routeName,
            'onTimePercent': performance.onTimePercent,
            'avgDelayMinutes': performance.avgDelayMinutes,
            'utilizationPercent': performance.utilizationPercent,
            'incidents': performance.incidents,
          },
      ],
      'occupancy': occupancyItem(data.occupancy),
    });
  }

  /// BUS-006 — emits the CANONICAL stop-time keys the backend actually writes
  /// (`pickupTime` / `dropTime`). This fixture previously emitted
  /// `scheduledTime`, mirroring the client mapper's mistake rather than the
  /// server's real payload — so the contract test agreed with the bug and could
  /// never have caught it.
  Map<String, dynamic> stopItem(TransportStop stop) => {
        'id': stop.id,
        'name': stop.name,
        'sequence': stop.sequence,
        'pickupTime': stop.pickupTime,
        'dropTime': stop.dropTime,
        'status': TransportEnumCodec.stopStatusToApi(stop.status),
        'latitude': stop.latitude,
        'longitude': stop.longitude,
      };

  /// BUS-006 — legacy-shaped stop payload (pre-fix seed rows carry
  /// `scheduledTime` and no drop time). Used to pin the read-only back-compat
  /// fallback in the mapper.
  Map<String, dynamic> legacyStopItem(TransportStop stop) => {
        'id': stop.id,
        'name': stop.name,
        'sequence': stop.sequence,
        'scheduledTime': stop.pickupTime,
        'status': TransportEnumCodec.stopStatusToApi(stop.status),
        'latitude': stop.latitude,
        'longitude': stop.longitude,
      };

  Map<String, dynamic> routeItem(TransportRoute route) => {
        'id': route.id,
        'name': route.name,
        'stopCount': route.stopCount,
        'distanceKm': route.distanceKm,
        'amDeparture': route.amDeparture,
        'pmDeparture': route.pmDeparture,
        'assignedBus': route.assignedBus,
        'studentCount': route.studentCount,
        'status': TransportEnumCodec.routeStatusToApi(route.status),
        'stops': [for (final stop in route.stops) stopItem(stop)],
        'shift': TransportEnumCodec.shiftToApi(route.shift),
      };

  Map<String, dynamic> routesEnvelope(List<TransportRoute> routes) {
    return listEnvelope([for (final route in routes) routeItem(route)]);
  }

  Map<String, dynamic> vehicleItem(TransportVehicle vehicle) => {
        'id': vehicle.id,
        'busNumber': vehicle.busNumber,
        'registration': vehicle.registration,
        'capacity': vehicle.capacity,
        'routeName': vehicle.routeName,
        'gpsDeviceId': vehicle.gpsDeviceId,
        'insuranceExpiry': vehicle.insuranceExpiry,
        'fitnessExpiry': vehicle.fitnessExpiry,
        'status': TransportEnumCodec.vehicleStatusToApi(vehicle.status),
        'occupancyPercent': vehicle.occupancyPercent,
      };

  Map<String, dynamic> vehiclesEnvelope(List<TransportVehicle> vehicles) {
    return listEnvelope([for (final vehicle in vehicles) vehicleItem(vehicle)]);
  }

  Map<String, dynamic> driverItem(TransportDriver driver) => {
        'id': driver.id,
        'name': driver.name,
        'licenseNumber': driver.licenseNumber,
        'licenseExpiry': driver.licenseExpiry,
        'phone': driver.phone,
        'assignedBus': driver.assignedBus,
        'attendancePercent': driver.attendancePercent,
        'rating': driver.rating,
        'status': TransportEnumCodec.driverStatusToApi(driver.status),
      };

  Map<String, dynamic> driversEnvelope(List<TransportDriver> drivers) {
    return listEnvelope([for (final driver in drivers) driverItem(driver)]);
  }

  Map<String, dynamic> allocationItem(StudentTransportAllocation allocation) =>
      {
        'id': allocation.id,
        'studentName': allocation.studentName,
        'admissionNumber': allocation.admissionNumber,
        'classLabel': allocation.classLabel,
        'pickupStop': allocation.pickupStop,
        'dropStop': allocation.dropStop,
        'routeId': allocation.routeId,
        'routeName': allocation.routeName,
        'busNumber': allocation.busNumber,
        'shift': TransportEnumCodec.shiftToApi(allocation.shift),
        'sisStudentId': allocation.sisStudentId,
        'demandRaised': allocation.demandRaised,
      };

  Map<String, dynamic> allocationsEnvelope(
    List<StudentTransportAllocation> allocations,
  ) {
    return listEnvelope([
      for (final allocation in allocations) allocationItem(allocation),
    ]);
  }

  Map<String, dynamic> attendanceItem(TransportAttendanceRecord record) => {
        'id': record.id,
        'studentName': record.studentName,
        'stopName': record.stopName,
        'routeName': record.routeName,
        'scheduledTime': record.scheduledTime,
        'actualTime': record.actualTime,
        'status': TransportEnumCodec.attendanceStatusToApi(record.status),
        'parentNotified': record.parentNotified,
        'shift': TransportEnumCodec.shiftToApi(record.shift),
      };

  Map<String, dynamic> attendanceEnvelope(
    List<TransportAttendanceRecord> records,
  ) {
    return listEnvelope([
      for (final record in records) attendanceItem(record),
    ]);
  }

  Map<String, dynamic> trackingVehicleItem(TrackingVehicleStatus vehicle) => {
        'busNumber': vehicle.busNumber,
        'routeName': vehicle.routeName,
        'driverName': vehicle.driverName,
        'status': TransportEnumCodec.trackingStatusToApi(vehicle.status),
        'speedKph': vehicle.speedKph,
        'lastPing': vehicle.lastPing,
        'nextStop': vehicle.nextStop,
        'studentCount': vehicle.studentCount,
        'etaMinutes': vehicle.etaMinutes,
        'latitude': vehicle.latitude,
        'longitude': vehicle.longitude,
      };

  Map<String, dynamic> trackingEnvelope(TransportTrackingPlaceholderData data) {
    return envelope({
      'mapPlaceholderLabel': data.mapPlaceholderLabel,
      'integrationNote': data.integrationNote,
      'parentAppRoute': data.parentAppRoute,
      'vehicles': [
        for (final vehicle in data.vehicles) trackingVehicleItem(vehicle),
      ],
    });
  }

  Map<String, dynamic> reportsEnvelope(TransportReportsData data) {
    return envelope({
      'catalog': [
        for (final item in data.catalog)
          {
            'id': item.id,
            'title': item.title,
            'description': item.description,
            'lastGenerated': item.lastGenerated,
          },
      ],
      'onTimeTrend': _trendPoints(data.onTimeTrend),
      'delayByRoute': [
        for (final segment in data.delayByRoute)
          {
            'label': segment.label,
            'value': segment.value,
            'percent': segment.percent,
          },
      ],
      'fuelTrend': _trendPoints(data.fuelTrend),
    });
  }

  Map<String, dynamic> settingsEnvelope(TransportSettingsData data) {
    return envelope({
      'defaultShift': TransportEnumCodec.shiftToApi(data.defaultShift),
      'sections': [
        for (final section in data.sections)
          {
            'id': section.id,
            'title': section.title,
            'items': [
              for (final item in section.items)
                {
                  'id': item.id,
                  'label': item.label,
                  'value': item.value,
                  'description': item.description,
                  'editable': item.editable,
                },
            ],
          },
      ],
    });
  }

  Map<String, dynamic> occupancyMetricsEnvelope(OccupancyMetrics metrics) {
    return envelope(occupancyItem(metrics));
  }

  // ── TRN-3: roster (read, {data}-wrapped) ──────────────────────────────────
  Map<String, dynamic> rosterEnvelope(RouteRoster roster) {
    return envelope({
      'routeId': roster.routeId,
      'routeName': roster.routeName,
      'stopCount': roster.stopCount,
      'studentCount': roster.studentCount,
      'stops': [
        for (final group in roster.stops)
          {
            'stop': group.stop,
            'sequence': group.sequence,
            'students': [
              for (final s in group.students)
                {
                  'sisStudentId': s.sisStudentId,
                  'studentName': s.studentName,
                  'classLabel': s.classLabel,
                  'stop': s.stop,
                },
            ],
          },
      ],
    });
  }

  // ── TRN-5: bulk allocation (write, unwrapped payload) ─────────────────────
  Map<String, dynamic> bulkAllocationResult(BulkAllocationResult result) {
    return {
      'routeId': result.routeId,
      'assigned': result.assigned,
      'assignedCount': result.assignedCount,
      'skipped': [
        for (final s in result.skipped)
          {'studentId': s.studentId, 'reason': s.reason},
      ],
      'capacityOverridden': result.capacityOverridden,
    };
  }

  // ── TRN-8: document-expiry reminder (write, unwrapped payload) ────────────
  Map<String, dynamic> documentExpiryReminder(int reminded) {
    return {'reminded': reminded, 'withinDays': 30, 'expiries': const []};
  }

  // ── TRN-9: raised demand (write, unwrapped payload) ───────────────────────
  Map<String, dynamic> demandResult(TransportDemandResult result) {
    return {
      'id': result.id,
      'sisStudentId': result.sisStudentId,
      'routeId': result.routeId,
      'feeStructureId': result.feeStructureId,
      'academicYear': result.academicYear,
      'term': result.term,
      'invoiceId': result.invoiceId,
      'accountId': result.accountId,
      if (result.idempotent) 'idempotent': true,
    };
  }

  List<Map<String, dynamic>> _trendPoints(List<TransportTrendPoint> points) {
    return [
      for (final point in points)
        {
          'label': point.label,
          'amountLakhs': point.amountLakhs,
          'targetLakhs': point.targetLakhs,
        },
    ];
  }
}
