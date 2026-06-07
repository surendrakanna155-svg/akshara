import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'audit_event.dart';
import 'audit_upload_status.dart';

const String kAuditUploadQueueStorageKey = 'audit_upload_queue_v1';

/// Persists pending audit uploads for offline retry.
class AuditUploadQueue {
  AuditUploadQueue(this._prefs);

  final SharedPreferences _prefs;

  Future<void> enqueue(AuditEvent event) async {
    final entries = await readAll();
    if (entries.any((e) => e.event.id == event.id)) return;

    entries.add(
      AuditUploadEntry(event: event, status: UploadStatus.pending),
    );
    await _write(entries);
  }

  Future<List<AuditUploadEntry>> readAll() async {
    final raw = _prefs.getString(kAuditUploadQueueStorageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) AuditUploadEntry.fromJson(item),
      ];
    } on Object {
      return [];
    }
  }

  Future<List<AuditUploadEntry>> pendingEntries() async {
    final all = await readAll();
    return all
        .where(
          (e) =>
              e.status == UploadStatus.pending ||
              e.status == UploadStatus.failed,
        )
        .toList(growable: false);
  }

  Future<void> updateEntry(AuditUploadEntry entry) async {
    final entries = await readAll();
    final index = entries.indexWhere((e) => e.event.id == entry.event.id);
    if (index == -1) return;
    entries[index] = entry;
    await _write(entries);
  }

  Future<void> markUploading(String eventId) async {
    await _updateStatus(eventId, UploadStatus.uploading);
  }

  Future<void> markUploaded(String eventId) async {
    final entries = await readAll();
    entries.removeWhere((e) => e.event.id == eventId);
    await _write(entries);
  }

  Future<void> markFailed(
    String eventId, {
    required String error,
    required int retryCount,
    required DateTime attemptedAt,
  }) async {
    final entries = await readAll();
    final index = entries.indexWhere((e) => e.event.id == eventId);
    if (index == -1) return;

    entries[index] = entries[index].copyWith(
      status: UploadStatus.failed,
      retryCount: retryCount,
      lastAttemptAt: attemptedAt,
      lastError: error,
    );
    await _write(entries);
  }

  Future<void> clear() async {
    await _prefs.remove(kAuditUploadQueueStorageKey);
  }

  Future<void> _updateStatus(String eventId, UploadStatus status) async {
    final entries = await readAll();
    final index = entries.indexWhere((e) => e.event.id == eventId);
    if (index == -1) return;

    entries[index] = entries[index].copyWith(status: status);
    await _write(entries);
  }

  Future<void> _write(List<AuditUploadEntry> entries) async {
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _prefs.setString(kAuditUploadQueueStorageKey, encoded);
  }
}
