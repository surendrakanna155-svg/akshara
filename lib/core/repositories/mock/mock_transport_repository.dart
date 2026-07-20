import 'package:flutter/material.dart';

import '../../../core/errors/api_failure.dart';
import '../../../features/transport/transport_document_expiry.dart';
import '../../../features/transport/transport_models.dart';
import '../../../features/transport/transport_requests.dart';
import '../../../router/route_names.dart';
import '../interfaces/transport_repository.dart';
import '../paginated_result.dart';
import '../pagination_helpers.dart';
import '../repository_query.dart';
import 'mock_transport_write_store.dart';

class MockTransportRepository implements TransportRepository {
  MockTransportRepository() : _routes = List.of(_seedRoutes);

  final List<TransportRoute> _routes;
  int _routeCounter = 100;

  static const _seedAllocations = [
    StudentTransportAllocation(
      id: 'alloc_1',
      studentName: 'Ravi Kumar',
      admissionNumber: 'ADM-2026-0138',
      classLabel: '10',
      pickupStop: 'Lake View Colony',
      dropStop: 'Akshara Main Gate',
      routeId: 'route_12',
      routeName: 'Route 12 — North',
      busNumber: 'BUS-07',
      shift: TransportShift.both,
      sisStudentId: 'SIS-STU-10430',
    ),
    StudentTransportAllocation(
      id: 'alloc_2',
      studentName: 'Emma Thomas',
      admissionNumber: 'ADM-2026-0135',
      classLabel: '7',
      pickupStop: 'Green Park Gate',
      dropStop: 'Akshara Main Gate',
      routeId: 'route_12',
      routeName: 'Route 12 — North',
      busNumber: 'BUS-07',
      shift: TransportShift.both,
      sisStudentId: 'SIS-STU-10418',
    ),
    StudentTransportAllocation(
      id: 'alloc_3',
      studentName: 'Ananya Reddy',
      admissionNumber: 'ADM-2026-0142',
      classLabel: '5',
      pickupStop: 'Hitech City',
      dropStop: 'Akshara Main Gate',
      routeId: 'route_08',
      routeName: 'Route 08 — West',
      busNumber: 'BUS-03',
      shift: TransportShift.am,
      sisStudentId: 'SIS-STU-10422',
    ),
    StudentTransportAllocation(
      id: 'alloc_4',
      studentName: 'Priya Sharma',
      admissionNumber: 'ADM-2025-0092',
      classLabel: '8',
      pickupStop: 'Madhapur Junction',
      dropStop: 'Akshara Main Gate',
      routeId: 'route_05',
      routeName: 'Route 05 — Central',
      busNumber: 'BUS-02',
      shift: TransportShift.both,
      sisStudentId: 'SIS-STU-10415',
    ),
    StudentTransportAllocation(
      id: 'alloc_5',
      studentName: 'Kavya Iyer',
      admissionNumber: 'ADM-2026-0145',
      classLabel: '6',
      pickupStop: '—',
      dropStop: 'Akshara Main Gate',
      routeId: '',
      routeName: 'Unassigned',
      busNumber: '—',
      shift: TransportShift.both,
      sisStudentId: 'SIS-STU-10425',
    ),
    StudentTransportAllocation(
      id: 'alloc_6',
      studentName: 'Rohan Mehta',
      admissionNumber: 'ADM-2026-0148',
      classLabel: '9',
      pickupStop: '—',
      dropStop: 'Akshara Main Gate',
      routeId: '',
      routeName: 'Unassigned',
      busNumber: '—',
      shift: TransportShift.am,
      sisStudentId: 'SIS-STU-10428',
    ),
  ];

  static const _stopsRoute12 = [
    TransportStop(
      id: 'stop_1',
      name: 'Lake View Colony',
      sequence: 1,
      scheduledTime: '7:05 AM',
      status: TransportStopStatus.completed,
      latitude: 17.4484,
      longitude: 78.3908,
    ),
    TransportStop(
      id: 'stop_2',
      name: 'Green Park Gate',
      sequence: 2,
      scheduledTime: '7:18 AM',
      status: TransportStopStatus.next,
      latitude: 17.4521,
      longitude: 78.4012,
    ),
    TransportStop(
      id: 'stop_3',
      name: 'Akshara Main Gate',
      sequence: 3,
      scheduledTime: '7:35 AM',
      status: TransportStopStatus.upcoming,
      latitude: 17.4612,
      longitude: 78.4123,
    ),
  ];

  static const _seedVehicles = [
    TransportVehicle(
      id: 'veh_7',
      busNumber: 'BUS-07',
      registration: 'TS 09 AB 4521',
      capacity: 48,
      routeName: 'Route 12 — North',
      gpsDeviceId: 'GPS-TR-007',
      insuranceExpiry: 'Dec 2026',
      fitnessExpiry: 'Aug 2026',
      status: TransportVehicleStatus.active,
      occupancyPercent: 88,
    ),
    TransportVehicle(
      id: 'veh_3',
      busNumber: 'BUS-03',
      registration: 'TS 09 CD 8832',
      capacity: 40,
      routeName: 'Route 08 — West',
      gpsDeviceId: 'GPS-TR-003',
      insuranceExpiry: 'Nov 2026',
      fitnessExpiry: 'Jul 2026',
      status: TransportVehicleStatus.active,
      occupancyPercent: 76,
    ),
    TransportVehicle(
      id: 'veh_2',
      busNumber: 'BUS-02',
      registration: 'TS 09 EF 1102',
      capacity: 50,
      routeName: 'Route 05 — Central',
      gpsDeviceId: 'GPS-TR-002',
      insuranceExpiry: 'Oct 2026',
      fitnessExpiry: 'Sep 2026',
      status: TransportVehicleStatus.active,
      occupancyPercent: 90,
    ),
    TransportVehicle(
      id: 'veh_11',
      busNumber: 'BUS-11',
      registration: 'TS 09 GH 7744',
      capacity: 45,
      routeName: 'Route 03 — East',
      gpsDeviceId: 'GPS-TR-011',
      insuranceExpiry: 'Oct 2026',
      fitnessExpiry: 'Jun 2026',
      status: TransportVehicleStatus.maintenance,
      occupancyPercent: 0,
    ),
  ];

