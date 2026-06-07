/// Live API remote datasource modules that must propagate tenant context.
class TenantApiPropagationRegistry {
  const TenantApiPropagationRegistry._();

  /// Relative paths under `lib/core/repositories/api/` for tenant propagation tests.
  static const liveRemoteDatasources = <String>[
    'admissions/remote/admissions_remote_datasource.dart',
    'finance/remote/finance_remote_datasource.dart',
    'sis/remote/sis_remote_datasource.dart',
    'auth/remote/auth_remote_datasource.dart',
    'transport/remote/transport_remote_datasource.dart',
    'hr/remote/hr_remote_datasource.dart',
    'hostel/remote/hostel_remote_datasource.dart',
    'library/remote/library_remote_datasource.dart',
    'inventory/remote/inventory_remote_datasource.dart',
    'alumni/remote/alumni_remote_datasource.dart',
    'management/remote/management_remote_datasource.dart',
    'control_center/remote/control_center_remote_datasource.dart',
    'parent/remote/parent_remote_datasource.dart',
    'teacher/remote/teacher_remote_datasource.dart',
    'student/remote/student_remote_datasource.dart',
    'audit/remote/audit_remote_datasource.dart',
  ];

  static const requiredTenantMarkers = <String>[
    'tenantId',
    'TenantInterceptor',
    'ApiConfig.tenantIdHeader',
  ];
}
