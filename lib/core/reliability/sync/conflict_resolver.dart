import '../model/reliability_enums.dart';

/// What to do when the server reports a conflict, decided by the operation's
/// [ConflictCategory] (refinement R2 — there is NO global last-write-wins).
enum ConflictResolution {
  /// Low-risk data: re-apply the client's write on top of the server's current
  /// version (last-write-wins), carrying the server version as a precondition.
  retryWithServerVersion,

  /// High-risk data (fees, payroll, approvals, published marks, inventory,
  /// finance): never auto-overwrite — park the op and require the user to
  /// explicitly resolve "your copy vs server copy".
  requireUserResolution,
}

class ConflictResolver {
  const ConflictResolver();

  ConflictResolution resolve(ConflictCategory category) {
    switch (category) {
      case ConflictCategory.lowRisk:
        return ConflictResolution.retryWithServerVersion;
      case ConflictCategory.highRisk:
        return ConflictResolution.requireUserResolution;
    }
  }
}
