import 'package:flutter/foundation.dart';

/// Event payload emitted by vendor monitoring adapters.
class VendorMonitoringPayload {
  const VendorMonitoringPayload({
    required this.vendor,
    required this.type,
    required this.name,
    required this.attributes,
  });

  final String vendor;
  final String type;
  final String name;
  final Map<String, String> attributes;
}

/// Boundary between monitoring adapters and vendor SDKs or HTTP clients.
abstract class VendorMonitoringTransport {
  void send(VendorMonitoringPayload payload);
}

/// Safe transport used until a vendor SDK/client is provisioned.
class NoOpVendorMonitoringTransport implements VendorMonitoringTransport {
  const NoOpVendorMonitoringTransport();

  @override
  void send(VendorMonitoringPayload payload) {}
}

/// Development transport for validating vendor payload shape.
class DebugVendorMonitoringTransport implements VendorMonitoringTransport {
  const DebugVendorMonitoringTransport();

  @override
  void send(VendorMonitoringPayload payload) {
    debugPrint(
      '[${payload.vendor}] ${payload.type}:${payload.name} ${payload.attributes}',
    );
  }
}
