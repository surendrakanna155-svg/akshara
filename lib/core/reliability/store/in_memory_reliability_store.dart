import '../model/draft_record.dart';
import '../model/mutation_envelope.dart';
import '../model/reliability_enums.dart';
import 'reliability_store.dart';

/// In-memory [ReliabilityStore] used by tests and as a safe default before the
/// encrypted SQLite store is wired in. Not durable across restarts.
class InMemoryReliabilityStore implements ReliabilityStore {
  final Map<String, MutationEnvelope> _ops = <String, MutationEnvelope>{};
  final Map<String, DraftRecord> _drafts = <String, DraftRecord>{};

  @override
  Future<void> putOperation(MutationEnvelope op) async {
    _ops[op.id] = op;
  }

  @override
  Future<void> deleteOperation(String id) async {
    _ops.remove(id);
  }

  @override
  Future<MutationEnvelope?> getOperation(String id) async => _ops[id];

  @override
  Future<List<MutationEnvelope>> pendingOperations() async {
    final List<MutationEnvelope> pending = _ops.values
        .where((MutationEnvelope o) => o.status == SyncStatus.pending)
        .toList()
      ..sort((MutationEnvelope a, MutationEnvelope b) =>
          a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  @override
  Future<List<MutationEnvelope>> allOperations() async {
    final List<MutationEnvelope> all = _ops.values.toList()
      ..sort((MutationEnvelope a, MutationEnvelope b) =>
          b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<void> putDraft(DraftRecord draft) async {
    _drafts[draft.key] = draft;
  }

  @override
  Future<DraftRecord?> getDraft(String key) async => _drafts[key];

  @override
  Future<void> deleteDraft(String key) async {
    _drafts.remove(key);
  }

  @override
  Future<List<DraftRecord>> draftsForUser(String userId) async {
    final List<DraftRecord> drafts = _drafts.values
        .where((DraftRecord d) => d.userId == userId)
        .toList()
      ..sort((DraftRecord a, DraftRecord b) =>
          b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  @override
  Future<void> clear() async {
    _ops.clear();
    _drafts.clear();
  }
}
