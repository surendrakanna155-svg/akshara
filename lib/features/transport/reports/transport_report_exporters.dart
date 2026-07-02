import '../../../core/reports/akshara_report_export_service.dart';
import '../transport_models.dart';

/// Turns the transport view-models into the shared XCT-1 grid shape (headers +
/// string rows) and drives CSV / PDF exports through [AksharaReportExportService].
/// Every transport report rides the same grid primitive — no report invents its
/// own CSV/PDF layout.
class TransportReportExporters {
  const TransportReportExporters(this._service);

  final AksharaReportExportService _service;

  static String _vehicleStatusLabel(TransportVehicleStatus status) {
    return switch (status) {
      TransportVehicleStatus.active => 'Active',
      TransportVehicleStatus.maintenance => 'Maintenance',
      TransportVehicleStatus.retired => 'Retired',
    };
  }

  // --- TRN-3 stop-wise route roster ------------------------------------------

  static const List<String> rosterHeaders = [
    'Stop',
    'Sequence',
    'Student',
    'Class',
    'SIS ID',
  ];

  static List<List<String>> rosterRows(RouteRoster roster) {
    return [
      for (final group in roster.stops)
        for (final student in group.students)
          [
            group.stop,
            '${group.sequence}',
            student.studentName,
            student.classLabel,
            student.sisStudentId,
          ],
    ];
  }

  Future<void> shareRosterCsv(RouteRoster roster) {
    return _service.shareGridCsv(
      filename: 'route_roster_${roster.routeId}',
      headers: rosterHeaders,
      rows: rosterRows(roster),
    );
  }

  Future<void> shareRosterPdf(RouteRoster roster) {
    return _service.shareGridPdf(
      filename: 'route_roster_${roster.routeId}',
      reportTitle: 'Route roster',
      moduleLabel: 'Transport · Route ${roster.routeName}',
      headers: rosterHeaders,
      rows: rosterRows(roster),
      generatedAtLabel: DateTime.now().toIso8601String(),
    );
  }

  // --- Student transport list ------------------------------------------------

  static const List<String> studentListHeaders = [
    'Student',
    'Admission',
    'Class',
    'Route',
    'Bus',
    'Pickup',
    'Drop',
    'SIS ID',
  ];

  static List<List<String>> studentListRows(
    List<StudentTransportAllocation> allocations,
  ) {
    return [
      for (final a in allocations)
        [
          a.studentName,
          a.admissionNumber,
          a.classLabel,
          a.routeName,
          a.busNumber,
          a.pickupStop,
          a.dropStop,
          a.sisStudentId,
        ],
    ];
  }

  Future<void> shareStudentListCsv(
    List<StudentTransportAllocation> allocations,
  ) {
    return _service.shareGridCsv(
      filename: 'student_transport_list',
      headers: studentListHeaders,
      rows: studentListRows(allocations),
    );
  }

  Future<void> shareStudentListPdf(
    List<StudentTransportAllocation> allocations,
  ) {
    return _service.shareGridPdf(
      filename: 'student_transport_list',
      reportTitle: 'Student transport list',
      moduleLabel: 'Transport · Allocations',
      headers: studentListHeaders,
      rows: studentListRows(allocations),
      generatedAtLabel: DateTime.now().toIso8601String(),
    );
  }

  // --- Vehicle list ----------------------------------------------------------

  static const List<String> vehicleListHeaders = [
    'Bus',
    'Registration',
    'Capacity',
    'Status',
    'Insurance',
    'Fitness',
    'PUC',
    'Permit',
    'Road tax',
  ];

  static List<List<String>> vehicleListRows(List<TransportVehicle> vehicles) {
    return [
      for (final v in vehicles)
        [
          v.busNumber,
          v.registration,
          '${v.capacity}',
          _vehicleStatusLabel(v.status),
          v.insuranceExpiry,
          v.fitnessExpiry,
          v.pucExpiry,
          v.permitExpiry,
          v.roadTaxExpiry,
        ],
    ];
  }

  Future<void> shareVehicleListCsv(List<TransportVehicle> vehicles) {
    return _service.shareGridCsv(
      filename: 'vehicle_list',
      headers: vehicleListHeaders,
      rows: vehicleListRows(vehicles),
    );
  }

  Future<void> shareVehicleListPdf(List<TransportVehicle> vehicles) {
    return _service.shareGridPdf(
      filename: 'vehicle_list',
      reportTitle: 'Vehicle list',
      moduleLabel: 'Transport · Fleet',
      headers: vehicleListHeaders,
      rows: vehicleListRows(vehicles),
      generatedAtLabel: DateTime.now().toIso8601String(),
      rightAlignFrom: 2,
    );
  }
}
