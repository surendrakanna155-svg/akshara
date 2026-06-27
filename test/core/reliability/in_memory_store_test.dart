import 'package:akshara_erp/core/reliability/model/draft_record.dart';
import 'package:akshara_erp/core/reliability/model/mutation_envelope.dart';
import 'package:akshara_erp/core/reliability/model/mutation_request.dart';
import 'package:akshara_erp/core/reliability/model/reliability_enums.dart';
import 'package:akshara_erp/core/reliability/store/in_memory_reliability_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryReliabilityStore store;
  final DateTime t0 = DateTime.utc(2026, 6, 27, 9);

  setUp(() => store = InMemoryReliabilityStore());

  MutationEnvelope env(String id, SyncStatus status, DateTime created) {
    return MutationEnvelope(
      request: MutationRequest(
        type: 't', method: 'POST', path: '/x', idempotencyKey: id),
      status: status,
      createdAt: created,
    );
  }

  test('pendingOperations returns only pending, oldest first', () async {
    await store.putOperation(
        env('b', SyncStatus.pending, t0.add(const Duration(minutes: 2))));
    await store.putOperation(env('a', SyncStatus.pending, t0));
    await store.putOperation(env('c', SyncStatus.confirmed, t0));

    final pending = await store.pendingOperations();
    expect(pending.map((e) => e.id).toList(), <String>['a', 'b']);
  });

  test('round-trips an operation via JSON', () async {
    final e = env('a', SyncStatus.pending, t0)
        .copyWith(attempts: 2, lastError: 'X');
    final restored = MutationEnvelope.fromJson(e.toJson());
    expect(restored.id, 'a');
    expect(restored.attempts, 2);
    expect(restored.lastError, 'X');
    expect(restored.status, SyncStatus.pending);
  });

  test('drafts are scoped per user and round-trip via JSON', () async {
    await store.putDraft(DraftRecord(
        key: 'k1', userId: 'u1', json: const {'a': 1}, updatedAt: t0));
    await store.putDraft(DraftRecord(
        key: 'k2', userId: 'u2', json: const {'b': 2}, updatedAt: t0));

    expect((await store.draftsForUser('u1')).single.key, 'k1');
    final d = await store.getDraft('k1');
    final restored = DraftRecord.fromJson(d!.toJson());
    expect(restored.json, <String, dynamic>{'a': 1});
  });

  test('clear wipes operations and drafts (logout safety)', () async {
    await store.putOperation(env('a', SyncStatus.pending, t0));
    await store.putDraft(DraftRecord(
        key: 'k1', userId: 'u1', json: const {}, updatedAt: t0));
    await store.clear();
    expect(await store.allOperations(), isEmpty);
    expect(await store.draftsForUser('u1'), isEmpty);
  });
}
