import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/network/openapi/openapi_contract_registry.dart';
import 'package:akshara_erp/core/network/openapi/openapi_response_validator.dart';
import 'package:akshara_erp/core/repositories/api/audit/dto/audit_batch_upload_dto.dart';
import 'package:akshara_erp/core/repositories/api/audit/remote/audit_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/audit/remote/audit_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

const _validator = OpenApiResponseValidator();

void main() {
  group('AuditRemoteDataSource', () {
    test('uploadBatch posts OpenAPI-valid request and parses response', () async {
      Map<String, dynamic>? capturedBody;

      final dio = createFakeDio((options) {
        if (options.path == AuditApiPaths.batch && options.method == 'POST') {
          capturedBody = options.data as Map<String, dynamic>?;
          return {
            'data': {
              'acceptedCount': 1,
              'rejectedIds': [],
            },
          };
        }
        return const {'data': {}};
      });

      final remote = AuditRemoteDataSource(dio);
      final events = [
        AuditEvent(
          id: 'audit_remote_1',
          type: AuditEventType.login,
          timestamp: DateTime.utc(2026, 6, 7, 12),
          userId: 'user_1',
          tenantId: 'tenant_1',
        ),
      ];

      final response = await remote.uploadBatch(events);

      expect(response.acceptedCount, 1);
      expect(capturedBody, isNotNull);

      final requestSchema =
          OpenApiContractRegistry.requestSchemaForPath(AuditApiPaths.batch)!;
      expect(_validator.validate(capturedBody, requestSchema), isEmpty);

      final responseSchema =
          OpenApiContractRegistry.responseSchemaForPath(AuditApiPaths.batch)!;
      expect(
        _validator.validate(
          {'data': {'acceptedCount': 1, 'rejectedIds': []}},
          responseSchema,
        ),
        isEmpty,
      );
    });

    test('uploadBatch returns zero accepted for empty batch', () async {
      final remote = AuditRemoteDataSource(createFakeDio((_) => const {}));
      final response = await remote.uploadBatch(const []);
      expect(response.acceptedCount, 0);
    });

    test('AuditBatchUploadRequestDto serializes event fields', () {
      final dto = AuditBatchUploadRequestDto.fromEvents([
        AuditEvent(
          id: 'audit_dto_1',
          type: AuditEventType.permissionDenied,
          timestamp: DateTime.utc(2026, 6, 7, 12, 30),
          correlationId: 'corr_abc',
          category: AuditEventCategory.security,
          metadata: const {'route': '/finance'},
        ),
      ]);

      final json = dto.toJson();
      expect(json['events'], hasLength(1));
      expect(json['events'][0]['type'], 'permissionDenied');
      expect(json['events'][0]['category'], 'security');
      expect(json['events'][0]['metadata']['route'], '/finance');
    });
  });
}
