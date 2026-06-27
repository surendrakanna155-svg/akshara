import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/policy/operation_policy_registry.dart';
import 'package:akshara_erp/core/reliability/reliable_writer.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:akshara_erp/core/reliability/store/reliability_store.dart';
import 'package:akshara_erp/core/reliability/sync/backoff.dart';
import 'package:akshara_erp/core/reliability/sync/mutation_executor.dart';
import 'package:akshara_erp/core/reliability/sync/mutation_gateway.dart';
import 'package:akshara_erp/core/reliability/sync/sync_engine.dart';
import 'package:akshara_erp/core/repositories/api/teacher/remote/teacher_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/teacher_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/reliability/reliability_fakes.dart';

/// Airplane-mode integration (design §13): a teacher submits attendance offline,
/// the write is queued (optimistic "Pending sync"), survives to the next session,
/// then flushes EXACTLY ONCE on reconnect — no duplicate, no lost work.
/// Closes QA-X-001 / -002.
void main() {
  const RepositoryQuery query = RepositoryQuery(
    tenantId: 'tenant-1',
    schoolId: 'school-1',
  );

  TeacherAttendanceSubmitRequest request() => const TeacherAttendanceSubmitRequest(
        classId: 'class-8a',
        entries: <TeacherAttendanceMarkEntry>[
          TeacherAttendanceMarkEntry(
              studentId: 's1', mark: StudentAttendanceMark.present),
          TeacherAttendanceMarkEntry(
              studentId: 's2', mark: StudentAttendanceMark.absent),
          TeacherAttendanceMarkEntry(
              studentId: 's3', mark: StudentAttendanceMark.present),
        ],
      );

  test('offline submit queues an optimistic Pending-sync result, no send',
      () async {
    final ReliabilityStore store = InMemoryReliabilityStore();
    final FakeConnectivity connectivity = FakeConnectivity(online: false);
    final FakeExecutor executor = FakeExecutor((req, _) => ok());
    final gateway = MutationGateway(
      registry: OperationPolicyRegistry.withDefaults(),
      executor: executor,
      store: store,
      connectivity: connectivity,
    );
    final datasource = TeacherRemoteDataSource(
      Dio(),
      reliableWriter: ReliableWriter(gateway),
    );

    final result =
        await datasource.submitClassAttendance(query: query, request: request());

    // Optimistic, explicitly non-final result the UI can show immediately.
    expect(result.raw['submittedAtLabel'], 'Pending sync');
    expect(result.raw['presentCount'], 2);
    expect(result.raw['absentCount'], 1);
    // Nothing was sent while offline …
    expect(executor.callCount, 0);
    // … but the write is durably queued.
    final pending = await store.pendingOperations();
    expect(pending, hasLength(1));
    expect(pending.single.request.type, OperationTypes.submitAttendance);
    expect(pending.single.status, SyncStatus.pending);

    await connectivity.dispose();
  });

  test('queued write survives "relaunch" and flushes exactly once on reconnect',
      () async {
    // Session 1: offline submit enqueues the write.
    final ReliabilityStore store = InMemoryReliabilityStore();
    final FakeConnectivity connectivity = FakeConnectivity(online: false);
    final FakeExecutor executor = FakeExecutor(
      (req, _) => ok(<String, dynamic>{'classId': 'class-8a', 'serverConfirmed': true}),
    );
    final gateway = MutationGateway(
      registry: OperationPolicyRegistry.withDefaults(),
      executor: executor,
      store: store,
      connectivity: connectivity,
    );
    final datasource = TeacherRemoteDataSource(
      Dio(),
      reliableWriter: ReliableWriter(gateway),
    );
    await datasource.submitClassAttendance(query: query, request: request());
    final String queuedOpId = (await store.pendingOperations()).single.id;

    // Session 2 ("relaunch"): a fresh SyncEngine reads the SAME durable store —
    // the queued op is still there.
    final engine = SyncEngine(
      store: store,
      executor: executor,
      connectivity: connectivity,
      registry: OperationPolicyRegistry.withDefaults(),
    );
    expect((await store.pendingOperations()).single.id, queuedOpId,
        reason: 'the queued write persisted across the relaunch');

    // Reconnect → drain.
    connectivity.setOnline(true);
    await engine.flush();

    // Sent EXACTLY once, then confirmed — exactly-once, no duplicate.
    expect(executor.callCount, 1);
    expect(executor.sent.single.idempotencyKey, queuedOpId,
        reason: 'replayed with its stable idempotency key');
    final op = await store.getOperation(queuedOpId);
    expect(op!.status, SyncStatus.confirmed);
    expect(await store.pendingOperations(), isEmpty);

    // A second flush must NOT re-send (no double submission).
    await engine.flush();
    expect(executor.callCount, 1);

    await engine.dispose();
    await connectivity.dispose();
  });

  test('lost-ack retry replays via idempotency → confirmed, never duplicated',
      () async {
    final ReliabilityStore store = InMemoryReliabilityStore();
    final FakeConnectivity connectivity = FakeConnectivity(online: false);
    // First send: the server applied the write but the 2xx ack was lost
    // (network drop) → the client retries and the backend replays the original
    // response as a 409 IDEMPOTENCY_CONFLICT, which the platform treats as
    // confirmed (exactly-once).
    final FakeExecutor executor = FakeExecutor((req, callIndex) {
      if (callIndex == 0) throw const NetworkUnavailableException('drop');
      return idempotencyReplay(<String, dynamic>{'classId': 'class-8a'});
    });
    final gateway = MutationGateway(
      registry: OperationPolicyRegistry.withDefaults(),
      executor: executor,
      store: store,
      connectivity: connectivity,
    );
    final datasource = TeacherRemoteDataSource(
      Dio(),
      reliableWriter: ReliableWriter(gateway),
    );
    await datasource.submitClassAttendance(query: query, request: request());

    final engine = SyncEngine(
      store: store,
      executor: executor,
      connectivity: connectivity,
      registry: OperationPolicyRegistry.withDefaults(),
      backoff: const Backoff(base: Duration.zero), // immediate retry in test
    );
    connectivity.setOnline(true);
    await engine.flush(); // network drop → stays pending
    await engine.flush(); // retry → idempotency replay → confirmed

    final ops = await store.allOperations();
    expect(ops.single.status, SyncStatus.confirmed);

    await engine.dispose();
    await connectivity.dispose();
  });
}
