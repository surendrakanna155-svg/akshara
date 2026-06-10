import 'dart:io';

import 'package:akshara_erp/core/network/openapi/openapi_contract_registry.dart';
import 'package:akshara_erp/core/network/openapi/openapi_response_validator.dart';
import 'package:akshara_erp/core/repositories/api/audit/remote/audit_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/parent/remote/parent_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/student/remote/student_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/teacher/remote/teacher_api_paths.dart';
import 'package:akshara_erp/core/security/server_rbac_route_inventory.dart';
import 'package:akshara_erp/core/tenant/tenant_api_propagation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sprint 6 validation suite — contract, tenant propagation, RBAC inventory parity.
void main() {
  group('Sprint 6 validation suite', () {
    const validator = OpenApiResponseValidator();

    test('OpenAPI spec includes mobile and audit live paths', () {
      final spec = File('openapi/akshara-erp-v1.yaml').readAsStringSync();
      expect(spec, contains(AuditApiPaths.batch));
      expect(spec, contains(ParentApiPaths.dashboard));
      expect(spec, contains(TeacherApiPaths.dashboard));
      expect(spec, contains(StudentApiPaths.dashboard));
    });

    test('audit batch request/response validate against OpenAPI', () {
      expect(
        validator.validate(
          {
            'events': [
              {
                'id': 'sprint6_audit_1',
                'type': 'permissionSync',
                'timestamp': '2026-06-10T10:00:00Z',
              },
            ],
          },
          OpenApiContractRegistry.auditBatchUploadRequest,
        ),
        isEmpty,
      );
      expect(
        validator.validate(
          {
            'data': {'acceptedCount': 1, 'rejectedIds': []},
          },
          OpenApiContractRegistry.auditBatchUploadResponse,
        ),
        isEmpty,
      );
    });

    test('all live remote datasources registered for tenant propagation', () {
      expect(TenantApiPropagationRegistry.liveRemoteDatasources.length, greaterThanOrEqualTo(16));
      for (final module in ['parent', 'teacher', 'student', 'audit']) {
        expect(
          TenantApiPropagationRegistry.liveRemoteDatasources.any((p) => p.contains(module)),
          isTrue,
          reason: 'missing $module datasource',
        );
      }
    });

    test('server RBAC inventory covers post-Sprint 4 modules', () {
      for (final module in ['parent', 'teacher', 'student', 'audit', 'management']) {
        expect(ServerRbacRouteInventory.modules, contains(module));
      }
    });
  });
}
