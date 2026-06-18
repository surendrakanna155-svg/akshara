import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/reports/finance_audit_register_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinanceAuditRegisterService', () {
    const service = FinanceAuditRegisterService();

    test('filters finance module and finance event types', () {
      final events = [
        AuditEvent(
          id: '1',
          type: AuditEventType.login,
          timestamp: DateTime(2026, 6, 1),
        ),
        AuditEvent(
          id: '2',
          type: AuditEventType.collectionCreated,
          timestamp: DateTime(2026, 6, 2),
          metadata: const {'module': 'finance', 'action': 'createCollection'},
        ),
        AuditEvent(
          id: '3',
          type: AuditEventType.studentUpdated,
          timestamp: DateTime(2026, 6, 3),
          metadata: const {'module': 'sis'},
        ),
      ];

      final filtered = service.filterFinanceEvents(events);
      expect(filtered, hasLength(1));
      expect(filtered.first.id, '2');
    });

    test('buildRegisterPdf returns non-empty bytes', () async {
      final bytes = await service.buildRegisterPdf(
        events: [
          AuditEvent(
            id: '2',
            type: AuditEventType.refundApproved,
            timestamp: DateTime(2026, 6, 2),
            metadata: const {
              'module': 'finance',
              'action': 'approveRefund',
              'entityId': 'refund_1',
            },
          ),
        ],
        generatedAtLabel: '2026-06-17',
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
