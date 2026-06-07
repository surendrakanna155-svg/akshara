import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_logger.dart';
import 'package:akshara_erp/core/audit/audit_upload_queue.dart';
import 'package:akshara_erp/core/audit/audit_upload_service.dart';
import 'package:akshara_erp/core/audit/audit_upload_status.dart';
import 'package:akshara_erp/core/network/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Audit upload integration', () {
    late AuditUploadQueue queue;
    late List<List<AuditEvent>> uploadedBatches;
    late AuditUploadService service;
    var shouldFailUpload = false;
    var now = DateTime(2026, 6, 7, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      queue = AuditUploadQueue(prefs);
      uploadedBatches = [];
      shouldFailUpload = false;
      now = DateTime(2026, 6, 7, 12);

      service = AuditUploadService(
        queue: queue,
        batchSize: 2,
        baseRetryDelay: const Duration(seconds: 1),
        maxRetries: 3,
        clock: () => now,
        uploader: (batch) async {
          if (shouldFailUpload) {
            throw Exception('upload failed');
          }
          uploadedBatches.add(List<AuditEvent>.from(batch));
        },
      );
    });

    test('logger enqueues events for upload after local log', () async {
      final prefs = await SharedPreferences.getInstance();
      final logger = AuditLogger(prefs, uploadQueue: queue);

      await logger.logTyped(
        type: AuditEventType.permissionDenied,
        userId: 'user_1',
        metadata: {ApiConfig.correlationIdHeader: 'ak-corr-1'},
      );

      final local = await logger.readAll();
      expect(local, hasLength(1));
      expect(local.first.correlationId, 'ak-corr-1');
      expect(local.first.category, AuditEventCategory.security);

      final pending = await queue.pendingEntries();
      expect(pending, hasLength(1));
      expect(pending.first.event.id, local.first.id);
    });

    test('flush uploads pending events in batches', () async {
      await service.enqueue(
        AuditEvent(
          id: 'audit_1',
          type: AuditEventType.login,
          timestamp: now,
        ),
      );
      await service.enqueue(
        AuditEvent(
          id: 'audit_2',
          type: AuditEventType.logout,
          timestamp: now,
        ),
      );
      await service.enqueue(
        AuditEvent(
          id: 'audit_3',
          type: AuditEventType.tokenRefresh,
          timestamp: now,
        ),
      );

      await service.flush();

      expect(uploadedBatches, hasLength(2));
      expect(uploadedBatches[0], hasLength(2));
      expect(uploadedBatches[1], hasLength(1));
      expect(await queue.pendingEntries(), isEmpty);
    });

    test('flush marks failed uploads and retries after backoff', () async {
      shouldFailUpload = true;
      await service.enqueue(
        AuditEvent(
          id: 'audit_retry',
          type: AuditEventType.auditUploadFailed,
          timestamp: now,
        ),
      );

      await service.flush();
      var pending = await queue.pendingEntries();
      expect(pending, hasLength(1));
      expect(pending.single.status, UploadStatus.failed);
      expect(pending.single.retryCount, 1);

      await service.flush();
      pending = await queue.pendingEntries();
      expect(pending.single.retryCount, 1);

      now = now.add(const Duration(seconds: 1));
      shouldFailUpload = false;
      await service.flush();

      expect(uploadedBatches, hasLength(1));
      expect(await queue.pendingEntries(), isEmpty);
    });

    test('queue persists across service instances', () async {
      await service.enqueue(
        AuditEvent(
          id: 'audit_persist',
          type: AuditEventType.permissionSync,
          timestamp: now,
        ),
      );

      final restored = AuditUploadService(
        queue: queue,
        batchSize: 20,
        uploader: (batch) async {
          uploadedBatches.add(batch);
        },
      );

      await restored.flush();
      expect(uploadedBatches.single.single.id, 'audit_persist');
    });
  });
}
