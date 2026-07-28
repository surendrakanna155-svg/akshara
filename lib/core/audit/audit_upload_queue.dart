import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'audit_event.dart';
import 'audit_upload_status.dart';

const String kAuditUploadQueueStorageKey = 'audit_upload_queue_v1';

/// Counter of entries discarded because the queue was full. Persisted so the
/// loss survives a restart — see [AuditUploadQueue.droppedCount].
const String kAuditUploadQueueDroppedKey = 'audit_upload_queue_dropped_v1';

/// Hard cap on queued uploads.
///
/// The queue was previously unbounded, and entries were only ever removed on
/// SUCCESS ([markUploaded]). Combined with the retry ceiling — the uploader
/// skips anything at or past `maxRetries` — an entry that could never succeed
/// was never retried AND never deleted. That is not hypothetical: audit ingest
/// is staff-scope-only server-side, so a parent's or student's device receives a
/// permanent 403 and its queue grows for the life of the install. Every
/// subsequent audit write then costs a full decode+encode of an ever-larger
/// list, so the device gets monotonically slower forever.
///
/// 500 is deliberately larger than the 200-entry local audit log: this queue
/// holds evidence in transit, so it should absorb a long offline stretch before
/// it starts losing anything.
const int kAuditUploadQueueMaxEntries = 500;

/// Retry ceiling past which an entry is considered permanently undeliverable and
/// is purged. Must be >= `AuditUploadService.maxRetries` (5), or the queue would
/// drop entries the uploader would still have retried.
const int kAuditUploadQueueMaxRetries = 5;

/// Persists pending audit uploads for offline retry.
class AuditUploadQueue {
  AuditUploadQueue(this._prefs);

  final SharedPreferences _prefs;

  /// How many entries have been discarded because the queue was full.
  ///
  /// Silently losing audit data is itself an audit defect, so the loss is
  /// counted and kept rather than dropped on the floor. Surface this anywhere
  /// queue health is shown.
  int get droppedCount => _prefs.getInt(kAuditUploadQueueDroppedKey) ?? 0;

  Future<void> enqueue(AuditEvent event) async {
    var entries = await readAll();
    if (entries.any((e) => e.event.id == event.id)) return;

    // Self-heal on the way in: purge entries the uploader has permanently given
    // up on. Doing it here (rather than in the uploader) means a queue that is
    // never drained — e.g. on a device whose ingest is refused — still cannot
    // accumulate dead weight indefinitely.
    entries = entries
        .where((e) => e.retryCount < kAuditUploadQueueMaxRetries)
        .toList();

    entries.add(
      AuditUploadEntry(event: event, status: UploadStatus.pending),
    );

    if (entries.length > kAuditUploadQueueMaxEntries) {
      // Drop from the OLDEST end. Both ends lose evidence, so this is a real
      // trade-off: dropping the newest would keep the start of an incident but
      // discard the events describing what it became, and would also mean a
      // full queue silently stops recording anything new. Keeping the most
      // recent window is the more useful failure mode for support, and the
      // count below makes the loss visible rather than silent.
      final overflow = entries.length - kAuditUploadQueueMaxEntries;
      entries.removeRange(0, overflow);
      await _prefs.setInt(kAuditUploadQueueDroppedKey, droppedCount + overflow);
    }

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
    await _prefs.remove(kAuditUploadQueueDroppedKey);
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
