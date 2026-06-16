import 'school_configuration_models.dart';

/// Tenant-backed school configuration — multi-admin, cross-device, auditable.
final class TenantSchoolConfigurationStore {
  TenantSchoolConfigurationStore._();

  static final TenantSchoolConfigurationStore instance =
      TenantSchoolConfigurationStore._();

  final Map<String, SchoolConfiguration> _byTenant = {};
  final List<TenantConfigAuditEntry> _auditLog = [];

  SchoolConfiguration? read(String tenantId) => _byTenant[tenantId];

  SchoolConfiguration write({
    required String tenantId,
    required SchoolConfiguration config,
    required String actorLabel,
  }) {
    final next = config.copyWith(configuredAt: DateTime.now());
    _byTenant[tenantId] = next;
    _auditLog.insert(
      0,
      TenantConfigAuditEntry(
        tenantId: tenantId,
        actorLabel: actorLabel,
        changedAt: DateTime.now(),
        summary: 'Updated school configuration',
      ),
    );
    return next;
  }

  List<TenantConfigAuditEntry> auditForTenant(String tenantId) => _auditLog
      .where((entry) => entry.tenantId == tenantId)
      .toList(growable: false);
}

class TenantConfigAuditEntry {
  const TenantConfigAuditEntry({
    required this.tenantId,
    required this.actorLabel,
    required this.changedAt,
    required this.summary,
  });

  final String tenantId;
  final String actorLabel;
  final DateTime changedAt;
  final String summary;
}
