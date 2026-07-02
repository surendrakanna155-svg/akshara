import '../../../features/transport/transport_models.dart';

/// Mutable transport write state for mock repositories.
class MockTransportWriteStore {
  MockTransportWriteStore._();

  static final MockTransportWriteStore instance = MockTransportWriteStore._();

  List<StudentTransportAllocation>? allocations;
  List<TransportVehicle>? vehicles;
  List<TransportDriver>? drivers;
  List<TransportAttendanceRecord>? attendance;

  /// TRN-9 idempotency keys ("sisStudentId::routeId::academicYear::term").
  final Map<String, TransportDemandResult> demands = {};

  void reset() {
    allocations = null;
    vehicles = null;
    drivers = null;
    attendance = null;
    demands.clear();
  }
}
