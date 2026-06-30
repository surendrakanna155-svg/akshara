import 'package:akshara_erp/core/reliability/drafts/draft_controller.dart';
import 'package:akshara_erp/core/reliability/drafts/draft_model.dart';
import 'package:akshara_erp/core/reliability/model/cache_record.dart';
import 'package:akshara_erp/core/reliability/model/mutation_envelope.dart';
import 'package:akshara_erp/core/reliability/model/operation_policy.dart';
import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:akshara_erp/core/reliability/reliable_writer.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/reliability/sync/backoff.dart';
import 'package:akshara_erp/core/reliability/sync/mutation_executor.dart';
import 'package:akshara_erp/core/reliability/sync/sync_engine.dart';
import 'package:akshara_erp/core/reliability/sync/mutation_gateway.dart';
import 'package:akshara_erp/core/repositories/api/teacher/remote/teacher_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/reliability/reliability_fakes.dart';

/// QW7 · QA-C-021 — Data-reliability behaviour cert (end-to-end, one workflow).
///
/// The unit/integration reliability suite proves each property in isolation:
///  • test/core/reliability/draft_controller_test.dart, draft_resume_test.dart —
///    draft autosave + cross-session recovery.
///  • test/integration/reliability/airplane_mode_*.dart — offline queue +
///    sync-on-reconnect + lost-ack idempotency.
///  • test/core/reliability/sync_engine_test.dart — retry/backoff, conflict
///    parking (high-risk) / LWW re-apply (low-risk), exactly-once.
///  • test/core/reliability/qw6_offline_read_cache_store_test.dart — read cache.
///
/// The genuine gap this cert closes: assert ALL of those reliability points
/// across ONE continuous workflow — the teacher's "mark the class, lose the
/// network, come back" loop — so the properties are shown to hold *together*,
/// in order, over the same durable store. It reuses the airplane-mode harness
/// (FakeConnectivity / FakeExecutor / InMemoryReliabilityStore) and the real
/// SyncEngine / DraftController / ReliableWriter; it extends the assertions to
/// the integrated sequence rather than re-proving any single leg.
void main() {
  const RepositoryQuery query =
      RepositoryQuery(tenantId: 't1', schoolId: 's1');

  TeacherAttendanceSubmitRequest attendance() =>
      const TeacherAttendanceSubmitRequest(
        classId: 'class-8a',
        entries: <TeacherAttendanceMarkEntry>[
          TeacherAttendanceMarkEntry(
              studentId: 's1', mark: StudentAttendanceMark.present),
          TeacherAttendanceMarkEntry(
              studentId: 's2', mark: StudentAttendanceMark.absent),
        ],
      );

  group('QA-C-021 · the offline teacher loop — all reliability points in order',
      () {
    test(
        'draft autosave+recovery → offline queue → reconnect sync → exactly once',
        () async {
      final store = InMemoryReliabilityStore();

      // ---- 1. DRAFT AUTOSAVE + RECOVERY ----------------------------------
      // Teacher half-fills the marks form; autosave persists it. The app is
      // killed; a fresh controller over the SAME store resumes it byte-for-byte.
      final session1 = DraftController(store, userId: 'teacher-1');
      await session1.save(const MapDraft(
        'attendance:class-8a',
        <String, dynamic>{'s1': 'present', 's2': 'absent'},
        draftLabel: 'Class 8A attendance',
      ));
      expect(await session1.hasDraft('attendance:class-8a'), isTrue);

      final session2 = DraftController(store, userId: 'teacher-1');
      final recovered = await session2.recover('attendance:class-8a');
      expect(recovered, isNotNull);
      expect(recovered!.json, <String, dynamic>{'s1': 'present', 's2': 'absent'});
      expect(recovered.label, 'Class 8A attendance');

      // ---- 2. OFFLINE QUEUE ----------------------------------------------
      // The teacher submits while offline → optimistic "Pending sync", nothing
      // sent, the write durably queued.
      final connectivity = FakeConnectivity(online: false);
      final executor = FakeExecutor((req, _) => ok(<String, dynamic>{
            'classId': 'class-8a',
            'serverConfirmed': true,
          }));
      final gateway = MutationGateway(
        registry: OperationPolicyRegistry.withDefaults(),
        executor: executor,
        store: store,
        connectivity: connectivity,
      );
      final ds = TeacherRemoteDataSource(Dio(),
          reliableWriter: ReliableWriter(gateway));

      final result =
          await ds.submitClassAttendance(query: query, request: attendance());
      expect(result.raw['submittedAtLabel'], 'Pending sync');
      expect(executor.callCount, 0, reason: 'offline → nothing sent');
      final pending = await store.pendingOperations();
      expect(pending, hasLength(1));
      final opId = pending.single.id;

      // On confirmed submit, the form draft is cleared (never re-offered).
      await session2.discard('attendance:class-8a');
      expect(await session2.hasDraft('attendance:class-8a'), isFalse);

      // ---- 3. SYNC ON RECONNECT (exactly once) ---------------------------
      final engine = SyncEngine(
        store: store,
        executor: executor,
        connectivity: connectivity,
        registry: OperationPolicyRegistry.withDefaults(),
      );
      connectivity.setOnline(true);
      await engine.flush();
      expect(executor.callCount, 1, reason: 'sent exactly once on reconnect');
      expect(executor.sent.single.idempotencyKey, opId);
      expect((await store.getOperation(opId))!.status, SyncStatus.confirmed);

      // ---- 4. DUPLICATE PREVENTION ---------------------------------------
      // Re-flush (e.g. another connectivity tick) must NOT re-send.
      await engine.flush();
      expect(executor.callCount, 1, reason: 'no duplicate attendance submit');
      expect(await store.pendingOperations(), isEmpty);

      await engine.dispose();
      await connectivity.dispose();
    });

    test('lost-ack on reconnect replays via idempotency → confirmed, never dup',
        () async {
      // The server applied the write but the 2xx ack was lost; the retry gets a
      // 409 IDEMPOTENCY_CONFLICT which the platform treats as confirmed.
      final store = InMemoryReliabilityStore();
      final connectivity = FakeConnectivity(online: false);
      final executor = FakeExecutor((req, i) {
        if (i == 0) throw const NetworkUnavailableException('ack-drop');
        return idempotencyReplay(<String, dynamic>{'classId': 'class-8a'});
      });
      final gateway = MutationGateway(
        registry: OperationPolicyRegistry.withDefaults(),
        executor: executor,
        store: store,
        connectivity: connectivity,
      );
      final ds = TeacherRemoteDataSource(Dio(),
          reliableWriter: ReliableWriter(gateway));
      await ds.submitClassAttendance(query: query, request: attendance());

      final engine = SyncEngine(
        store: store,
        executor: executor,
        connectivity: connectivity,
        registry: OperationPolicyRegistry.withDefaults(),
        backoff: const Backoff(base: Duration.zero),
      );
      connectivity.setOnline(true);
      await engine.flush(); // drop → stays pending
      await engine.flush(); // retry → idempotency replay → confirmed

      final ops = await store.allOperations();
      expect(ops.single.status, SyncStatus.confirmed,
          reason: 'exactly-once preserved across a lost ack');

      await engine.dispose();
      await connectivity.dispose();
    });
  });

  group('QA-C-021 · retry/backoff + conflict handling on the same store', () {
    late InMemoryReliabilityStore store;
    late FakeConnectivity conn;
    late FixedClock clock;
    final DateTime t0 = DateTime.utc(2026, 6, 30, 9);

    setUp(() {
      store = InMemoryReliabilityStore();
      conn = FakeConnectivity();
      clock = FixedClock(t0);
    });

    Future<void> enqueue(String type, {String id = 'op1'}) => store.putOperation(
          MutationEnvelope(
            request: req(type, id: id),
            status: SyncStatus.pending,
            createdAt: t0,
          ),
        );

    test('transient 5xx → backoff, not retried until due, then confirms',
        () async {
      final exec =
          FakeExecutor((_, i) => i == 0 ? serverError() : ok());
      final engine = SyncEngine(
        store: store,
        executor: exec,
        connectivity: conn,
        registry: OperationPolicyRegistry.withDefaults(),
        backoff: const Backoff(base: Duration(seconds: 2)),
        clock: clock,
        random: FixedRandom(1.0),
      );
      await enqueue(OperationTypes.submitAttendance);

      await engine.flush(); // 503 → pending, attempt 1, nextAttemptAt = +2s
      final op1 = (await store.getOperation('op1'))!;
      expect(op1.status, SyncStatus.pending);
      expect(op1.attempts, 1);
      expect(op1.nextAttemptAt, isNotNull);

      await engine.flush(); // backoff window not elapsed → skipped, no resend
      expect(exec.callCount, 1, reason: 'backoff must hold the retry');

      clock.advance(const Duration(seconds: 2));
      await engine.flush(); // due → 200 → confirmed
      expect((await store.getOperation('op1'))!.status, SyncStatus.confirmed);
      expect(exec.callCount, 2);
    });

    test('high-risk money conflict is PARKED, never auto-overwritten', () async {
      final exec =
          FakeExecutor((_, __) => conflict(<String, dynamic>{'row_version': 7}));
      final engine = SyncEngine(
        store: store,
        executor: exec,
        connectivity: conn,
        registry: OperationPolicyRegistry(const {
          'finance.collectFee': OperationPolicy(
            kind: OperationKind.queueable,
            conflictCategory: ConflictCategory.highRisk,
          ),
        }),
        clock: clock,
      );
      await enqueue('finance.collectFee');

      await engine.flush();
      final op = (await store.getOperation('op1'))!;
      expect(op.status, SyncStatus.conflict,
          reason: 'high-risk write parks for explicit human resolution');
      expect(op.serverRow, <String, dynamic>{'row_version': 7});

      // Parked conflicts are NOT retried automatically (no silent overwrite).
      await engine.flush();
      expect(exec.callCount, 1);

      // Explicit keep-client requeues it for a precondition-guarded resend.
      await engine.resolveConflict('op1', keepClient: true);
      expect((await store.getOperation('op1'))!.status, SyncStatus.pending);
    });

    test('low-risk conflict re-applies (LWW) carrying the server version',
        () async {
      final exec = FakeExecutor((r, i) =>
          i == 0 ? conflict(<String, dynamic>{'row_version': 9}) : ok());
      final engine = SyncEngine(
        store: store,
        executor: exec,
        connectivity: conn,
        registry: OperationPolicyRegistry(const {
          'attendance.mark': OperationPolicy(
            kind: OperationKind.queueable,
            conflictCategory: ConflictCategory.lowRisk,
          ),
        }),
        backoff: const Backoff(base: Duration(seconds: 1)),
        clock: clock,
        random: FixedRandom(1.0),
      );
      await enqueue('attendance.mark');

      await engine.flush(); // 409 → re-enqueued pending with expectedVersion
      expect((await store.getOperation('op1'))!.status, SyncStatus.pending);

      clock.advance(const Duration(seconds: 1));
      await engine.flush(); // resent with precondition → 200 → confirmed
      expect((await store.getOperation('op1'))!.status, SyncStatus.confirmed);
      expect(exec.sent[1].body['expectedVersion'], 9,
          reason: 'LWW carries the server version as a precondition');
    });

    test('permanent 4xx fails fast (no infinite retry of a bad request)',
        () async {
      final exec = FakeExecutor((_, __) => validationError());
      final engine = SyncEngine(
        store: store,
        executor: exec,
        connectivity: conn,
        registry: OperationPolicyRegistry.withDefaults(),
        clock: clock,
      );
      await enqueue(OperationTypes.submitAttendance);

      await engine.flush();
      final op = (await store.getOperation('op1'))!;
      expect(op.status, SyncStatus.failed);
      expect(op.lastError, 'VALIDATION_ERROR');
      // A failed op is not silently retried.
      await engine.flush();
      expect(exec.callCount, 1);
    });
  });

  group('QA-C-021 · offline READ cache keeps the workflow usable offline', () {
    test('last-good read is served back offline; logout wipes it with drafts',
        () async {
      final store = InMemoryReliabilityStore();

      // A prior online read of the class roster was cached.
      await store.putCache(CacheRecord(
        key: 'GET /attendance/class-8a',
        scope: 't1|s1|teacher-1',
        json: const <String, dynamic>{
          'students': <String>['s1', 's2'],
        },
        updatedAt: DateTime(2026, 6, 30, 9),
      ));

      // Offline, the roster is still readable from the cache (workflow usable).
      final hit = await store.getCache('GET /attendance/class-8a');
      expect(hit, isNotNull);
      expect(hit!.json['students'], <String>['s1', 's2']);

      // Logout wipes the cache AND any drafts together (multi-user safety).
      final drafts = DraftController(store, userId: 'teacher-1');
      await drafts.save(const MapDraft('d', <String, dynamic>{'x': 1}));
      expect(await drafts.hasDraft('d'), isTrue);

      await store.clear();
      expect(await store.getCache('GET /attendance/class-8a'), isNull,
          reason: 'logout wipe clears the read cache');
      expect(await drafts.hasDraft('d'), isFalse,
          reason: 'logout wipe clears drafts alongside the cache');
    });
  });
}
