import 'package:akshara_erp/core/auth/auth_security_providers.dart';
import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/features/auth/auth_token_provider.dart';
import 'package:akshara_erp/features/auth/token_storage.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/repositories/api/api_repository_providers.dart';
import 'package:akshara_erp/core/auth/auth_repository_providers.dart';
import 'package:akshara_erp/core/repositories/api/admissions/remote/admissions_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/auth/remote/auth_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
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
  if (admissionsApiEnabled || financeApiEnabled || authApiEnabled || sisApiEnabled) {
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
  return ProviderContainer(
    overrides: providerTestOverrides([...apiOverrides, ...overrides]),
  );
}