  @override
  Future<TransportDashboardData> getDashboard({required RepositoryQuery query}) async {
    return const TransportDashboardData(
      kpis: [
        TransportKpi(
          id: 'active_buses',
          value: '18',
          label: 'Active Buses',
          icon: Icons.directions_bus_outlined,
          accentName: 'primary',
        ),
        TransportKpi(
          id: 'on_time',
          value: '94%',
          label: 'On-Time Rate',
          icon: Icons.schedule_outlined,
          accentName: 'success',
        ),
        TransportKpi(
          id: 'delayed',
          value: '2',
          label: 'Delayed',
          icon: Icons.warning_amber_outlined,
          accentName: 'error',
        ),
        TransportKpi(
          id: 'picked',
          value: '842',
          label: 'Students Picked',
          icon: Icons.groups_outlined,
          accentName: 'success',
        ),
        TransportKpi(
          id: 'driver_absent',
          value: '1',
          label: 'Driver Absent',
          icon: Icons.person_off_outlined,
          accentName: 'warning',
        ),
        TransportKpi(
          id: 'fuel',
          value: '₹84K',
          label: 'Fuel Cost (MTD)',
          icon: Icons.local_gas_station_outlined,
          accentName: 'neutral',
          detail: 'Finance integration placeholder',
        ),
      ],
      vehicleAssignments: [
        VehicleAssignment(
          id: 'va_1',
          busNumber: 'BUS-07',
          routeName: 'Route 12 — North',
          driverName: 'Ramesh Kumar',
          shift: TransportShift.am,
          studentCount: 42,
          trackingStatus: TrackingStatus.moving,
          etaLabel: '4 min',
        ),
        VehicleAssignment(
          id: 'va_2',
          busNumber: 'BUS-03',
          routeName: 'Route 08 — West',
          driverName: 'Suresh Naidu',
          shift: TransportShift.am,
          studentCount: 38,
          trackingStatus: TrackingStatus.delayed,
          etaLabel: '12 min late',
        ),
        VehicleAssignment(
          id: 'va_3',
          busNumber: 'BUS-02',
          routeName: 'Route 05 — Central',
          driverName: 'Vijay Reddy',
          shift: TransportShift.am,
          studentCount: 45,
          trackingStatus: TrackingStatus.idle,
          etaLabel: 'At stop',
        ),
      ],
      activeDelays: [
        'Route 08 — West delayed 12 min (traffic at Hitech City)',
        'BUS-11 GPS offline since 7:42 AM',
      ],
      routePerformance: [
        RoutePerformance(
          routeName: 'Route 12 — North',
          onTimePercent: '96%',
          avgDelayMinutes: 3,
          utilizationPercent: 88,
          incidents: 0,
        ),
        RoutePerformance(
          routeName: 'Route 08 — West',
          onTimePercent: '82%',
          avgDelayMinutes: 11,
          utilizationPercent: 76,
          incidents: 1,
        ),
        RoutePerformance(
          routeName: 'Route 05 — Central',
          onTimePercent: '94%',
          avgDelayMinutes: 4,
          utilizationPercent: 90,
          incidents: 0,
        ),
      ],
      occupancy: OccupancyMetrics(
        totalCapacity: 138,
        allocatedSeats: 4,
        unassignedStudents: 2,
        utilizationPercent: 3,
      ),
      aiInsight:
          'Route 08 — West shows recurring delays at Hitech City. Consider stop reorder or alternate path. 2 students unassigned — link to SIS-02 registry.',
    );
  }

  static const _seedRoutes = [
        TransportRoute(
          id: 'route_12',
          name: 'Route 12 — North',
          stopCount: 8,
          distanceKm: '14.2 km',
          amDeparture: '6:45 AM',
          pmDeparture: '3:30 PM',
          assignedBus: 'BUS-07',
          studentCount: 42,
          status: TransportRouteStatus.active,
          stops: _stopsRoute12,
          shift: TransportShift.both,
        ),
        TransportRoute(
          id: 'route_08',
          name: 'Route 08 — West',
          stopCount: 6,
          distanceKm: '11.8 km',
          amDeparture: '6:55 AM',
          pmDeparture: '3:40 PM',
          assignedBus: 'BUS-03',
          studentCount: 38,
          status: TransportRouteStatus.active,
          stops: _stopsRoute12,
          shift: TransportShift.both,
        ),
        TransportRoute(
          id: 'route_05',
          name: 'Route 05 — Central',
          stopCount: 7,
          distanceKm: '9.5 km',
          amDeparture: '7:00 AM',
          pmDeparture: '3:45 PM',
          assignedBus: 'BUS-02',
          studentCount: 45,
          status: TransportRouteStatus.active,
          stops: _stopsRoute12,
          shift: TransportShift.both,
        ),
        TransportRoute(
          id: 'route_15',
          name: 'Route 15 — South (Draft)',
          stopCount: 5,
          distanceKm: '12.0 km',
          amDeparture: '—',
          pmDeparture: '—',
          assignedBus: '—',
          studentCount: 0,
          status: TransportRouteStatus.draft,
          stops: [],
          shift: TransportShift.am,
        ),
      ];

  @override
  Future<PaginatedResult<TransportRoute>> getRoutes({
    required RepositoryQuery query,
  }) async =>
      PaginatedResult.fromItems(
        _routes,
        page: query.page,
        pageSize: query.pageSize,
      );

  @override
  Future<TransportRoute> createRoute({
    required RepositoryQuery query,
    required CreateTransportRouteRequest request,
  }) async {
    final id = 'route_${++_routeCounter}';
    final route = TransportRoute(
      id: id,
      name: request.name,
      stopCount: 0,
      distanceKm: request.distanceKm,
      amDeparture: request.amDeparture,
      pmDeparture: request.pmDeparture,
      assignedBus: '—',
      studentCount: 0,
      status: TransportRouteStatus.draft,
      stops: const [],
      shift: request.shift,
    );
    _routes.insert(0, route);
    return route;
  }

  @override
  Future<TransportRoute> activateRoute({
    required RepositoryQuery query,
    required ActivateTransportRouteRequest request,
  }) async {
    final index = _routes.indexWhere((r) => r.id == request.routeId);
    if (index < 0) {
      throw StateError('Route not found');
    }
    final current = _routes[index];
    if (current.status != TransportRouteStatus.draft) {
      throw StateError('Only draft routes can be activated');
    }
    final activated = TransportRoute(
      id: current.id,
      name: current.name,
      stopCount: current.stopCount,
      distanceKm: current.distanceKm,
      amDeparture: current.amDeparture,
      pmDeparture: current.pmDeparture,
      assignedBus: current.assignedBus == '—' ? 'BUS-TBD' : current.assignedBus,
      studentCount: current.studentCount,
      status: TransportRouteStatus.active,
      stops: current.stops,
      shift: current.shift,
    );
    _routes[index] = activated;
    return activated;
  }

  @override
  Future<PaginatedResult<TransportVehicle>> getVehicles({
    required RepositoryQuery query,
  }) async =>
      paginateList(await _loadVehicles(), query);

