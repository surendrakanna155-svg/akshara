import '../model/mutation_envelope.dart';
import '../model/reliability_enums.dart';

/// A snapshot of sync state that drives the Sync Center UI (refinement R3).
class SyncSummary {
  const SyncSummary({
    this.online = true,
    this.pending = 0,
    this.inFlight = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.lastSyncedAt,
    this.history = const <MutationEnvelope>[],
    this.durabilityDegraded = false,
  });

  final bool online;
  final int pending;
  final int inFlight;
  final int conflicts;
  final int failed;
  final DateTime? lastSyncedAt;

  /// REL-8 — true when the durable store fell back to in-memory this session, so
  /// queued work won't survive a restart. Drives a "storage unavailable" warning.
  final bool durabilityDegraded;

  /// Recent operations, newest first (for the detailed history view).
  final List<MutationEnvelope> history;

  /// Items still needing attention (queued, in-flight, conflicted, failed).
  int get outstanding => pending + inFlight + conflicts + failed;

  bool get hasOutstanding => outstanding > 0;
  bool get hasConflicts => conflicts > 0;

  /// Whether the offline/pending banner should be shown at all.
  bool get shouldShowBanner => !online || hasOutstanding || durabilityDegraded;

  factory SyncSummary.fromOperations(
    List<MutationEnvelope> all, {
    required bool online,
    bool durabilityDegraded = false,
  }) {
    int pending = 0, inFlight = 0, conflicts = 0, failed = 0;
    DateTime? lastSynced;
    for (final MutationEnvelope op in all) {
      switch (op.status) {
        case SyncStatus.pending:
          pending++;
        case SyncStatus.inFlight:
          inFlight++;
        case SyncStatus.conflict:
          conflicts++;
        case SyncStatus.failed:
          failed++;
        case SyncStatus.confirmed:
          if (lastSynced == null || op.createdAt.isAfter(lastSynced)) {
            lastSynced = op.createdAt;
          }
      }
    }
    return SyncSummary(
      online: online,
      pending: pending,
      inFlight: inFlight,
      conflicts: conflicts,
      failed: failed,
      lastSyncedAt: lastSynced,
      history: all.take(50).toList(),
      durabilityDegraded: durabilityDegraded,
    );
  }
}
