import '../../../../features/transport/transport_models.dart';

/// Mutable transport write state for mock repositories.
class MockTransportWriteStore {
  MockTransportWriteStore._();

  static final MockTransportWriteStore instance = MockTransportWriteStore._();

  List<StudentTransportAllocation>? allocations;
  List<TransportVehicle>? vehicles;

  void reset() {
    allocations = null;
    vehicles = null;
  }
}
