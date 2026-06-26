import 'package:akshara_erp/core/auth/auth_security_providers.dart';
import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/features/auth/auth_token_provider.dart';
import 'package:akshara_erp/features/auth/token_storage.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/repositories/api/api_repository_providers.dart';
import 'package:akshara_erp/core/auth/auth_repository_providers.dart';
import 'package:akshara_erp/core/repositories/api/admissions/remote/admissions_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/audit/audit_upload_providers.dart';
import 'package:akshara_erp/core/repositories/api/audit/remote/audit_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/auth/remote/auth_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/alumni/remote/alumni_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/academic_operations/remote/academic_operations_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/workflow/remote/workflow_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/control_center/remote/control_center_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/platform_intelligence/remote/platform_intelligence_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/hostel/remote/hostel_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/hr/remote/hr_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/inventory/remote/inventory_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/library/remote/library_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/management/remote/management_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/transport/remote/transport_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/parent/remote/parent_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/teacher/remote/teacher_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/student/remote/student_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/parent/parent_active_child_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

SharedPreferences? _testPrefs;

/// Initializes mock SharedPreferences for auth/audit integration tests.
Future<void> initProviderTestPrefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  _testPrefs = await SharedPreferences.getInstance();
}

/// Default tenant scope for provider unit tests (avoids auth/storage deps).
List<Override> providerTestOverrides([List<Override> extra = const []]) {
  final base = <Override>[
    repositoryQueryProvider.overrideWith((ref) => RepositoryQuery.demo),
    // Parent reads use the child-scoped query; in prefs-less unit tests
    // short-circuit it to the demo scope (mirrors repositoryQueryProvider) so
    // they don't transitively reach authProvider/SharedPreferences. Tests that
    // need a specific child override parentActiveChildProvider explicitly
    // (their override wins, being appended after this base).
    parentRepositoryQueryProvider.overrideWith((ref) => RepositoryQuery.demo),
    parentActiveChildProvider.overrideWithValue(null),
  ];
  if (_testPrefs != null) {
    base.insert(0, sharedPreferencesProvider.overrideWithValue(_testPrefs!));
    base.insert(
      1,
      secureStorageBackendProvider.overrideWith(
        (ref) => PreferencesStorageBackend(_testPrefs!),
      ),
    );
    base.insert(
      2,
      tokenStorageProvider.overrideWith(
        (ref) => TokenStorage(PreferencesStorageBackend(_testPrefs!)),
      ),
    );
  }
  return [...base, ...extra];
}

