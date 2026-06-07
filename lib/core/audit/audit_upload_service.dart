import 'audit_event.dart';
import 'audit_upload_queue.dart';
import 'audit_upload_status.dart';

/// Uploads queued audit events in batches with exponential backoff retry.
class AuditUploadService {
  AuditUploadService({
    required AuditUploadQueue queue,
    required AuditBatchUploader uploader,
    this.batchSize = 20,
    this.maxRetries = 5,
    this.baseRetryDelay = const Duration(seconds: 1),
    DateTime Function()? clock,
  })  : _queue = queue,
        _uploader = uploader,
        _clock = clock ?? DateTime.now;

  final AuditUploadQueue _queue;
  final AuditBatchUploader _uploader;
  final int batchSize;
  final int maxRetries;
  final Duration baseRetryDelay;
  final DateTime Function() _clock;

  bool _isProcessing = false;

  Future<void> enqueue(AuditEvent event) => _queue.enqueue(event);

  /// Processes all eligible pending entries, respecting [batchSize].
  Future<void> flush() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      await _processPending();
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processPending() async {
    while (true) {
      final pending = await _eligibleEntries();
      if (pending.isEmpty) return;

      final batch = pending.take(batchSize).toList(growable: false);
      final events = batch.map((e) => e.event).toList(growable: false);

      for (final entry in batch) {
        await _queue.markUploading(entry.event.id);
      }

      try {
        await _uploader(events);
        for (final entry in batch) {
          await _queue.markUploaded(entry.event.id);
        }
      } on Object catch (error) {
        final now = _clock();
        for (final entry in batch) {
          final nextRetryCount = entry.retryCount + 1;
          await _queue.markFailed(
            entry.event.id,
            error: '$error',
            retryCount: nextRetryCount,
            attemptedAt: now,
          );
        }
        return;
      }
    }
  }

  Future<List<AuditUploadEntry>> _eligibleEntries() async {
    final pending = await _queue.pendingEntries();
    final now = _clock();
    return pending.where((entry) => _isReadyForRetry(entry, now)).toList();
  }

  bool _isReadyForRetry(AuditUploadEntry entry, DateTime now) {
    if (entry.retryCount >= maxRetries) return false;
    if (entry.status == UploadStatus.pending) return true;
    if (entry.lastAttemptAt == null) return true;

    final delay = _retryDelayFor(entry.retryCount);
    return now.difference(entry.lastAttemptAt!) >= delay;
  }

  Duration _retryDelayFor(int retryCount) {
    if (retryCount <= 0) return Duration.zero;
    final multiplier = 1 << (retryCount - 1);
    return Duration(
      milliseconds: baseRetryDelay.inMilliseconds * multiplier,
    );
  }
}

/// Sends a batch of audit events to the server.
typedef AuditBatchUploader = Future<void> Function(List<AuditEvent> batch);
