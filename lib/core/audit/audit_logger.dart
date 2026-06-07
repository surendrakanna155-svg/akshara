import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'audit_event.dart';
import 'audit_retention_policy.dart';
import 'audit_security_categorizer.dart';
import 'audit_upload_queue.dart';

const String kAuditLogStorageKey = 'audit_events_v1';
const int kAuditLogMaxEntries = 200;

/// Persists audit events locally for later server upload.
class AuditLogger {
  AuditLogger(
    this._prefs, {
    AuditRetentionPolicy retentionPolicy = const AuditRetentionPolicy(
      maxEntries: kAuditLogMaxEntries,
    ),
    AuditUploadQueue? uploadQueue,
  })  : _retentionPolicy = retentionPolicy,
        _uploadQueue = uploadQueue;

  final SharedPreferences _prefs;
  final AuditRetentionPolicy _retentionPolicy;
  final AuditUploadQueue? _uploadQueue;

  Future<void> log(AuditEvent event) async {
    final events = await readAll();
    events.insert(0, event);
    final retained = _retentionPolicy.apply(events);
    await _write(retained);
    await _uploadQueue?.enqueue(event);
  }

  Future<void> logTyped({
    required AuditEventType type,
    String? userId,
    String? tenantId,
    String? schoolId,
    String? correlationId,
    AuditEventCategory? category,
    Map<String, String> metadata = const {},
  }) {
    final resolvedCorrelationId =
        correlationId ?? AuditEvent.correlationIdFromMetadata(metadata);
    final resolvedCategory =
        category ?? AuditSecurityCategorizer.categorize(type);

    return log(
      AuditEvent(
        id: 'audit_${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        timestamp: DateTime.now(),
        userId: userId,
        tenantId: tenantId,
        schoolId: schoolId,
        correlationId: resolvedCorrelationId,
        category: resolvedCategory,
        metadata: metadata,
      ),
    );
  }

  Future<List<AuditEvent>> readAll() async {
    final raw = _prefs.getString(kAuditLogStorageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) AuditEvent.fromJson(item),
      ];
    } on Object {
      return [];
    }
  }

  Future<List<AuditEvent>> readByType(AuditEventType type) async {
    final all = await readAll();
    return all.where((e) => e.type == type).toList(growable: false);
  }

  Future<void> clear() async {
    await _prefs.remove(kAuditLogStorageKey);
  }

  Future<void> _write(List<AuditEvent> events) async {
    final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
    await _prefs.setString(kAuditLogStorageKey, encoded);
  }
}