ProviderContainer createProviderTestContainer({
  List<Override> overrides = const [],
  Dio? apiAdmissionsDio,
  bool admissionsApiEnabled = false,
  Dio? apiFinanceDio,
  bool financeApiEnabled = false,
  Dio? apiSisDio,
  bool sisApiEnabled = false,
  Dio? apiAuthDio,
  bool authApiEnabled = false,
  Dio? apiAuditDio,
  bool auditApiEnabled = false,
  Dio? apiHrDio,
  bool hrApiEnabled = false,
  Dio? apiTransportDio,
  bool transportApiEnabled = false,
  Dio? apiHostelDio,
  bool hostelApiEnabled = false,
  Dio? apiLibraryDio,
  bool libraryApiEnabled = false,
  Dio? apiInventoryDio,
  bool inventoryApiEnabled = false,
  Dio? apiAlumniDio,
  bool alumniApiEnabled = false,
  Dio? apiManagementDio,
  bool managementApiEnabled = false,
  Dio? apiControlCenterDio,
  bool controlCenterApiEnabled = false,
  Dio? apiPlatformIntelligenceDio,
  bool platformIntelligenceApiEnabled = false,
  Dio? apiParentDio,
  bool parentApiEnabled = false,
  Dio? apiTeacherDio,
  bool teacherApiEnabled = false,
  Dio? apiStudentDio,
  bool studentApiEnabled = false,
  Dio? apiAcademicOperationsDio,
  bool academicOperationsApiEnabled = false,
  Dio? apiWorkflowDio,
  bool workflowApiEnabled = false,
}) {
  final apiOverrides = <Override>[];
  if (apiAdmissionsDio != null) {
    apiOverrides.add(
      admissionsRemoteDataSourceProvider.overrideWith(
        (ref) => AdmissionsRemoteDataSource(apiAdmissionsDio),
      ),
    );
  }
  if (apiFinanceDio != null) {
    apiOverrides.add(
      financeRemoteDataSourceProvider.overrideWith(
        (ref) => FinanceRemoteDataSource(apiFinanceDio),
      ),
    );
  }
  if (apiSisDio != null) {
    apiOverrides.add(
      sisRemoteDataSourceProvider.overrideWith(
        (ref) => SisRemoteDataSource(apiSisDio),
      ),
    );
  }
  if (apiAuthDio != null) {
    apiOverrides.add(
      authRemoteDataSourceProvider.overrideWith(
        (ref) => AuthRemoteDataSource(apiAuthDio),
      ),
    );
  }
  if (apiAuditDio != null) {
    apiOverrides.add(
      auditRemoteDataSourceProvider.overrideWith(
        (ref) => AuditRemoteDataSource(apiAuditDio),
      ),
    );
  }
  if (apiHrDio != null) {
    apiOverrides.add(
      hrRemoteDataSourceProvider.overrideWith(
        (ref) => HrRemoteDataSource(apiHrDio),
      ),
    );
  }
  if (apiTransportDio != null) {
    apiOverrides.add(
      transportRemoteDataSourceProvider.overrideWith(
        (ref) => TransportRemoteDataSource(apiTransportDio),
      ),
    );
  }
  if (apiHostelDio != null) {
    apiOverrides.add(
      hostelRemoteDataSourceProvider.overrideWith(
        (ref) => HostelRemoteDataSource(apiHostelDio),
      ),
    );
  }
  if (apiLibraryDio != null) {
    apiOverrides.add(
      libraryRemoteDataSourceProvider.overrideWith(
        (ref) => LibraryRemoteDataSource(apiLibraryDio),
      ),
    );
  }
  if (apiInventoryDio != null) {
    apiOverrides.add(
      inventoryRemoteDataSourceProvider.overrideWith(
        (ref) => InventoryRemoteDataSource(apiInventoryDio),
      ),
    );
  }
  if (apiAlumniDio != null) {
    apiOverrides.add(
      alumniRemoteDataSourceProvider.overrideWith(
        (ref) => AlumniRemoteDataSource(apiAlumniDio),
      ),
    );
  }
  if (apiManagementDio != null) {
    apiOverrides.add(
      managementRemoteDataSourceProvider.overrideWith(
        (ref) => ManagementRemoteDataSource(apiManagementDio),
      ),
    );
  }
  if (apiControlCenterDio != null) {
    apiOverrides.add(
      controlCenterRemoteDataSourceProvider.overrideWith(
        (ref) => ControlCenterRemoteDataSource(apiControlCenterDio),
      ),
    );
  }
  if (apiPlatformIntelligenceDio != null) {
    apiOverrides.add(
      platformIntelligenceRemoteDataSourceProvider.overrideWith(
        (ref) => PlatformIntelligenceRemoteDataSource(apiPlatformIntelligenceDio),
      ),
    );
  }
  if (apiParentDio != null) {
    apiOverrides.add(
      parentRemoteDataSourceProvider.overrideWith(
        (ref) => ParentRemoteDataSource(apiParentDio),
      ),
    );
  }
  if (apiTeacherDio != null) {
    apiOverrides.add(
      teacherRemoteDataSourceProvider.overrideWith(
        (ref) => TeacherRemoteDataSource(apiTeacherDio),
      ),
    );
  }
  if (apiStudentDio != null) {
    apiOverrides.add(
      studentRemoteDataSourceProvider.overrideWith(
        (ref) => StudentRemoteDataSource(apiStudentDio),
      ),
    );
  }
  if (apiAcademicOperationsDio != null) {
    apiOverrides.add(
      academicOperationsRemoteDataSourceProvider.overrideWith(
        (ref) => AcademicOperationsRemoteDataSource(apiAcademicOperationsDio),
      ),
    );
  }
  if (apiWorkflowDio != null) {
    apiOverrides.add(
      workflowRemoteDataSourceProvider.overrideWith(
        (ref) => WorkflowRemoteDataSource(apiWorkflowDio),
      ),
    );
  }
  if (admissionsApiEnabled ||
      financeApiEnabled ||
      authApiEnabled ||
      sisApiEnabled ||
      auditApiEnabled ||
      hrApiEnabled ||
      transportApiEnabled ||
      hostelApiEnabled ||
      libraryApiEnabled ||
      inventoryApiEnabled ||
      alumniApiEnabled ||
      managementApiEnabled ||
      controlCenterApiEnabled ||
      platformIntelligenceApiEnabled ||
      parentApiEnabled ||
      teacherApiEnabled ||
      studentApiEnabled ||
      academicOperationsApiEnabled ||
      workflowApiEnabled) {
    apiOverrides.add(
      environmentProvider.overrideWith(
        (ref) => Environment.development.copyWith(enableApiMode: true),
      ),
    );
  }
  if (admissionsApiEnabled) {
    apiOverrides.add(
      admissionsApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (financeApiEnabled) {
    apiOverrides.add(
      financeApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (sisApiEnabled) {
    apiOverrides.add(
      sisApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (authApiEnabled) {
    apiOverrides.add(
      authApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (auditApiEnabled) {
    apiOverrides.add(
      auditApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (hrApiEnabled) {
    apiOverrides.add(
      hrApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (transportApiEnabled) {
    apiOverrides.add(
      transportApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (hostelApiEnabled) {
    apiOverrides.add(
      hostelApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (libraryApiEnabled) {
    apiOverrides.add(
      libraryApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (inventoryApiEnabled) {
    apiOverrides.add(
      inventoryApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (alumniApiEnabled) {
    apiOverrides.add(
      alumniApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (managementApiEnabled) {
    apiOverrides.add(
      managementApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (controlCenterApiEnabled) {
    apiOverrides.add(
      controlCenterApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (platformIntelligenceApiEnabled) {
    apiOverrides.add(
      platformIntelligenceApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (parentApiEnabled) {
    apiOverrides.add(
      parentApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (teacherApiEnabled) {
    apiOverrides.add(
      teacherApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (studentApiEnabled) {
    apiOverrides.add(
      studentApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (academicOperationsApiEnabled) {
    apiOverrides.add(
      academicOperationsApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  if (workflowApiEnabled) {
    apiOverrides.add(
      workflowApiEnabledProvider.overrideWith((ref) => true),
    );
  }
  return ProviderContainer(
    overrides: providerTestOverrides([...apiOverrides, ...overrides]),
  );
}

/// Container for mobile feature provider tests (repository + tenant query wired).
ProviderContainer createMobileProviderTestContainer({
  List<Override> overrides = const [],
}) {
  return ProviderContainer(
    overrides: providerTestOverrides(overrides),
  );
}
