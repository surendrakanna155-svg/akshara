import 'package:akshara_erp/core/audit/audit_compliance_providers.dart';
import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/repositories/api/audit/remote/audit_api_paths.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

void main() {
  group('Audit API integration', () {
    setUp(() async {
      await initProviderTestPrefs();
    });

    test('auditBatchUploaderProvider uploads when audit API enabled', () async {
      final uploaded = <List<AuditEvent>>[];

      final container = createProviderTestContainer(
        auditApiEnabled: true,
        apiAuditDio: createFakeDio((options) {
          if (options.path == AuditApiPaths.batch) {
            uploaded.add([
              for (final raw in (options.data as Map)['events'] as List)
                AuditEvent.fromJson(Map<String, dynamic>.from(raw as Map)),
            ]);
            return {
              'data': {'acceptedCount': 1, 'rejectedIds': []},
            };
          }
          return const {'data': {}};
        }),
      );
      addTearDown(container.dispose);

      final uploader = container.read(auditBatchUploaderProvider);
      final event = AuditEvent(
        id: 'audit_integration_1',
        type: AuditEventType.permissionSync,
        timestamp: DateTime.utc(2026, 6, 7, 12),
      );

      await uploader([event]);

      expect(uploaded, hasLength(1));
      expect(uploaded.single.single.id, 'audit_integration_1');
    });

    test('auditUploadService drains queue through remote uploader', () async {
      final container = createProviderTestContainer(
        auditApiEnabled: true,
        apiAuditDio: createFakeDio((options) {
          if (options.path == AuditApiPaths.batch) {
            return {
              'data': {
                'acceptedCount':
                    ((options.data as Map)['events'] as List).length,
              },
            };
          }
          return const {'data': {}};
        }),
      );
      addTearDown(container.dispose);

      final service = container.read(auditUploadServiceProvider);
      await service.enqueue(
        AuditEvent(
          id: 'audit_queue_1',
          type: AuditEventType.login,
          timestamp: DateTime.utc(2026, 6, 7, 12),
        ),
      );

      await service.flush();
      expect(await container.read(auditPendingUploadsProvider.future), isEmpty);
    });

    test('auditBatchUploaderProvider throws when audit API disabled', () async {
      final container = createProviderTestContainer();
      addTearDown(container.dispose);

      final uploader = container.read(auditBatchUploaderProvider);
      expect(
        () => uploader([
          AuditEvent(
            id: 'audit_disabled',
            type: AuditEventType.login,
            timestamp: DateTime.utc(2026, 6, 7, 12),
          ),
        ]),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
