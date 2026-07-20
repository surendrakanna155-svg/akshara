import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_security_providers.dart';
import 'incident_context_service.dart';
import 'incident_route_observer.dart';
import 'incident_telemetry.dart';

/// ASIP Phase 1 — providers for the automatic incident-evidence backbone.
///
/// A single passive telemetry ring is shared by the router observer (navigation
/// breadcrumbs) and the Dio interceptor (recent API calls); the context service
/// assembles them + device/session identity into the create-context block.

/// Singleton passive telemetry ring for the whole session.
final incidentTelemetryBufferProvider = Provider<IncidentTelemetryBuffer>((ref) {
  return IncidentTelemetryBuffer();
});

/// Device / OS / app-version probe (real plugins in production).
final incidentEnvironmentProbeProvider = Provider<IncidentEnvironmentProbe>((ref) {
  return PlatformIncidentEnvironmentProbe();
});

/// [NavigatorObserver] registered on the app router to capture the current
/// screen + navigation breadcrumbs.
final incidentRouteObserverProvider = Provider<IncidentRouteObserver>((ref) {
  return IncidentRouteObserver(ref.watch(incidentTelemetryBufferProvider));
});

/// Assembles the incident context block at report time.
final incidentContextServiceProvider = Provider<IncidentContextService>((ref) {
  return IncidentContextService(
    probe: ref.watch(incidentEnvironmentProbeProvider),
    buffer: ref.watch(incidentTelemetryBufferProvider),
    sessionIdReader: () async =>
        (await ref.read(sessionMetadataStorageProvider).read())?.sessionId,
  );
});
