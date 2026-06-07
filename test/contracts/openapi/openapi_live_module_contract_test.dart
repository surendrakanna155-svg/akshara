import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/network/openapi/openapi_contract_registry.dart';
import 'package:akshara_erp/core/network/openapi/openapi_response_validator.dart';
import 'package:akshara_erp/core/repositories/api/admissions/remote/admissions_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/auth/remote/auth_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/sis/remote/sis_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/hr/remote/hr_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/transport/remote/transport_api_paths.dart';
import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_hr_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_transport_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../admissions/admissions_fixture_builder.dart';
import '../auth/auth_fixture_builder.dart';
import '../finance/finance_fixture_builder.dart';
import '../hr/hr_fixture_builder.dart';
import '../sis/sis_fixture_builder.dart';
import '../transport/transport_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _authFixtures = AuthFixtureBuilder();
const _admissionsFixtures = AdmissionsFixtureBuilder();
const _financeFixtures = FinanceFixtureBuilder();
const _sisFixtures = SisFixtureBuilder();
const _hrFixtures = HrFixtureBuilder();
const _transportFixtures = TransportFixtureBuilder();
const _validator = OpenApiResponseValidator();

void main() {
  group('OpenAPI live module fixture contracts', () {
    test('auth permissions fixture matches OpenAPI schema', () {
      final payload = _authFixtures.permissionsEnvelope();
      final schema =
          OpenApiContractRegistry.responseSchemaForPath(AuthApiPaths.permissions)!;
      expect(_validator.validate(payload, schema), isEmpty);
    });

    test('auth user fixture matches OpenAPI schema', () {
      final payload = _authFixtures.userEnvelope();
      final schema =
          OpenApiContractRegistry.responseSchemaForPath(AuthApiPaths.me)!;
      expect(_validator.validate(payload, schema), isEmpty);
    });

    test('admissions dashboard fixture matches OpenAPI schema', () async {
      final mockData =
          await MockAdmissionsRepository().getDashboard(query: kQuery);
      final payload = _admissionsFixtures.dashboardEnvelope(mockData);
      final schema = OpenApiContractRegistry.responseSchemaForPath(
        AdmissionsApiPaths.dashboard,
      )!;
      expect(_validator.validate(payload, schema), isEmpty);
    });

    test('finance dashboard fixture matches OpenAPI schema', () async {
      final mockData = await MockFinanceRepository().getDashboard(query: kQuery);
      final payload = _financeFixtures.dashboardEnvelope(mockData);
      final schema = OpenApiContractRegistry.responseSchemaForPath(
        FinanceApiPaths.dashboard,
      )!;
      expect(_validator.validate(payload, schema), isEmpty);
    });

    test('sis dashboard fixture matches OpenAPI schema', () async {
      final mockData = await MockSisRepository().getDashboard(query: kQuery);
      final payload = _sisFixtures.dashboardEnvelope(mockData);
      final schema =
          OpenApiContractRegistry.responseSchemaForPath(SisApiPaths.dashboard)!;
      expect(_validator.validate(payload, schema), isEmpty);
    });

    test('hr dashboard fixture matches OpenAPI schema', () async {
      final mockData = await MockHrRepository().getDashboard(query: kQuery);
      final payload = _hrFixtures.dashboardEnvelope(mockData);
      final schema =
          OpenApiContractRegistry.responseSchemaForPath(HrApiPaths.dashboard)!;
      expect(_validator.validate(payload, schema), isEmpty);
    });

    test('transport dashboard fixture matches OpenAPI schema', () async {
      final mockData =
          await MockTransportRepository().getDashboard(query: kQuery);
      final payload = _transportFixtures.dashboardEnvelope(mockData);
      final schema = OpenApiContractRegistry.responseSchemaForPath(
        TransportApiPaths.dashboard,
      )!;
      expect(_validator.validate(payload, schema), isEmpty);
    });

    test('audit batch request built from events matches OpenAPI schema', () {
      final request = {
        'events': [
          AuditEvent(
            id: 'audit_contract_1',
            type: AuditEventType.permissionSync,
            timestamp: DateTime.utc(2026, 6, 7, 12),
            userId: 'staff_1',
            tenantId: 'tenant_1',
            correlationId: 'corr_1',
            category: AuditEventCategory.security,
          ).toJson(),
        ],
      };
      final schema = OpenApiContractRegistry.requestSchemaForPath(
        '/audit/events/batch',
      )!;
      expect(_validator.validate(request, schema), isEmpty);
    });
  });
}
