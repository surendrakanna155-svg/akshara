import 'package:flutter/material.dart';

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

  @override
  Future<PaginatedResult<TransportDriver>> getDrivers({
    required RepositoryQuery query,
  }) async =>
      paginateList(const [
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
      ], query);

  @override
  Future<PaginatedResult<StudentTransportAllocation>> getAllocations({
    required RepositoryQuery query,
  }) async =>
      paginateList(await _loadAllocations(), query);

  @override
  Future<PaginatedResult<TransportAttendanceRecord>> getAttendanceRecords({
    required RepositoryQuery query,
  }) async =>
      paginateList(const [
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
      ], query);

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
  }) {
    final route = _requireActiveRoute(routeId);
    final vehicle = vehicles.firstWhere(
      (v) => v.busNumber == route.assignedBus,
      orElse: () => throw StateError('Assigned vehicle not found'),
    );
    final count = _studentsOnRoute(allocations, routeId);
    if (count >= vehicle.capacity) {
      throw StateError('Route capacity exceeded');
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
    );

    final updated = StudentTransportAllocation(
      id: current.id,
      studentName: current.studentName,
      admissionNumber: current.admissionNumber,
      classLabel: current.classLabel,
      pickupStop: request.pickupStop,
      dropStop: request.dropStop,
      routeId: route.id,
      routeName: route.name,
      busNumber: route.assignedBus,
      shift: current.shift,
      sisStudentId: current.sisStudentId,
    );
    allocations[index] = updated;
    await _syncRouteAndVehicleMetrics();
    return updated;
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
}
