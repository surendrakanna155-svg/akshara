import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_upload_queue.dart';
import 'package:akshara_erp/core/audit/audit_upload_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AuditUploadQueue', () {
    late AuditUploadQueue queue;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      queue = AuditUploadQueue(prefs);
    });

    AuditEvent sampleEvent({String id = 'audit_1'}) {
      return AuditEvent(
        id: id,
        type: AuditEventType.login,
        timestamp: DateTime(2026, 6, 7),
        correlationId: 'ak-123',
        category: AuditEventCategory.auth,
      );
    }

    test('enqueue adds pending entry and persists', () async {
      await queue.enqueue(sampleEvent());

      final entries = await queue.readAll();
      expect(entries, hasLength(1));
      expect(entries.first.status, UploadStatus.pending);
      expect(entries.first.event.correlationId, 'ak-123');
    });

    test('enqueue ignores duplicate event ids', () async {
      await queue.enqueue(sampleEvent());
      await queue.enqueue(sampleEvent());

      expect(await queue.readAll(), hasLength(1));
    });

    test('markUploading updates status', () async {
      await queue.enqueue(sampleEvent());
      await queue.markUploading('audit_1');

      final entries = await queue.readAll();
      expect(entries.single.status, UploadStatus.uploading);
    });

    test('markUploaded removes entry from queue', () async {
      await queue.enqueue(sampleEvent());
      await queue.markUploaded('audit_1');

      expect(await queue.readAll(), isEmpty);
    });

    test('markFailed records retry metadata', () async {
      await queue.enqueue(sampleEvent());
      final attemptedAt = DateTime(2026, 6, 7, 13);

      await queue.markFailed(
        'audit_1',
        error: 'network',
        retryCount: 1,
        attemptedAt: attemptedAt,
      );

      final pending = await queue.pendingEntries();
      expect(pending, hasLength(1));
      expect(pending.single.status, UploadStatus.failed);
      expect(pending.single.retryCount, 1);
      expect(pending.single.lastError, 'network');
      expect(pending.single.lastAttemptAt, attemptedAt);
    });

    test('pendingEntries includes pending and failed only', () async {
      await queue.enqueue(sampleEvent(id: 'pending'));
      await queue.enqueue(
        sampleEvent(id: 'failed').copyWith(type: AuditEventType.logout),
      );
      await queue.markFailed(
        'failed',
        error: 'timeout',
        retryCount: 1,
        attemptedAt: DateTime(2026, 6, 7),
      );
      await queue.enqueue(
        sampleEvent(id: 'uploaded').copyWith(type: AuditEventType.tokenRefresh),
      );
      await queue.markUploading('uploaded');
      await queue.markUploaded('uploaded');

      final pending = await queue.pendingEntries();
      expect(pending.map((e) => e.event.id), containsAll(['pending', 'failed']));
      expect(pending.map((e) => e.event.id), isNot(contains('uploaded')));
    });
  });
}
