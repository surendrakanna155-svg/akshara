import 'dart:io';

import 'package:akshara_erp/core/network/openapi/openapi_contract_registry.dart';
import 'package:akshara_erp/core/network/openapi/openapi_response_validator.dart';
import 'package:akshara_erp/core/repositories/api/admissions/remote/admissions_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/audit/remote/audit_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/auth/remote/auth_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/hr/remote/hr_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/transport/remote/transport_api_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenAPI spec file', () {
    test('akshara-erp-v1.yaml exists and declares live module paths', () {
      final specFile = File('openapi/akshara-erp-v1.yaml');
      expect(specFile.existsSync(), isTrue);

      final contents = specFile.readAsStringSync();
      expect(contents, contains(AuthApiPaths.permissions));
      expect(contents, contains(AdmissionsApiPaths.dashboard));
      expect(contents, contains(HrApiPaths.dashboard));
      expect(contents, contains(TransportApiPaths.dashboard));
      expect(contents, contains(AuditApiPaths.batch));
      expect(contents, contains('AuditBatchUploadRequest'));
      expect(contents, contains('AuthPermissionsEnvelope'));
    });
  });

  group('OpenApiResponseValidator', () {
    const validator = OpenApiResponseValidator();

    test('validates auth permissions envelope', () {
      final errors = validator.validate(
        {
          'data': {
            'permissions': [
              {'permission': 'viewFinance', 'source': 'server'},
            ],
          },
        },
        OpenApiContractRegistry.authPermissionsEnvelope,
      );
      expect(errors, isEmpty);
    });

    test('reports missing required dashboard kpis', () {
      final errors = validator.validate(
        {'data': {}},
        OpenApiContractRegistry.dashboardEnvelope,
      );
      expect(errors, contains(r'$.data: missing required property "kpis"'));
    });

    test('validates audit batch upload request', () {
      final errors = validator.validate(
        {
          'events': [
            {
              'id': 'audit_1',
              'type': 'login',
              'timestamp': '2026-06-07T12:00:00.000Z',
            },
          ],
        },
        OpenApiContractRegistry.auditBatchUploadRequest,
      );
      expect(errors, isEmpty);
    });

    test('validates audit batch upload response', () {
      final errors = validator.validate(
        {
          'data': {
            'acceptedCount': 2,
            'rejectedIds': [],
          },
        },
        OpenApiContractRegistry.auditBatchUploadResponse,
      );
      expect(errors, isEmpty);
    });
  });

  group('OpenApiContractRegistry', () {
    test('maps live module paths to response schemas', () {
      expect(
        OpenApiContractRegistry.responseSchemaForPath(AuthApiPaths.permissions),
        isNotNull,
      );
      expect(
        OpenApiContractRegistry.responseSchemaForPath(
          AdmissionsApiPaths.dashboard,
        ),
        isNotNull,
      );
      expect(
        OpenApiContractRegistry.requestSchemaForPath(AuditApiPaths.batch),
        isNotNull,
      );
    });
  });
}