  static const _seedDrivers = [
    TransportDriver(
      id: 'drv_1',
      name: 'Ramesh Kumar',
      licenseNumber: 'DL-TS-2018-4521',
      licenseExpiry: 'Mar 2028',
      phone: '+91 98765 22001',
      assignedBus: 'BUS-07',
      attendancePercent: '98%',
      rating: '4.8',
      status: TransportDriverStatus.active,
    ),
    TransportDriver(
      id: 'drv_2',
      name: 'Suresh Naidu',
      licenseNumber: 'DL-TS-2016-8832',
      licenseExpiry: 'Jun 2027',
      phone: '+91 91234 33002',
      assignedBus: 'BUS-03',
      attendancePercent: '96%',
      rating: '4.5',
      status: TransportDriverStatus.active,
    ),
    TransportDriver(
      id: 'drv_3',
      name: 'Vijay Reddy',
      licenseNumber: 'DL-TS-2019-1102',
      licenseExpiry: 'Dec 2028',
      phone: '+91 99887 44003',
      assignedBus: 'BUS-02',
      attendancePercent: '100%',
      rating: '4.9',
      status: TransportDriverStatus.active,
    ),
    TransportDriver(
      id: 'drv_4',
      name: 'Kiran Das',
      licenseNumber: 'DL-TS-2015-7744',
      licenseExpiry: 'Apr 2026',
      phone: '+91 94440 55004',
      assignedBus: '—',
      attendancePercent: '0%',
      rating: '4.2',
      status: TransportDriverStatus.onLeave,
    ),
  ];

  Future<List<TransportDriver>> _loadDrivers() async {
    final store = MockTransportWriteStore.instance;
    store.drivers ??= List<TransportDriver>.from(_seedDrivers);
    return store.drivers!;
  }

  @override
  Future<PaginatedResult<TransportDriver>> getDrivers({
    required RepositoryQuery query,
  }) async =>
      paginateList(await _loadDrivers(), query);

  @override
  Future<PaginatedResult<StudentTransportAllocation>> getAllocations({
    required RepositoryQuery query,
  }) async =>
      paginateList(_annotateDemandRaised(await _loadAllocations()), query);

  /// PRA-P0-20 — mirror of the server annotation: an allocation reads as billed
  /// when a raised transport demand matches its (sisStudentId, routeId).
  List<StudentTransportAllocation> _annotateDemandRaised(
    List<StudentTransportAllocation> allocations,
  ) {
    final store = MockTransportWriteStore.instance;
    if (store.demands.isEmpty) return allocations;
    final billed = <String>{
      for (final d in store.demands.values) '${d.sisStudentId}::${d.routeId}',
    };
    return [
      for (final a in allocations)
        (a.routeId.isNotEmpty &&
                billed.contains('${a.sisStudentId}::${a.routeId}'))
            ? a.copyWith(demandRaised: true)
            : a,
    ];
  }

  static const _seedAttendance = [
    TransportAttendanceRecord(
      id: 'att_1',
      studentName: 'Ravi Kumar',
      stopName: 'Lake View Colony',
      routeName: 'Route 12 — North',
      scheduledTime: '7:05 AM',
      actualTime: '7:06 AM',
      status: TransportAttendanceStatus.picked,
      parentNotified: false,
      shift: TransportShift.am,
    ),
    TransportAttendanceRecord(
      id: 'att_2',
      studentName: 'Emma Thomas',
      stopName: 'Green Park Gate',
      routeName: 'Route 12 — North',
      scheduledTime: '7:18 AM',
      actualTime: '—',
      status: TransportAttendanceStatus.waiting,
      parentNotified: false,
      shift: TransportShift.am,
    ),
    TransportAttendanceRecord(
      id: 'att_3',
      studentName: 'Ananya Reddy',
      stopName: 'Hitech City',
      routeName: 'Route 08 — West',
      scheduledTime: '7:10 AM',
      actualTime: '7:22 AM',
      status: TransportAttendanceStatus.picked,
      parentNotified: true,
      shift: TransportShift.am,
    ),
    TransportAttendanceRecord(
      id: 'att_4',
      studentName: 'Rohan Mehta',
      stopName: 'Banjara Hills',
      routeName: 'Route 05 — Central',
      scheduledTime: '7:12 AM',
      actualTime: '—',
      status: TransportAttendanceStatus.absent,
      parentNotified: true,
      shift: TransportShift.am,
    ),
  ];

  Future<List<TransportAttendanceRecord>> _loadAttendance() async {
    final store = MockTransportWriteStore.instance;
    store.attendance ??= List<TransportAttendanceRecord>.from(_seedAttendance);
    return store.attendance!;
  }

  @override
  Future<PaginatedResult<TransportAttendanceRecord>> getAttendanceRecords({
    required RepositoryQuery query,
  }) async =>
      paginateList(await _loadAttendance(), query);

