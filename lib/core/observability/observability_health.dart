import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audit/audit_compliance_providers.dart';
import 'observability_providers.dart';

/// Unified operational health snapshot for diagnostics surfaces.
class ObservabilityHealthSnapshot {
  const ObservabilityHealthSnapshot({
    required this.monitoringEnabled,
    required this.analyticsEnabled,
    required this.auditHealthy,
    required this.auditIssues,
  });

  final bool monitoringEnabled;
  final bool analyticsEnabled;
  final bool auditHealthy;
  final List<String> auditIssues;
}

final observabilityHealthProvider = FutureProvider<ObservabilityHealthSnapshot>(
  (ref) async {
    final config = ref.watch(observabilityConfigProvider);
    final audit = await ref.watch(auditHealthSnapshotProvider.future);
    return ObservabilityHealthSnapshot(
      monitoringEnabled: config.enableMonitoring,
      analyticsEnabled: config.enableAnalytics,
      auditHealthy: audit.isHealthy,
      auditIssues: audit.issues,
    );
  },
);
