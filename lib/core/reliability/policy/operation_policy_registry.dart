import '../model/operation_policy.dart';
import '../model/reliability_enums.dart';

/// The single, centralized place that declares the reliability behaviour of
/// every write in the app (refinement R4).
///
/// Because every write passes through the [MutationGateway], turning on
/// draft/queue/retry for a module is a one-line registry entry here — there is
/// no per-screen offline code anywhere. Unregistered operations fall back to
/// the conservative [OperationPolicy.fallback] (online-only), so adding the
/// platform changes no behaviour until an operation is opted in.
class OperationPolicyRegistry {
  OperationPolicyRegistry([Map<String, OperationPolicy>? policies])
      : _policies = <String, OperationPolicy>{...?policies};

  final Map<String, OperationPolicy> _policies;

  /// Resolve the policy for an operation [type]; never null.
  OperationPolicy policyFor(String type) =>
      _policies[type] ?? OperationPolicy.fallback;

  bool isRegistered(String type) => _policies.containsKey(type);

  /// Register or override the policy for an operation type.
  void register(String type, OperationPolicy policy) {
    _policies[type] = policy;
  }

  Iterable<String> get registeredTypes => _policies.keys;

  /// The Phase-0b seed: the pilot-critical writes that must survive
  /// interruption / poor connectivity. Everything else inherits the safe
  /// online-only fallback until explicitly opted in (Phase 0c).
  factory OperationPolicyRegistry.withDefaults() {
    return OperationPolicyRegistry(<String, OperationPolicy>{
      // Single-owner, low-risk data-entry — queue + last-write-wins.
      OperationTypes.markAttendance: const OperationPolicy(
        kind: OperationKind.queueable,
        conflictCategory: ConflictCategory.lowRisk,
      ),
      OperationTypes.submitAttendance: const OperationPolicy(
        kind: OperationKind.queueable,
        conflictCategory: ConflictCategory.lowRisk,
      ),
      OperationTypes.saveExamMarksDraft: const OperationPolicy(
        kind: OperationKind.queueable,
        conflictCategory: ConflictCategory.lowRisk,
      ),
      OperationTypes.applyLeave: const OperationPolicy(
        kind: OperationKind.queueable,
        conflictCategory: ConflictCategory.lowRisk,
      ),
      // Staff GPS+face check-in/out (attendance-auth, audit R1): ALWAYS online.
      // The server enforces a per-event location-freshness window, so a queued
      // check-in drained later is GUARANTEED-stale — an offline optimistic
      // "recorded" would be a lie. Per the FINAL design
      // (docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §4): a fresh fix per event;
      // the only offline path is the audited manual attendance request.
      OperationTypes.markStaffAttendance:
          const OperationPolicy(kind: OperationKind.onlineOnly),
      // High-risk record-of-truth — queue but require explicit conflict
      // resolution and never finalise (e.g. a receipt) until confirmed (R1/R2).
      OperationTypes.collectFee: const OperationPolicy(
        kind: OperationKind.queueable,
        conflictCategory: ConflictCategory.highRisk,
      ),
      OperationTypes.submitExamMarks: const OperationPolicy(
        kind: OperationKind.queueable,
        conflictCategory: ConflictCategory.highRisk,
      ),
      // Always online — an offline optimistic result would be unsafe.
      OperationTypes.login: const OperationPolicy(kind: OperationKind.onlineOnly),
      OperationTypes.gatewayPayment:
          const OperationPolicy(kind: OperationKind.onlineOnly),
      OperationTypes.aiGenerate:
          const OperationPolicy(kind: OperationKind.onlineOnly),
    });
  }
}

/// Canonical operation-type keys. New modules add a constant here and one
/// registry entry — never new offline code.
abstract final class OperationTypes {
  static const String markAttendance = 'attendance.mark';
  static const String submitAttendance = 'attendance.submit';
  static const String saveExamMarksDraft = 'exam.marks.saveDraft';
  static const String submitExamMarks = 'exam.marks.submit';
  static const String applyLeave = 'leave.apply';
  static const String markStaffAttendance = 'staffAttendance.check';
  static const String collectFee = 'finance.collectFee';
  static const String login = 'auth.login';
  static const String gatewayPayment = 'finance.gatewayPayment';
  static const String aiGenerate = 'ai.generate';
}