  @override
  Future<TransportAttendanceRecord> recordAttendance({
    required RepositoryQuery query,
    required RecordTransportAttendanceRequest request,
  }) async {
    final records = await _loadAttendance();
    final record = TransportAttendanceRecord(
      id: request.id ?? 'att_${DateTime.now().microsecondsSinceEpoch}',
      studentName: request.studentName,
      stopName: request.stopName,
      routeName: request.routeName,
      scheduledTime: request.scheduledTime,
      actualTime: request.actualTime,
      status: request.status,
      parentNotified: request.parentNotified,
      shift: request.shift,
    );
    final index = records.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      records[index] = record;
    } else {
      records.insert(0, record);
    }
    return record;
  }

  // ─── PRA-P1-43: generate a route's attendance roster from its allocations ────

  TransportShift _parseShiftName(String value) => switch (value) {
        'pm' => TransportShift.pm,
        'both' => TransportShift.both,
        _ => TransportShift.am,
      };

  /// Derives `waiting` attendance rows for a route+shift+date from the route's
  /// live allocations (mirror of the backend) instead of a single client-provided
  /// row. Idempotent by a stable id `${routeId}:${sisStudentId}:${shift}:${date}`
  /// — a re-run never clobbers a status a driver already recorded. Returns the
  /// number of rows added. Not part of [TransportRepository]: exercised directly.
  Future<int> generateAttendanceRoster({
    required RepositoryQuery query,
    required String routeId,
    String shift = 'am',
    String? date,
  }) async {
    final routeIndex = _routes.indexWhere((r) => r.id == routeId);
    if (routeIndex < 0) throw StateError('Route not found');
    final route = _routes[routeIndex];
    final day = date ?? DateTime.now().toIso8601String().substring(0, 10);
    final shiftEnum = _parseShiftName(shift);
    final allocations = await _loadAllocations();
    final records = await _loadAttendance();

    var added = 0;
    for (final a in allocations) {
      if (a.routeId != routeId) continue;
      final matchesShift = a.shift == shiftEnum ||
          a.shift == TransportShift.both ||
          shiftEnum == TransportShift.both;
      if (!matchesShift) continue;
      if (a.sisStudentId.isEmpty) continue;
      final id = '$routeId:${a.sisStudentId}:$shift:$day';
      if (records.any((r) => r.id == id)) continue;
      final stop = route.stops.firstWhere(
        (s) => s.name.trim() == a.pickupStop.trim(),
        orElse: () => const TransportStop(
          id: '',
          name: '',
          sequence: 0,
          scheduledTime: '',
          status: TransportStopStatus.upcoming,
          latitude: 0,
          longitude: 0,
        ),
      );
      records.insert(
        0,
        TransportAttendanceRecord(
          id: id,
          studentName: a.studentName,
          stopName: a.pickupStop,
          routeName: route.name,
          scheduledTime: stop.scheduledTime,
          actualTime: '',
          status: TransportAttendanceStatus.waiting,
          parentNotified: false,
          shift: shiftEnum,
        ),
      );
      added++;
    }
    return added;
  }

  @override
  Future<TransportTrackingPlaceholderData> getTrackingPlaceholder({required RepositoryQuery query}) async {
    return const TransportTrackingPlaceholderData(
      mapPlaceholderLabel: 'Fleet telemetry — route status and ETAs',
      integrationNote:
          'Telemetry-first tracking for transport managers. Parent and student apps receive route alerts from the same feed.',
      parentAppRoute: RouteNames.parentDashboard,
      vehicles: [
        TrackingVehicleStatus(
          busNumber: 'BUS-07',
          routeName: 'Route 12 — North',
          driverName: 'Ramesh Kumar',
          status: TrackingStatus.moving,
          speedKph: 32,
          lastPing: '30 sec ago',
          nextStop: 'Green Park Gate',
          studentCount: 42,
          etaMinutes: 4,
          latitude: 17.4502,
          longitude: 78.3965,
        ),
        TrackingVehicleStatus(
          busNumber: 'BUS-03',
          routeName: 'Route 08 — West',
          driverName: 'Suresh Naidu',
          status: TrackingStatus.delayed,
          speedKph: 18,
          lastPing: '1 min ago',
          nextStop: 'Hitech City',
          studentCount: 38,
          etaMinutes: 12,
          latitude: 17.4438,
          longitude: 78.3812,
        ),
        TrackingVehicleStatus(
          busNumber: 'BUS-11',
          routeName: 'Route 03 — East',
          driverName: '—',
          status: TrackingStatus.offline,
          speedKph: 0,
          lastPing: '18 min ago',
          nextStop: '—',
          studentCount: 0,
          etaMinutes: 0,
          latitude: 17.4680,
          longitude: 78.4200,
        ),
      ],
    );
  }

  @override
  Future<TransportReportsData> getReports({required RepositoryQuery query}) async {
    return const TransportReportsData(
      catalog: [
        TransportReportCatalogItem(
          id: 'rpt_on_time',
          title: 'On-Time Performance',
          description: 'Route punctuality trend and delay analysis',
          lastGenerated: '5 Jun 2026',
        ),
        TransportReportCatalogItem(
          id: 'rpt_utilization',
          title: 'Route Utilization',
          description: 'Capacity usage and occupancy by route',
          lastGenerated: '4 Jun 2026',
        ),
        TransportReportCatalogItem(
          id: 'rpt_fuel',
          title: 'Fuel Analysis',
          description: 'Fuel cost vs distance — Finance FN placeholder',
          lastGenerated: '1 Jun 2026',
        ),
        TransportReportCatalogItem(
          id: 'rpt_driver',
          title: 'Driver Attendance',
          description: 'Driver presence and rating summary',
          lastGenerated: '3 Jun 2026',
        ),
        TransportReportCatalogItem(
          id: 'rpt_students',
          title: 'Student Transport List',
          description: 'SIS-linked allocation export',
          lastGenerated: '5 Jun 2026',
        ),
        TransportReportCatalogItem(
          id: 'rpt_incidents',
          title: 'Incident Log',
          description: 'Delays, absences, and GPS offline events',
          lastGenerated: '2 Jun 2026',
        ),
      ],
      onTimeTrend: [
        TransportTrendPoint(label: 'Jan', amountLakhs: 92, targetLakhs: 95),
        TransportTrendPoint(label: 'Feb', amountLakhs: 94, targetLakhs: 95),
        TransportTrendPoint(label: 'Mar', amountLakhs: 93, targetLakhs: 95),
        TransportTrendPoint(label: 'Apr', amountLakhs: 95, targetLakhs: 95),
        TransportTrendPoint(label: 'May', amountLakhs: 94, targetLakhs: 95),
        TransportTrendPoint(label: 'Jun', amountLakhs: 94, targetLakhs: 95),
      ],
      delayByRoute: [
        TransportSegment(label: 'Route 08', value: 11, percent: 35),
        TransportSegment(label: 'Route 12', value: 3, percent: 10),
        TransportSegment(label: 'Route 05', value: 4, percent: 12),
        TransportSegment(label: 'Route 03', value: 8, percent: 25),
      ],
      fuelTrend: [
        TransportTrendPoint(label: 'Jan', amountLakhs: 7.2, targetLakhs: 8.0),
        TransportTrendPoint(label: 'Feb', amountLakhs: 7.8, targetLakhs: 8.0),
        TransportTrendPoint(label: 'Mar', amountLakhs: 8.1, targetLakhs: 8.5),
        TransportTrendPoint(label: 'Apr', amountLakhs: 8.4, targetLakhs: 8.5),
        TransportTrendPoint(label: 'May', amountLakhs: 8.0, targetLakhs: 8.5),
        TransportTrendPoint(label: 'Jun', amountLakhs: 8.4, targetLakhs: 8.5),
      ],
    );
  }

  @override
  Future<TransportSettingsData> getSettings({required RepositoryQuery query}) async {
    return const TransportSettingsData(
      defaultShift: TransportShift.am,
      sections: [
        TransportSettingsSection(
          id: 'shifts',
          title: 'Shift configuration',
          items: [
            TransportSettingItem(
              id: 'am_start',
              label: 'AM pickup window',
              value: '6:30 – 8:00 AM',
              description: 'Default morning shift schedule',
              editable: true,
            ),
            TransportSettingItem(
              id: 'pm_start',
              label: 'PM drop window',
              value: '3:15 – 4:30 PM',
              description: 'Afternoon return schedule',
              editable: true,
            ),
          ],
        ),
        TransportSettingsSection(
          id: 'gps',
          title: 'GPS & tracking',
          items: [
            TransportSettingItem(
              id: 'provider',
              label: 'GPS provider',
              value: 'FleetTrack (sandbox)',
              description: 'TR-07 live map placeholder',
              editable: true,
            ),
            TransportSettingItem(
              id: 'ping_interval',
              label: 'Ping interval',
              value: '30 seconds',
              description: 'Vehicle location refresh rate',
              editable: true,
            ),
          ],
        ),
        TransportSettingsSection(
          id: 'parent',
          title: 'Parent app integration',
          items: [
            TransportSettingItem(
              id: 'route_info',
              label: 'Route information',
              value: 'Enabled',
              description: 'Parent sees assigned route and bus (PA dashboard)',
              editable: false,
            ),
            TransportSettingItem(
              id: 'delay_notify',
              label: 'Delay notifications',
              value: 'Push + SMS',
              description: 'Notify parents on pickup delays',
              editable: true,
            ),
          ],
        ),
        TransportSettingsSection(
          id: 'finance',
          title: 'Finance integration',
          items: [
            TransportSettingItem(
              id: 'transport_fee',
              label: 'Transport fee component',
              value: 'Linked to FN-02 fee structures',
              description: 'Future: transport fee billing placeholder',
              editable: false,
            ),
            TransportSettingItem(
              id: 'fuel_expense',
              label: 'Fuel expense posting',
              value: 'Manual (Finance FN-05 placeholder)',
              description: 'Fuel cost MTD sync to finance',
              editable: false,
            ),
          ],
        ),
        TransportSettingsSection(
          id: 'sis',
          title: 'Student SIS integration',
          items: [
            TransportSettingItem(
              id: 'allocation_sync',
              label: 'Allocation sync',
              value: 'SIS-STU IDs linked',
              description: 'TR-05 allocations reference SIS registry',
              editable: false,
            ),
            TransportSettingItem(
              id: 'attendance_sync',
              label: 'Attendance sync',
              value: 'TR-06 → SIS attendance placeholder',
              description: 'Transport pickup status feeds student record',
              editable: false,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<OccupancyMetrics> getOccupancyMetrics({required RepositoryQuery query}) async {
    return _computeOccupancyMetrics();
  }

  Future<List<StudentTransportAllocation>> _loadAllocations() async {
    final store = MockTransportWriteStore.instance;
    store.allocations ??= List<StudentTransportAllocation>.from(_seedAllocations);
    return store.allocations!;
  }

  Future<List<TransportVehicle>> _loadVehicles() async {
    final store = MockTransportWriteStore.instance;
    store.vehicles ??= List<TransportVehicle>.from(_seedVehicles);
    return store.vehicles!;
  }

  int _studentsOnRoute(List<StudentTransportAllocation> allocations, String routeId) {
    return allocations.where((a) => a.routeId == routeId).length;
  }

  TransportRoute _requireActiveRoute(String routeId) {
    final index = _routes.indexWhere((r) => r.id == routeId);
    if (index < 0) {
      throw StateError('Route not found');
    }
    final route = _routes[index];
    if (route.status != TransportRouteStatus.active) {
      throw StateError('Route is not active');
    }
    if (route.assignedBus == '—') {
      throw StateError('Route has no assigned vehicle');
    }
    return route;
  }

  void _assertRouteCapacity({
    required List<StudentTransportAllocation> allocations,
    required List<TransportVehicle> vehicles,
    required String routeId,
    int adding = 1,
    bool allowOverCapacity = false,
  }) {
    final route = _requireActiveRoute(routeId);
    final vehicle = vehicles.firstWhere(
      (v) => v.busNumber == route.assignedBus,
      orElse: () => throw StateError('Assigned vehicle not found'),
    );
    if (vehicle.capacity <= 0) return; // unbounded
    final count = _studentsOnRoute(allocations, routeId);
    if (count + adding > vehicle.capacity && !allowOverCapacity) {
      // TRN-7 — surface the same typed failure the API path does, so the UI's
      // capacity-override confirm dialog fires in mock mode too.
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message:
              'Route ${route.name} is at capacity ($count/${vehicle.capacity}); '
              'assign anyway?',
          code: 'CAPACITY_EXCEEDED',
          statusCode: 409,
        ),
      );
    }
  }

  Future<void> _syncRouteAndVehicleMetrics() async {
    final allocations = await _loadAllocations();
    final vehicles = await _loadVehicles();

    for (var i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      if (route.status != TransportRouteStatus.active) continue;
      final count = _studentsOnRoute(allocations, route.id);
      _routes[i] = TransportRoute(
        id: route.id,
        name: route.name,
        stopCount: route.stopCount,
        distanceKm: route.distanceKm,
        amDeparture: route.amDeparture,
        pmDeparture: route.pmDeparture,
        assignedBus: route.assignedBus,
        studentCount: count,
        status: route.status,
        stops: route.stops,
        shift: route.shift,
      );
    }

    final store = MockTransportWriteStore.instance;
    store.vehicles = [
      for (final vehicle in vehicles)
        TransportVehicle(
          id: vehicle.id,
          busNumber: vehicle.busNumber,
          registration: vehicle.registration,
          capacity: vehicle.capacity,
          routeName: vehicle.routeName,
          gpsDeviceId: vehicle.gpsDeviceId,
          insuranceExpiry: vehicle.insuranceExpiry,
          fitnessExpiry: vehicle.fitnessExpiry,
          status: vehicle.status,
          occupancyPercent: _vehicleOccupancyPercent(
            vehicle: vehicle,
            allocations: allocations,
          ),
        ),
    ];
  }

  int _vehicleOccupancyPercent({
    required TransportVehicle vehicle,
    required List<StudentTransportAllocation> allocations,
  }) {
    if (vehicle.capacity <= 0) return 0;
    final count = allocations.where((a) => a.busNumber == vehicle.busNumber).length;
    return ((count / vehicle.capacity) * 100).round();
  }

  Future<OccupancyMetrics> _computeOccupancyMetrics() async {
    await _syncRouteAndVehicleMetrics();
    final allocations = await _loadAllocations();
    final vehicles = await _loadVehicles();
    final activeVehicles = vehicles
        .where((v) => v.status == TransportVehicleStatus.active)
        .toList(growable: false);
    final totalCapacity =
        activeVehicles.fold<int>(0, (sum, vehicle) => sum + vehicle.capacity);
    final allocatedSeats = allocations.where((a) => a.isAssigned).length;
    final unassignedStudents = allocations.where((a) => !a.isAssigned).length;
    final utilizationPercent = totalCapacity == 0
        ? 0
        : ((allocatedSeats / totalCapacity) * 100).round();
    return OccupancyMetrics(
      totalCapacity: totalCapacity,
      allocatedSeats: allocatedSeats,
      unassignedStudents: unassignedStudents,
      utilizationPercent: utilizationPercent,
    );
  }

  @override
  Future<StudentTransportAllocation> assignStudentTransport({
    required RepositoryQuery query,
    required AssignStudentTransportRequest request,
  }) async {
    final allocations = await _loadAllocations();
    final vehicles = await _loadVehicles();
    final index = allocations.indexWhere((a) => a.id == request.allocationId);
    if (index < 0) {
      throw StateError('Student allocation not found');
    }
    final current = allocations[index];
    if (current.isAssigned) {
      throw StateError('Student is already assigned to a route');
    }

    final route = _requireActiveRoute(request.routeId);
    _assertRouteCapacity(
      allocations: allocations,
      vehicles: vehicles,
      routeId: request.routeId,
      allowOverCapacity: request.allowOverCapacity,
    );

    final updated = StudentTransportAllocation(
      id: current.id,
      studentName:
          request.studentName.isNotEmpty ? request.studentName : current.studentName,
      admissionNumber: request.admissionNumber.isNotEmpty
          ? request.admissionNumber
          : current.admissionNumber,
      classLabel:
          request.classLabel.isNotEmpty ? request.classLabel : current.classLabel,
      pickupStop: request.pickupStop,
      dropStop: request.dropStop,
      routeId: route.id,
      routeName: route.name,
      busNumber: route.assignedBus,
      shift: current.shift,
      sisStudentId:
          request.sisStudentId.isNotEmpty ? request.sisStudentId : current.sisStudentId,
    );
    allocations[index] = updated;
    await _syncRouteAndVehicleMetrics();
    return updated;
  }

  @override
  Future<TransportDelayNotificationResult> notifyRouteDelay({
    required RepositoryQuery query,
    required NotifyRouteDelayRequest request,
  }) async {
    final routeIndex = _routes.indexWhere((r) => r.id == request.routeId);
    if (routeIndex < 0) {
      throw StateError('Route not found');
    }
    if (request.message.trim().isEmpty) {
      throw StateError('Delay message is required');
    }
    final route = _routes[routeIndex];
    final allocations = await _loadAllocations();
    final affected =
        allocations.where((a) => a.routeId == request.routeId).length;
    return TransportDelayNotificationResult(
      routeName: route.name,
      recipientCount: affected,
    );
  }

  @override
  Future<StudentTransportAllocation> transferStudentTransport({
    required RepositoryQuery query,
    required TransferStudentTransportRequest request,
  }) async {
    final allocations = await _loadAllocations();
    final vehicles = await _loadVehicles();
    final index = allocations.indexWhere((a) => a.id == request.allocationId);
    if (index < 0) {
      throw StateError('Student allocation not found');
    }
    final current = allocations[index];
    if (!current.isAssigned) {
      throw StateError('Student is not assigned to a route');
    }
    if (current.routeId == request.targetRouteId) {
      throw StateError('Student is already on this route');
    }

    final targetRoute = _requireActiveRoute(request.targetRouteId);
    _assertRouteCapacity(
      allocations: allocations,
      vehicles: vehicles,
      routeId: request.targetRouteId,
    );

    final updated = StudentTransportAllocation(
      id: current.id,
      studentName: current.studentName,
      admissionNumber: current.admissionNumber,
      classLabel: current.classLabel,
      pickupStop: request.pickupStop,
      dropStop: request.dropStop,
      routeId: targetRoute.id,
      routeName: targetRoute.name,
      busNumber: targetRoute.assignedBus,
      shift: current.shift,
      sisStudentId: current.sisStudentId,
    );
    allocations[index] = updated;
    await _syncRouteAndVehicleMetrics();
    return updated;
  }

  @override
  Future<StudentTransportAllocation> removeStudentTransport({
    required RepositoryQuery query,
    required RemoveStudentTransportRequest request,
  }) async {
    final allocations = await _loadAllocations();
    final index = allocations.indexWhere((a) => a.id == request.allocationId);
    if (index < 0) {
      throw StateError('Student allocation not found');
    }
    final current = allocations[index];
    if (!current.isAssigned) {
      throw StateError('Student is not assigned to a route');
    }

    final updated = StudentTransportAllocation(
      id: current.id,
      studentName: current.studentName,
      admissionNumber: current.admissionNumber,
      classLabel: current.classLabel,
      pickupStop: '—',
      dropStop: current.dropStop,
      routeId: '',
      routeName: 'Unassigned',
      busNumber: '—',
      shift: current.shift,
      sisStudentId: current.sisStudentId,
    );
    allocations[index] = updated;
    await _syncRouteAndVehicleMetrics();
    return updated;
  }

  // ─── TRN-1/TRN-2: vehicle CRUD ──────────────────────────────────────────────

  int _vehicleCounter = 500;

  String _regKey(String value) => value.trim().toUpperCase();

  @override
  Future<TransportVehicle> createVehicle({
    required RepositoryQuery query,
    required CreateTransportVehicleRequest request,
  }) async {
    final vehicles = await _loadVehicles();
    final key = _regKey(request.registration);
    if (vehicles.any((v) => _regKey(v.registration) == key)) {
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message:
              'A vehicle with registration ${request.registration} already exists',
          code: 'DUPLICATE_REGISTRATION',
          statusCode: 409,
        ),
      );
    }
    final vehicle = TransportVehicle(
      id: 'veh_${++_vehicleCounter}',
      busNumber: request.registration,
      registration: request.registration,
      capacity: request.capacity,
      routeName: '—',
      gpsDeviceId: '—',
      insuranceExpiry: request.insuranceExpiry,
      fitnessExpiry: request.fitnessExpiry,
      pucExpiry: request.pucExpiry,
      permitExpiry: request.permitExpiry,
      roadTaxExpiry: request.roadTaxExpiry,
      model: request.model,
      status: request.status,
      occupancyPercent: 0,
    );
    vehicles.insert(0, vehicle);
    return vehicle;
  }

  @override
  Future<TransportVehicle> updateVehicle({
    required RepositoryQuery query,
    required UpdateTransportVehicleRequest request,
  }) async {
    final vehicles = await _loadVehicles();
    final index = vehicles.indexWhere((v) => v.id == request.id);
    if (index < 0) throw StateError('Vehicle not found');
    final current = vehicles[index];
    final registration = request.registration ?? current.registration;
    if (request.registration != null) {
      final key = _regKey(request.registration!);
      if (vehicles.any((v) => v.id != request.id && _regKey(v.registration) == key)) {
        throw ApiFailureException(
          ApiFailure(
            type: ApiFailureType.unknown,
            message:
                'A vehicle with registration ${request.registration} already exists',
            code: 'DUPLICATE_REGISTRATION',
            statusCode: 409,
          ),
        );
      }
    }
    final updated = TransportVehicle(
      id: current.id,
      busNumber: current.busNumber,
      registration: registration,
      capacity: request.capacity ?? current.capacity,
      routeName: current.routeName,
      gpsDeviceId: current.gpsDeviceId,
      insuranceExpiry: request.insuranceExpiry ?? current.insuranceExpiry,
      fitnessExpiry: request.fitnessExpiry ?? current.fitnessExpiry,
      pucExpiry: request.pucExpiry ?? current.pucExpiry,
      permitExpiry: request.permitExpiry ?? current.permitExpiry,
      roadTaxExpiry: request.roadTaxExpiry ?? current.roadTaxExpiry,
      model: request.model ?? current.model,
      status: request.status ?? current.status,
      occupancyPercent: current.occupancyPercent,
    );
    vehicles[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteVehicle({
    required RepositoryQuery query,
    required DeleteTransportVehicleRequest request,
  }) async {
    final vehicles = await _loadVehicles();
    final index = vehicles.indexWhere((v) => v.id == request.id);
    if (index < 0) throw StateError('Vehicle not found');
    final vehicle = vehicles[index];
    final reg = _regKey(vehicle.registration);
    final busNo = _regKey(vehicle.busNumber);
    // The backend blocks by registration; the mock seed conflates registration
    // and bus number on assignedBus, so match either to keep the guard faithful.
    final referencing = _routes.where(
      (r) =>
          r.status == TransportRouteStatus.active &&
          ((reg.isNotEmpty && _regKey(r.assignedBus) == reg) ||
              (busNo.isNotEmpty && _regKey(r.assignedBus) == busNo)),
    );
    if (referencing.isNotEmpty) {
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message:
              'Cannot delete vehicle ${vehicle.registration}: it is assigned to '
              'active route ${referencing.first.name}',
          code: 'VEHICLE_IN_USE',
          statusCode: 409,
        ),
      );
    }
    vehicles.removeAt(index);
  }

  // ─── PRA-P0-19: vehicle → route assignment ──────────────────────────────────

  /// Assigns a vehicle (by registration or bus number) to a route, setting the
  /// route's `assignedBus` so the capacity guard can resolve its capacity — the
  /// missing write that previously left the guard inert. Rejects a vehicle whose
  /// capacity is below the route's current allocation count (409 CAPACITY_EXCEEDED),
  /// mirroring the backend. Not part of [TransportRepository]: exercised directly.
  Future<TransportRoute> assignRouteVehicle({
    required RepositoryQuery query,
    required String routeId,
    required String registration,
  }) async {
    final index = _routes.indexWhere((r) => r.id == routeId);
    if (index < 0) throw StateError('Route not found');
    final vehicles = await _loadVehicles();
    final key = _regKey(registration);
    final vehicle = vehicles.firstWhere(
      (v) => _regKey(v.registration) == key || _regKey(v.busNumber) == key,
      orElse: () => throw StateError('Vehicle not found'),
    );
    final allocations = await _loadAllocations();
    final currentCount = _studentsOnRoute(allocations, routeId);
    if (vehicle.capacity > 0 && vehicle.capacity < currentCount) {
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message:
              'Vehicle ${vehicle.registration} capacity (${vehicle.capacity}) is '
              "below the route's current allocation of $currentCount students",
          code: 'CAPACITY_EXCEEDED',
          statusCode: 409,
        ),
      );
    }
    final current = _routes[index];
    // The mock keys capacity on busNumber (createVehicle sets busNumber ==
    // registration), so store busNumber to keep the mock's own guard resolvable.
    final updated = TransportRoute(
      id: current.id,
      name: current.name,
      stopCount: current.stopCount,
      distanceKm: current.distanceKm,
      amDeparture: current.amDeparture,
      pmDeparture: current.pmDeparture,
      assignedBus: vehicle.busNumber,
      studentCount: current.studentCount,
      status: current.status,
      stops: current.stops,
      shift: current.shift,
    );
    _routes[index] = updated;
    return updated;
  }

  // ─── TRN-1/TRN-2: driver CRUD ───────────────────────────────────────────────

  int _driverCounter = 500;

  @override
  Future<TransportDriver> createDriver({
    required RepositoryQuery query,
    required CreateTransportDriverRequest request,
  }) async {
    final drivers = await _loadDrivers();
    final key = _regKey(request.licenseNumber);
    if (drivers.any((d) => _regKey(d.licenseNumber) == key)) {
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message: 'A driver with licence ${request.licenseNumber} already exists',
          code: 'DUPLICATE_LICENSE',
          statusCode: 409,
        ),
      );
    }
    final driver = TransportDriver(
      id: 'drv_${++_driverCounter}',
      name: request.name,
      licenseNumber: request.licenseNumber,
      licenseExpiry: request.licenseExpiry,
      phone: request.phone,
      assignedBus: '—',
      attendancePercent: '0%',
      rating: '—',
      status: request.status,
    );
    drivers.insert(0, driver);
    return driver;
  }

  @override
  Future<TransportDriver> updateDriver({
    required RepositoryQuery query,
    required UpdateTransportDriverRequest request,
  }) async {
    final drivers = await _loadDrivers();
    final index = drivers.indexWhere((d) => d.id == request.id);
    if (index < 0) throw StateError('Driver not found');
    final current = drivers[index];
    if (request.licenseNumber != null) {
      final key = _regKey(request.licenseNumber!);
      if (drivers.any(
        (d) => d.id != request.id && _regKey(d.licenseNumber) == key,
      )) {
        throw ApiFailureException(
          ApiFailure(
            type: ApiFailureType.unknown,
            message:
                'A driver with licence ${request.licenseNumber} already exists',
            code: 'DUPLICATE_LICENSE',
            statusCode: 409,
          ),
        );
      }
    }
    final updated = TransportDriver(
      id: current.id,
      name: request.name ?? current.name,
      licenseNumber: request.licenseNumber ?? current.licenseNumber,
      licenseExpiry: request.licenseExpiry ?? current.licenseExpiry,
      phone: request.phone ?? current.phone,
      assignedBus: current.assignedBus,
      attendancePercent: current.attendancePercent,
      rating: current.rating,
      status: request.status ?? current.status,
    );
    drivers[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteDriver({
    required RepositoryQuery query,
    required DeleteTransportDriverRequest request,
  }) async {
    final drivers = await _loadDrivers();
    final index = drivers.indexWhere((d) => d.id == request.id);
    if (index < 0) throw StateError('Driver not found');
    drivers.removeAt(index);
  }

  // ─── TRN-3: stop-wise roster ────────────────────────────────────────────────

  @override
  Future<RouteRoster> getRouteRoster({
    required RepositoryQuery query,
    required String routeId,
  }) async {
    final routeIndex = _routes.indexWhere((r) => r.id == routeId);
    if (routeIndex < 0) throw StateError('Route not found');
    final route = _routes[routeIndex];
    final allocations = await _loadAllocations();
    final onRoute = allocations.where((a) => a.routeId == routeId).toList();

    final seqByStop = <String, int>{};
    for (final s in route.stops) {
      if (s.name.trim().isNotEmpty) seqByStop[s.name] = s.sequence;
    }

    final grouped = <String, List<RosterStudent>>{};
    for (final a in onRoute) {
      final stopName =
          a.pickupStop.trim().isEmpty ? '(unassigned stop)' : a.pickupStop.trim();
      grouped.putIfAbsent(stopName, () => []).add(
            RosterStudent(
              sisStudentId: a.sisStudentId,
              studentName: a.studentName,
              classLabel: a.classLabel,
              stop: stopName,
            ),
          );
    }

    final groups = grouped.entries
        .map(
          (e) => RosterStopGroup(
            stop: e.key,
            sequence: seqByStop[e.key] ?? 1 << 30,
            students: e.value
              ..sort((x, y) => x.studentName.compareTo(y.studentName)),
          ),
        )
        .toList()
      ..sort((a, b) {
        final bySeq = a.sequence.compareTo(b.sequence);
        return bySeq != 0 ? bySeq : a.stop.compareTo(b.stop);
      });

    return RouteRoster(
      routeId: route.id,
      routeName: route.name,
      stopCount: route.stops.length,
      studentCount: onRoute.length,
      stops: groups,
    );
  }

  // ─── TRN-4: stop editor ─────────────────────────────────────────────────────

  int _stopCounter = 900;

  TransportRoute _rewriteStops(
    TransportRoute route,
    List<TransportStop> stops,
  ) {
    final resequenced = [
      for (var i = 0; i < stops.length; i++)
        TransportStop(
          id: stops[i].id,
          name: stops[i].name,
          sequence: i + 1,
          scheduledTime: stops[i].scheduledTime,
          status: stops[i].status,
          latitude: stops[i].latitude,
          longitude: stops[i].longitude,
        ),
    ];
    return TransportRoute(
      id: route.id,
      name: route.name,
      stopCount: resequenced.length,
      distanceKm: route.distanceKm,
      amDeparture: route.amDeparture,
      pmDeparture: route.pmDeparture,
      assignedBus: route.assignedBus,
      studentCount: route.studentCount,
      status: route.status,
      stops: resequenced,
      shift: route.shift,
    );
  }

  TransportRoute _mutateRouteStops(
    String routeId,
    List<TransportStop> Function(List<TransportStop>) mutate,
  ) {
    final index = _routes.indexWhere((r) => r.id == routeId);
    if (index < 0) throw StateError('Route not found');
    final route = _routes[index];
    final next = _rewriteStops(route, mutate(List.of(route.stops)));
    _routes[index] = next;
    return next;
  }

  @override
  Future<TransportRoute> addStop({
    required RepositoryQuery query,
    required AddTransportStopRequest request,
  }) async {
    return _mutateRouteStops(request.routeId, (stops) {
      stops.add(
        TransportStop(
          id: 'stop_${++_stopCounter}',
          name: request.name,
          sequence: stops.length + 1,
          scheduledTime: request.pickupTime,
          status: TransportStopStatus.upcoming,
          latitude: 0,
          longitude: 0,
        ),
      );
      return stops;
    });
  }

  @override
  Future<TransportRoute> updateStop({
    required RepositoryQuery query,
    required UpdateTransportStopRequest request,
  }) async {
    return _mutateRouteStops(request.routeId, (stops) {
      final i = stops.indexWhere((s) => s.id == request.stopId);
      if (i < 0) throw StateError('Stop not found');
      final s = stops[i];
      stops[i] = TransportStop(
        id: s.id,
        name: request.name ?? s.name,
        sequence: s.sequence,
        scheduledTime: request.pickupTime ?? s.scheduledTime,
        status: s.status,
        latitude: s.latitude,
        longitude: s.longitude,
      );
      return stops;
    });
  }

  @override
  Future<TransportRoute> removeStop({
    required RepositoryQuery query,
    required RemoveTransportStopRequest request,
  }) async {
    return _mutateRouteStops(request.routeId, (stops) {
      final next = stops.where((s) => s.id != request.stopId).toList();
      if (next.length == stops.length) throw StateError('Stop not found');
      return next;
    });
  }

  @override
  Future<TransportRoute> reorderStops({
    required RepositoryQuery query,
    required ReorderTransportStopsRequest request,
  }) async {
    return _mutateRouteStops(request.routeId, (stops) {
      final byId = {for (final s in stops) s.id: s};
      if (request.stopOrder.length != stops.length ||
          request.stopOrder.any((id) => !byId.containsKey(id))) {
        throw StateError('stopOrder must be a permutation of the route stops');
      }
      return [for (final id in request.stopOrder) byId[id]!];
    });
  }

  // ─── TRN-5: bulk allocation ─────────────────────────────────────────────────

  @override
  Future<BulkAllocationResult> bulkAllocateTransport({
    required RepositoryQuery query,
    required BulkAllocateTransportRequest request,
  }) async {
    final allocations = await _loadAllocations();
    final vehicles = await _loadVehicles();
    final route = _requireActiveRoute(request.routeId);

    // Resolve targets: explicit ids, else match existing allocation rows by class.
    final List<StudentTransportAllocation> targets;
    if (request.sisStudentIds.isNotEmpty) {
      targets = allocations
          .where((a) => request.sisStudentIds.contains(a.sisStudentId))
          .toList();
    } else if (request.className != null) {
      targets = allocations
          .where((a) => a.classLabel == request.className)
          .toList();
    } else {
      throw StateError('Provide either sisStudentIds or a className');
    }

    final alreadyOnRoute = allocations
        .where((a) => a.routeId == request.routeId)
        .map((a) => a.sisStudentId)
        .toSet();
    final newcomers =
        targets.where((t) => !alreadyOnRoute.contains(t.sisStudentId)).length;

    _assertRouteCapacity(
      allocations: allocations,
      vehicles: vehicles,
      routeId: request.routeId,
      adding: newcomers,
      allowOverCapacity: request.allowOverCapacity,
    );

    final assigned = <String>[];
    final skipped = <SkippedAllocation>[];
    for (final t in targets) {
      if (t.sisStudentId.isEmpty) {
        skipped.add(SkippedAllocation(studentId: t.id, reason: 'empty student id'));
        continue;
      }
      final i = allocations.indexWhere((a) => a.id == t.id);
      allocations[i] = StudentTransportAllocation(
        id: t.id,
        studentName: t.studentName,
        admissionNumber: t.admissionNumber,
        classLabel: t.classLabel,
        pickupStop: request.pickupStop,
        dropStop: request.dropStop,
        routeId: route.id,
        routeName: route.name,
        busNumber: route.assignedBus,
        shift: t.shift,
        sisStudentId: t.sisStudentId,
      );
      assigned.add(t.sisStudentId);
    }
    await _syncRouteAndVehicleMetrics();
    return BulkAllocationResult(
      routeId: request.routeId,
      assigned: assigned,
      skipped: skipped,
      capacityOverridden: request.allowOverCapacity && newcomers > 0,
    );
  }

  // ─── TRN-8: document-expiry reminder ────────────────────────────────────────

  @override
  Future<int> sendTransportDocumentExpiryReminder({
    required RepositoryQuery query,
    required SendTransportDocumentExpiryReminderRequest request,
  }) async {
    final vehicles = await _loadVehicles();
    final drivers = await _loadDrivers();
    final expiries = TransportDocumentExpiryScanner.scan(
      vehicles: vehicles,
      drivers: drivers,
    );
    return expiries
        .where((e) => e.daysUntil <= request.withinDays)
        .length;
  }

  // ─── TRN-9: raise a Finance transport-fee demand ────────────────────────────

  @override
  Future<TransportDemandResult> raiseTransportDemand({
    required RepositoryQuery query,
    required RaiseTransportDemandRequest request,
  }) async {
    final store = MockTransportWriteStore.instance;
    final key =
        '${request.sisStudentId}::${request.routeId}::${request.academicYear}::${request.term}';
    final prior = store.demands[key];
    if (prior != null) {
      return TransportDemandResult(
        id: prior.id,
        sisStudentId: prior.sisStudentId,
        routeId: prior.routeId,
        feeStructureId: prior.feeStructureId,
        academicYear: prior.academicYear,
        term: prior.term,
        invoiceId: prior.invoiceId,
        accountId: prior.accountId,
        idempotent: true,
      );
    }
    final id = 'demand_${DateTime.now().microsecondsSinceEpoch}';
    final result = TransportDemandResult(
      id: id,
      sisStudentId: request.sisStudentId,
      routeId: request.routeId,
      feeStructureId: request.feeStructureId,
      academicYear: request.academicYear,
      term: request.term,
      invoiceId: 'inv_$id',
      accountId: 'acct_${request.sisStudentId}',
      idempotent: false,
    );
    store.demands[key] = result;
    return result;
  }
}
