import 'package:akshara_erp/core/audit/audit_health_monitor.dart';
import 'package:akshara_erp/core/audit/audit_readiness.dart';
import 'package:akshara_erp/core/audit/audit_retention_policy.dart';
import 'package:akshara_erp/core/audit/audit_upload_queue.dart';
import 'package:akshara_erp/core/audit/audit_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AuditReadinessVerifier', () {
    late AuditUploadQueue queue;
    late AuditUploadService service;
    late AuditHealthMonitor monitor;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      queue = AuditUploadQueue(prefs);
      service = AuditUploadService(
        queue: queue,
        uploader: (_) async {},
      );
      monitor = AuditHealthMonitor(queue: queue);
    });

    test('ready when API enabled and queue healthy', () async {
      const verifier = AuditReadinessVerifier();
      final result = await verifier.verify(
        queue: queue,
        service: service,
        monitor: monitor,
        retentionPolicy: const AuditRetentionPolicy(),
        auditApiEnabled: true,
      );

      expect(result.checks['queue_accessible'], isTrue);
      expect(result.checks['retention_policy_active'], isTrue);
      expect(result.isReady, isTrue);
    });

    test('not ready when audit API disabled in production mode check', () async {
      const verifier = AuditReadinessVerifier();
      final result = await verifier.verify(
        queue: queue,
        service: service,
        monitor: monitor,
        retentionPolicy: const AuditRetentionPolicy(),
        auditApiEnabled: false,
      );

      expect(result.checks['api_uploader_wired'], isFalse);
      expect(result.isReady, isFalse);
    });
  });
}
