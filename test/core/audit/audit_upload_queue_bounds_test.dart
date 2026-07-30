import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_upload_queue.dart';
import 'package:akshara_erp/core/audit/audit_upload_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The upload queue holds audit evidence in transit. It was unbounded, and
/// entries were removed only on SUCCESS — so an entry that could never succeed
/// was never retried and never deleted. On a parent's or student's device that
/// is the guaranteed case, not a hypothetical: audit ingest is staff-scope-only
/// server-side, so those devices get a permanent 403 and the queue grows for the
/// life of the install, making every later audit write cost a full
/// decode+encode of an ever-larger list.
AuditEvent _event(String id) => AuditEvent(
      id: id,
      type: AuditEventType.login,
      timestamp: DateTime.utc(2026, 7, 28),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AuditUploadQueue> newQueue() async =>
      AuditUploadQueue(await SharedPreferences.getInstance());

  group('AuditUploadQueue bounds', () {
    test('never exceeds the cap, however much is enqueued', () async {
      final queue = await newQueue();
      for (var i = 0; i < kAuditUploadQueueMaxEntries + 120; i++) {
        await queue.enqueue(_event('evt_$i'));
      }
      final entries = await queue.readAll();
      expect(entries.length, kAuditUploadQueueMaxEntries);
    });

    test('overflow drops the OLDEST and keeps the most recent window', () async {
      final queue = await newQueue();
      for (var i = 0; i < kAuditUploadQueueMaxEntries + 3; i++) {
        await queue.enqueue(_event('evt_$i'));
      }
      final ids = (await queue.readAll()).map((e) => e.event.id).toList();
      // The three oldest are gone; the newest survived.
      expect(ids, isNot(contains('evt_0')));
      expect(ids, isNot(contains('evt_2')));
      expect(ids, contains('evt_3'));
      expect(
        ids.last,
        'evt_${kAuditUploadQueueMaxEntries + 2}',
      );
    });

    test('a drop is COUNTED — losing audit data silently is its own defect',
        () async {
      final queue = await newQueue();
      expect(queue.droppedCount, 0);
      for (var i = 0; i < kAuditUploadQueueMaxEntries + 7; i++) {
        await queue.enqueue(_event('evt_$i'));
      }
      expect(queue.droppedCount, 7);
    });

    test('a permanently-failed entry is purged and cannot live forever',
        () async {
      final queue = await newQueue();
      await queue.enqueue(_event('doomed'));
      await queue.markFailed(
        'doomed',
        error: '403 Forbidden',
        retryCount: kAuditUploadQueueMaxRetries,
        attemptedAt: DateTime.utc(2026, 7, 28),
      );
      expect((await queue.readAll()).length, 1);

      // The next enqueue self-heals, so a queue that is never drained still
      // cannot accumulate dead weight.
      await queue.enqueue(_event('fresh'));
      final ids = (await queue.readAll()).map((e) => e.event.id).toList();
      expect(ids, ['fresh']);
    });

    test('an entry still within the retry budget is NOT purged', () async {
      final queue = await newQueue();
      await queue.enqueue(_event('retryable'));
      await queue.markFailed(
        'retryable',
        error: 'offline',
        retryCount: kAuditUploadQueueMaxRetries - 1,
        attemptedAt: DateTime.utc(2026, 7, 28),
      );
      await queue.enqueue(_event('fresh'));
      final ids = (await queue.readAll()).map((e) => e.event.id).toSet();
      expect(ids, containsAll(<String>['retryable', 'fresh']));
    });

    test('the purge threshold cannot undercut the uploader retry budget', () {
      // AuditUploadService.maxRetries defaults to 5. If the queue purged below
      // that, it would delete entries the uploader would still have retried —
      // discarding deliverable evidence.
      expect(kAuditUploadQueueMaxRetries, greaterThanOrEqualTo(5));
    });

    test('deduplicates by event id', () async {
      final queue = await newQueue();
      await queue.enqueue(_event('same'));
      await queue.enqueue(_event('same'));
      expect((await queue.readAll()).length, 1);
    });

    test('clear() resets the queue and the drop counter together', () async {
      final queue = await newQueue();
      for (var i = 0; i < kAuditUploadQueueMaxEntries + 2; i++) {
        await queue.enqueue(_event('evt_$i'));
      }
      expect(queue.droppedCount, greaterThan(0));
      await queue.clear();
      expect((await queue.readAll()), isEmpty);
      expect(queue.droppedCount, 0);
    });

    test('pendingEntries still surfaces pending and failed', () async {
      final queue = await newQueue();
      await queue.enqueue(_event('a'));
      await queue.enqueue(_event('b'));
      await queue.markFailed(
        'b',
        error: 'timeout',
        retryCount: 1,
        attemptedAt: DateTime.utc(2026, 7, 28),
      );
      final pending = await queue.pendingEntries();
      expect(pending.map((e) => e.event.id).toSet(), {'a', 'b'});
      expect(
        pending.firstWhere((e) => e.event.id == 'b').status,
        UploadStatus.failed,
      );
    });
  });
}
