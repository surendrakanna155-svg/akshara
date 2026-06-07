import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_health_monitor.dart';
import 'package:akshara_erp/core/audit/audit_upload_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AuditHealthMonitor', () {
    late AuditUploadQueue queue;
    late AuditHealthMonitor monitor;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      queue = AuditUploadQueue(prefs);
      monitor = AuditHealthMonitor(queue: queue, maxPendingThreshold: 2);
    });

    AuditEvent event(String id) => AuditEvent(
          id: id,
          type: AuditEventType.login,
          timestamp: DateTime.utc(2026, 6, 7),
        );

    test('healthy when queue is empty', () async {
      final snapshot = await monitor.snapshot();
      expect(snapshot.isHealthy, isTrue);
      expect(snapshot.pendingCount, 0);
    });

    test('unhealthy when pending exceeds threshold', () async {
      await queue.enqueue(event('a1'));
      await queue.enqueue(event('a2'));
      await queue.enqueue(event('a3'));

      final snapshot = await monitor.snapshot();
      expect(snapshot.isHealthy, isFalse);
      expect(snapshot.issues, isNotEmpty);
    });

    test('recordFlush updates last flush timestamp', () async {
      monitor.recordFlush(success: true);
      final snapshot = await monitor.snapshot();
      expect(snapshot.lastFlushAt, isNotNull);
    });
  });
}
