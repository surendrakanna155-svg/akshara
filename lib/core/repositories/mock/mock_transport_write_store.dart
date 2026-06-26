import '../../../../features/transport/transport_models.dart';

/// Mutable transport write state for mock repositories.
class MockTransportWriteStore {
  MockTransportWriteStore._();

  static final MockTransportWriteStore instance = MockTransportWriteStore._();

  List<StudentTransportAllocation>? allocations;
  List<TransportVehicle>? vehicles;
  List<TransportAttendanceRecord>? attendance;

  void reset() {
    allocations = null;
    vehicles = null;
    attendance = null;
  }
}
