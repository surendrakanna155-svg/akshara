import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_retention_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuditRetentionPolicy', () {
    const policy = AuditRetentionPolicy(
      maxEntries: 3,
      ttl: Duration(days: 7),
    );

    final now = DateTime(2026, 6, 7, 12);

    AuditEvent eventAt(DateTime timestamp, {String? id}) {
      return AuditEvent(
        id: id ?? 'audit_${timestamp.microsecondsSinceEpoch}',
        type: AuditEventType.login,
        timestamp: timestamp,
      );
    }

    test('isExpired returns true when timestamp exceeds ttl', () {
      final old = now.subtract(const Duration(days: 8));
      expect(policy.isExpired(old, now), isTrue);
    });

    test('isExpired returns false when timestamp is within ttl', () {
      final recent = now.subtract(const Duration(days: 2));
      expect(policy.isExpired(recent, now), isFalse);
    });

    test('apply drops expired events', () {
      final events = [
        eventAt(now.subtract(const Duration(days: 1)), id: 'recent'),
        eventAt(now.subtract(const Duration(days: 10)), id: 'expired'),
      ];

      final retained = policy.apply(events, now);
      expect(retained.map((e) => e.id), ['recent']);
    });

    test('apply caps events at maxEntries keeping newest first', () {
      final events = [
        eventAt(now, id: 'newest'),
        eventAt(now.subtract(const Duration(hours: 1)), id: 'middle'),
        eventAt(now.subtract(const Duration(hours: 2)), id: 'older'),
        eventAt(now.subtract(const Duration(hours: 3)), id: 'oldest'),
      ];

      final retained = policy.apply(events, now);
      expect(retained.map((e) => e.id), ['newest', 'middle', 'older']);
    });
  });
}
