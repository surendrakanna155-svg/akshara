import 'reliability_enums.dart';

/// The reliability policy for a single operation type.
///
/// Declared once in the [OperationPolicyRegistry]. Enabling draft/queue/retry
/// for a new module is a one-line registry entry — never new offline code
/// (refinement R4).
class OperationPolicy {
  const OperationPolicy({
    required this.kind,
    this.conflictCategory = ConflictCategory.highRisk,
  });

  /// How the operation may be executed (online-only / queueable / draft-only).
  final OperationKind kind;

  /// How conflicts are resolved for this operation's data (R2).
  final ConflictCategory conflictCategory;

  /// The conservative default used for any operation that has not been
  /// explicitly registered: behave like today (online-only) and, if a conflict
  /// ever surfaces, require explicit resolution rather than silently overwrite.
  static const OperationPolicy fallback = OperationPolicy(
    kind: OperationKind.onlineOnly,
    conflictCategory: ConflictCategory.highRisk,
  );

  bool get isQueueable => kind == OperationKind.queueable;
  bool get isDraftOnly => kind == OperationKind.draftOnly;
  bool get isOnlineOnly => kind == OperationKind.onlineOnly;
  bool get requiresExplicitConflictResolution =>
      conflictCategory == ConflictCategory.highRisk;

  @override
  String toString() =>
      'OperationPolicy(kind: $kind, conflict: $conflictCategory)';
}
