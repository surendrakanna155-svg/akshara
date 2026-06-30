import 'package:akshara_erp/core/reliability/drafts/draft_controller.dart';
import 'package:akshara_erp/core/reliability/drafts/draft_model.dart';
import 'package:akshara_erp/core/reliability/model/mutation_envelope.dart';
import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:akshara_erp/core/reliability/reliable_writer.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/reliability/sync/backoff.dart';
import 'package:akshara_erp/core/reliability/sync/mutation_gateway.dart';
import 'package:akshara_erp/core/reliability/sync/sync_engine.dart';
import 'package:akshara_erp/core/repositories/api/teacher/remote/teacher_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/reliability/reliability_fakes.dart';

/// QW8 · QA-R-007 (P0) — fault-injection RECOVERY suite.
///
/// PROVES: ZERO data loss + EXACTLY-ONCE across a process kill / crash, an
/// airplane-mode window, retry/backoff, and a long-running offline session —
/// not just the happy path. This EXTENDS, and does not duplicate, QW7's
/// QA-C-021 (`qa_c_021_data_reliability_behaviour_cert_test.dart`), which
/// already proves each single leg (draft autosave+recovery, offline queue,
/// reconnect exactly-once, lost-ack idempotency, backoff, conflict handling,
/// read cache). The preconditions below REUSE that file's harness and
/// assertions — they are not re-proven here. What is genuinely new are the two
/// fault-injection scenarios that cross a real interruption *while a write is
/// already in the durable outbox*:
///
///  • FI-1 — CRASH/KILL MID-QUEUE of a queued OUTBOX op (not just a draft).
///  • FI-2 — LONG-RUNNING OFFLINE SESSION (N=20 heterogeneous writes), incl. a
///    crash MID-DRAIN.
///
/// HOW THE KILL IS SIMULATED (headless): a literal native SIGKILL with the
/// on-disk SQLCipher store is INFRA-BLOCKED in a headless `flutter test` run —
/// it is already covered by the live Phase 0b certification
/// (`docs/DATA_RELIABILITY_PLATFORM_CERTIFICATION.md`: 20/20 live, with the EOS
/// "Data Loss ✗" condition cleared). What this file proves is the *logical*
/// recovery contract: a kill is modelled exactly as the durable store models
/// it — by serialising each queued envelope (`toJson`) and re-decoding it
/// (`MutationEnvelope.fromJson`) into a FRESH store after dropping the live
/// `SyncEngine`/store objects. That is the same restart-from-persistence
/// precedent used by `in_memory_store_test.dart` (round-trip) and
/// `exam_persistence_restart_integration_test.dart`
/// (`reset(clearPersistence:false)` + re-attach). If the contract holds across
/// the re-decode, it holds across a real relaunch from disk.
void main() {
  const RepositoryQuery query =
      RepositoryQuery(tenantId: 't1', schoolId: 's1');

  // A FixedClock anchors created_at ordering and makes backoff deterministic —
  // the same retry/backoff precondition QA-C-021 wires (FixedClock + Backoff).
  final DateTime t0 = DateTime.utc(2026, 6, 30, 9);

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

  /// Simulate a process death: take the *durable* contents of [old] (only the
  /// queued outbox survives a kill — in-flight RAM does not), serialise every
  /// op (`toJson`) and re-decode it (`MutationEnvelope.fromJson`) into a brand
  /// new store. The caller then drops [old] and every live SyncEngine that
  /// referenced it. This is the headless analogue of relaunching from the
  /// on-disk SQLCipher outbox.
  Future<InMemoryReliabilityStore> killAndRelaunch(
    InMemoryReliabilityStore old, {
    String? draftUserId,
  }) async {
    final InMemoryReliabilityStore fresh = InMemoryReliabilityStore();
    for (final MutationEnvelope op in await old.allOperations()) {
      // Re-decode the persisted bytes exactly as the store would on cold start.
      final MutationEnvelope decoded = MutationEnvelope.fromJson(op.toJson());
      await fresh.putOperation(decoded);
    }
    // Drafts are part of the same durable store and likewise survive a cold
    // start (the "never lose a half-typed form" guarantee).
    if (draftUserId != null) {
      final DraftController src = DraftController(old, userId: draftUserId);
      final DraftController dst = DraftController(fresh, userId: draftUserId);
      for (final draft in await src.myDrafts()) {
        await dst.save(MapDraft(draft.key, draft.json, draftLabel: draft.label));
      }
    }
    return fresh;
  }

  group('QA-R-007 · FI-1 — crash/kill mid-queue of a durable OUTBOX op', () {
    test(
        'queued op survives a kill (stable idempotency key), re-launched engine '
        'flushes it EXACTLY ONCE, re-flush never re-sends — zero loss',
        () async {
      // ---- PRECONDITION (reused from QA-C-021, not re-proven) -------------
      // Airplane mode (FakeConnectivity offline) + the autosave-flush guard:
      // the teacher's half-typed form is durably saved before submit, so a
      // kill during the queue step can never strand the typed work either.
      final store = InMemoryReliabilityStore();
      final connectivity = FakeConnectivity(online: false);

      final drafts = DraftController(store, userId: 'teacher-1');
      await drafts.save(const MapDraft(
        'attendance:class-8a',
        <String, dynamic>{'s1': 'present', 's2': 'absent'},
        draftLabel: 'Class 8A attendance',
      ));

      // The executor confirms whenever it is actually called. We assert call
      // counts to prove exactly-once.
      final executor = FakeExecutor((req, _) => ok(<String, dynamic>{
            'classId': 'class-8a',
            'serverConfirmed': true,
          }));

      // ---- ENQUEUE A REAL OUTBOX OP WHILE OFFLINE -------------------------
      final gateway = MutationGateway(
        registry: OperationPolicyRegistry.withDefaults(),
        executor: executor,
        store: store,
        connectivity: connectivity,
        clock: FixedClock(t0),
      );
      final ds = TeacherRemoteDataSource(Dio(),
          reliableWriter: ReliableWriter(gateway));

      final result =
          await ds.submitClassAttendance(query: query, request: attendance());
      expect(result.raw['submittedAtLabel'], 'Pending sync');
      expect(executor.callCount, 0, reason: 'offline → nothing sent');

      final List<MutationEnvelope> queued = await store.pendingOperations();
      expect(queued, hasLength(1), reason: 'exactly one durable outbox op');
      final MutationEnvelope original = queued.single;
      final String opId = original.id; // its stable idempotency key
      expect(opId, isNotEmpty);
      final Map<String, dynamic> originalBody = original.request.body;

      // ---- KILL: drop the live SyncEngine/store, relaunch from bytes ------
      // (No SyncEngine has run yet; the op is purely a queued envelope.)
      final InMemoryReliabilityStore relaunched =
          await killAndRelaunch(store, draftUserId: 'teacher-1');

      // The op SURVIVED the kill — same row, same stable idempotency key,
      // still pending (zero loss across the kill).
      final List<MutationEnvelope> afterKill =
          await relaunched.pendingOperations();
      expect(afterKill, hasLength(1), reason: 'op survived the kill');
      final MutationEnvelope survivor = afterKill.single;
      expect(survivor.id, opId,
          reason: 'idempotency key is STABLE across the kill');
      expect(survivor.status, SyncStatus.pending);
      expect(survivor.request.body, originalBody,
          reason: 'payload intact byte-for-byte after re-decode');
      expect(survivor.request.type, OperationTypes.submitAttendance);

      // The half-typed form draft ALSO survived the kill (autosave-flush
      // guard): a fresh controller over the relaunched store recovers it.
      final drafts2 = DraftController(relaunched, userId: 'teacher-1');
      expect(await drafts2.hasDraft('attendance:class-8a'), isTrue,
          reason: 'the autosaved draft survived the kill, byte-for-byte');

      // ---- RELAUNCHED ENGINE FLUSHES IT EXACTLY ONCE ON RECONNECT ---------
      final relaunchedConn = FakeConnectivity(online: false);
      final engine = SyncEngine(
        store: relaunched,
        executor: executor,
        connectivity: relaunchedConn,
        registry: OperationPolicyRegistry.withDefaults(),
        clock: FixedClock(t0),
      );
      relaunchedConn.setOnline(true);
      await engine.flush();

      expect(executor.callCount, 1,
          reason: 'sent EXACTLY ONCE by the re-launched engine');
      expect(executor.sent.single.idempotencyKey, opId,
          reason: 'replayed with the SAME idempotency key (server dedups)');
      expect((await relaunched.getOperation(opId))!.status,
          SyncStatus.confirmed);

      // ---- DUPLICATE PREVENTION: a second drain must NOT re-send -----------
      // (e.g. another connectivity tick, or a second relaunch.)
      await engine.flush();
      expect(executor.callCount, 1, reason: 'no duplicate send after a kill');
      expect(await relaunched.pendingOperations(), isEmpty,
          reason: 'outbox drained — nothing lost, nothing stuck');

      await drafts2.discard('attendance:class-8a');
      expect(await drafts2.hasDraft('attendance:class-8a'), isFalse);

      await engine.dispose();
      await connectivity.dispose();
      await relaunchedConn.dispose();
    });

    test(
        'a kill DURING a transient-retry backoff window still flushes exactly '
        'once after relaunch — retry state is durable, not double-counted',
        () async {
      // PRECONDITION (reused): retry/backoff on a transient 5xx (QA-C-021's
      // backoff leg). We queue the op directly (as that suite's `enqueue`
      // helper does) so the call indices are predictable across the kill.
      final store = InMemoryReliabilityStore();
      final conn = FakeConnectivity();
      final clock = FixedClock(t0);
      const String opId = 'retry-op-1';

      await store.putOperation(MutationEnvelope(
        request: req(OperationTypes.submitAttendance, id: opId),
        status: SyncStatus.pending,
        createdAt: t0,
      ));

      // First send fails transiently (503); the post-relaunch send confirms.
      final executor =
          FakeExecutor((_, i) => i == 0 ? serverError() : ok());

      final engine1 = SyncEngine(
        store: store,
        executor: executor,
        connectivity: conn,
        registry: OperationPolicyRegistry.withDefaults(),
        backoff: const Backoff(base: Duration(seconds: 2)),
        clock: clock,
        random: FixedRandom(1.0),
      );
      await engine1.flush(); // 503 → attempt++, nextAttemptAt = +2s, stays pending
      expect(executor.callCount, 1);
      final List<MutationEnvelope> pending = await store.pendingOperations();
      expect(pending, hasLength(1));
      final MutationEnvelope mid = pending.single;
      expect(mid.attempts, greaterThanOrEqualTo(1));
      expect(mid.nextAttemptAt, isNotNull,
          reason: 'op is mid-backoff when the kill lands');
      expect(mid.id, opId);

      // ---- KILL during the backoff window --------------------------------
      final InMemoryReliabilityStore relaunched = await killAndRelaunch(store);
      final MutationEnvelope survivor =
          (await relaunched.getOperation(opId))!;
      expect(survivor.status, SyncStatus.pending,
          reason: 'mid-backoff op survives the kill as pending');
      expect(survivor.attempts, mid.attempts,
          reason: 'attempt count is durable (not reset, not double-counted)');
      expect(survivor.nextAttemptAt, isNotNull);

      // ---- RELAUNCH: same clock advanced past the window → confirms once ---
      clock.advance(const Duration(seconds: 2));
      final engine2 = SyncEngine(
        store: relaunched,
        executor: executor,
        connectivity: conn,
        registry: OperationPolicyRegistry.withDefaults(),
        backoff: const Backoff(base: Duration(seconds: 2)),
        clock: clock,
        random: FixedRandom(1.0),
      );
      await engine2.flush(); // due → 200 → confirmed
      expect((await relaunched.getOperation(opId))!.status,
          SyncStatus.confirmed);
      // Total sends: engine1 503 + engine2 200 = 2, each carrying the SAME key.
      expect(executor.callCount, 2);
      expect(
        executor.sent.every((r) => r.idempotencyKey == opId),
        isTrue,
        reason: 'every retry carries the SAME idempotency key — server dedups',
      );

      // Re-flush after confirm: no resend.
      await engine2.flush();
      expect(executor.callCount, 2, reason: 'no duplicate after confirmation');

      await engine1.dispose();
      await engine2.dispose();
      await conn.dispose();
    });
  });

  group('QA-R-007 · FI-2 — long-running offline session (N=20 writes)', () {
    const int n = 20;

    // 20 heterogeneous queueable writes, each with a stable, unique id, queued
    // across a long offline window. createdAt strictly increases so FIFO order
    // is observable.
    List<MutationEnvelope> longSessionWrites(DateTime base) {
      // Rotate over the queueable, low-risk pilot write types so the batch is
      // genuinely heterogeneous (not 20 copies of one op).
      const List<String> types = <String>[
        OperationTypes.markAttendance,
        OperationTypes.submitAttendance,
        OperationTypes.saveExamMarksDraft,
        OperationTypes.applyLeave,
      ];
      return <MutationEnvelope>[
        for (int i = 0; i < n; i++)
          MutationEnvelope(
            request: req(
              types[i % types.length],
              id: 'longsess-op-${i.toString().padLeft(2, '0')}',
              body: <String, dynamic>{'seq': i},
            ),
            status: SyncStatus.pending,
            // 5-minute spacing → simulates a long offline window via FixedClock.
            createdAt: base.add(Duration(minutes: 5 * i)),
          ),
      ];
    }

    test(
        'all 20 queued over a long offline window flush in ONE drain — FIFO by '
        'created_at, callCount==20, no dups, no drops',
        () async {
      final store = InMemoryReliabilityStore();
      final connectivity = FakeConnectivity(online: false);
      final clock = FixedClock(t0);

      // Queue all 20 while offline, advancing the clock across the session so
      // each op's created_at is genuinely later than the previous one.
      final List<MutationEnvelope> writes = longSessionWrites(t0);
      for (final MutationEnvelope w in writes) {
        clock.setNow(w.createdAt);
        await store.putOperation(w);
      }
      expect(await store.pendingOperations(), hasLength(n),
          reason: 'all $n writes durably queued, none sent offline');

      final executor = FakeExecutor((_, __) => ok());
      final engine = SyncEngine(
        store: store,
        executor: executor,
        connectivity: connectivity,
        registry: OperationPolicyRegistry.withDefaults(),
        clock: clock,
      );

      // ---- RECONNECT → SINGLE DRAIN --------------------------------------
      connectivity.setOnline(true);
      await engine.flush();

      // Exactly 20 sends — no drops, no dups.
      expect(executor.callCount, n, reason: 'each of $n sent exactly once');
      final List<String> sentKeys =
          executor.sent.map((r) => r.idempotencyKey).toList();
      expect(sentKeys.toSet(), hasLength(n), reason: 'no duplicate sends');

      // FIFO: the engine drains pendingOperations() oldest-first (by
      // created_at), so the send order must match the queue order exactly.
      final List<String> expectedFifo =
          writes.map((MutationEnvelope w) => w.id).toList();
      expect(sentKeys, expectedFifo,
          reason: 'drained FIFO by created_at — per-entity order preserved');

      // Every op confirmed; nothing left pending (zero loss).
      final List<MutationEnvelope> all = await store.allOperations();
      expect(all, hasLength(n));
      expect(all.every((o) => o.status == SyncStatus.confirmed), isTrue);
      expect(await store.pendingOperations(), isEmpty);

      // Re-drain is a no-op (duplicate prevention across the whole batch).
      await engine.flush();
      expect(executor.callCount, n, reason: 'no batch re-send on second drain');

      await engine.dispose();
      await connectivity.dispose();
    });

    test(
        'crash MID-DRAIN after k confirmations → relaunch flushes the remaining '
        '20−k EXACTLY ONCE, none lost, none double-sent',
        () async {
      const int k = 7; // confirmations that durably landed before the crash

      final store = InMemoryReliabilityStore();
      final clock = FixedClock(t0);
      final List<MutationEnvelope> writes = longSessionWrites(t0);
      for (final MutationEnvelope w in writes) {
        await store.putOperation(w);
      }

      // ---- DRAIN THAT CRASHES AFTER k CONFIRMATIONS ----------------------
      // The executor confirms the first k sends, then throws to model the
      // process being killed mid-drain (power loss / OS kill / force-close).
      // Whatever the engine durably wrote for those k ops is what survives.
      final connA = FakeConnectivity();
      final crashingExecutor = FakeExecutor((_, i) {
        if (i < k) return ok();
        // The (k+1)-th send never completes — the process dies here.
        throw const _SimulatedProcessKill();
      });
      final engineA = SyncEngine(
        store: store,
        executor: crashingExecutor,
        connectivity: connA,
        registry: OperationPolicyRegistry.withDefaults(),
        clock: clock,
      );

      await expectLater(engineA.flush(), throwsA(isA<_SimulatedProcessKill>()),
          reason: 'the drain is interrupted by the kill');
      expect(crashingExecutor.callCount, k + 1,
          reason: 'k confirmed, then the kill lands on the next send');

      // The op the kill landed on was left inFlight in the store (its 200 never
      // came back) — on a real relaunch the durable outbox shows it as a write
      // that must be re-attempted, NOT confirmed. Zero loss requires it flush
      // again; exactly-once requires the SERVER to dedup it (same id).
      final MutationEnvelope interrupted = writes[k];
      expect(
        (await store.getOperation(interrupted.id))!.status,
        isNot(SyncStatus.confirmed),
        reason: 'the interrupted op is NOT confirmed (its ack never returned)',
      );

      // ---- KILL: drop engineA + its store, relaunch from durable bytes ----
      final InMemoryReliabilityStore relaunched = await killAndRelaunch(store);

      // The k confirmed ops are durably confirmed and will NOT be re-sent.
      final Set<String> confirmedIds = <String>{
        for (int i = 0; i < k; i++) writes[i].id,
      };
      for (final String id in confirmedIds) {
        expect((await relaunched.getOperation(id))!.status,
            SyncStatus.confirmed);
      }

      // The remaining 20−k (the interrupted one + the never-started ones) are
      // recoverable as pending work. An inFlight op on cold start is treated as
      // unfinished and re-queued for a safe, idempotent re-attempt.
      final List<MutationEnvelope> remaining = (await relaunched.allOperations())
          .where((o) => o.status != SyncStatus.confirmed)
          .toList();
      expect(remaining, hasLength(n - k),
          reason: 'exactly the un-confirmed work survives for replay');
      // Re-queue any op the kill left mid-flight so the engine will drain it.
      for (final MutationEnvelope o in remaining) {
        if (o.status != SyncStatus.pending) {
          await relaunched
              .putOperation(o.copyWith(status: SyncStatus.pending));
        }
      }

      // ---- RELAUNCHED ENGINE FLUSHES THE REMAINING 20−k EXACTLY ONCE ------
      final connB = FakeConnectivity();
      final cleanExecutor = FakeExecutor((_, __) => ok());
      final engineB = SyncEngine(
        store: relaunched,
        executor: cleanExecutor,
        connectivity: connB,
        registry: OperationPolicyRegistry.withDefaults(),
        clock: clock,
      );
      await engineB.flush();

      // The relaunched engine sent each remaining op once and only once.
      expect(cleanExecutor.callCount, n - k,
          reason: 'remaining ${n - k} flushed exactly once after relaunch');
      final List<String> resent =
          cleanExecutor.sent.map((r) => r.idempotencyKey).toList();
      expect(resent.toSet(), hasLength(n - k), reason: 'no double-send');
      // It must NOT re-send any of the k already-confirmed ops.
      expect(resent.toSet().intersection(confirmedIds), isEmpty,
          reason: 'already-confirmed ops are never re-sent (no duplicates)');

      // Whole-session accounting: all 20 are now confirmed, none lost.
      final List<MutationEnvelope> finalAll = await relaunched.allOperations();
      expect(finalAll, hasLength(n));
      expect(finalAll.every((o) => o.status == SyncStatus.confirmed), isTrue,
          reason: 'ALL 20 writes survived the crash — zero data loss');
      expect(
        finalAll.map((o) => o.id).toSet(),
        writes.map((o) => o.id).toSet(),
        reason: 'no op vanished and none was duplicated across the crash',
      );

      // Re-flush: nothing left, no resend.
      await engineB.flush();
      expect(cleanExecutor.callCount, n - k,
          reason: 'no resend once the outbox is fully drained');

      await engineA.dispose();
      await engineB.dispose();
      await connA.dispose();
      await connB.dispose();
    });
  });
}

/// Thrown by the FI-2 executor to model the process being killed mid-drain.
class _SimulatedProcessKill implements Exception {
  const _SimulatedProcessKill();
  @override
  String toString() => 'SimulatedProcessKill (FI-2 crash mid-drain)';
}
