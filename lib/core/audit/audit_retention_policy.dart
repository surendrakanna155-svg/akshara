import 'audit_event.dart';

/// Controls local audit log size and age limits.
class AuditRetentionPolicy {
  const AuditRetentionPolicy({
    this.maxEntries = 200,
    this.ttl = const Duration(days: 30),
  });

  final int maxEntries;
  final Duration ttl;

  bool isExpired(DateTime timestamp, [DateTime? now]) {
    final reference = now ?? DateTime.now();
    return reference.difference(timestamp) > ttl;
  }

  /// Returns events within [ttl], capped at [maxEntries] (newest first).
  List<AuditEvent> apply(List<AuditEvent> events, [DateTime? now]) {
    final reference = now ?? DateTime.now();
    final retained = events
        .where((e) => !isExpired(e.timestamp, reference))
        .take(maxEntries)
        .toList(growable: false);
    return retained;
  }
}
