import '../errors/api_failure.dart';
import 'model/mutation_outcome.dart';

/// The data a reliability-routed datasource parses into its typed response DTO,
/// plus whether the write was queued offline (optimistic, not yet server-backed).
///
/// Returned by [resolveWriteOutcome]. For a confirmed write [data] is the
/// authoritative server row; for a [pending] write it is the optimistic body the
/// caller supplied so the UI can update instantly (the global Sync Center then
/// surfaces it until the server confirms).
class ResolvedWrite {
  const ResolvedWrite({required this.data, required this.pending});

  final Map<String, dynamic> data;
  final bool pending;
}

/// Resolves a queueable-write [MutationOutcome] (from [ReliableWriter.runWrite])
/// into the value a typed datasource returns.
///
/// - **confirmed** → the server row (`outcome.data`).
/// - **pending** → the [optimistic] projection (the write is safely queued and
///   will replay exactly-once on reconnect).
/// - **conflict / failed** → throws an [ApiFailureException] so the existing
///   notifier error path (`apiFailureMapper.fromException`) surfaces it exactly
///   as a direct HTTP failure would — no per-screen error handling changes.
ResolvedWrite resolveWriteOutcome(
  MutationOutcome outcome, {
  required Map<String, dynamic> Function() optimistic,
}) {
  if (outcome.isConfirmed) {
    return ResolvedWrite(data: outcome.data ?? const <String, dynamic>{}, pending: false);
  }
  if (outcome.isPending) {
    return ResolvedWrite(data: optimistic(), pending: true);
  }
  throw ApiFailureException(_failureFor(outcome));
}

ApiFailure _failureFor(MutationOutcome outcome) {
  if (outcome.isConflict) {
    return ApiFailure(
      type: ApiFailureType.unknown,
      message: outcome.errorMessage ??
          'This record was changed somewhere else. Open the Sync Center to review and resolve it.',
      code: outcome.errorCode ?? 'CONFLICT',
      statusCode: 409,
    );
  }
  final String? code = outcome.errorCode;
  final ApiFailureType type;
  switch (code) {
    case 'FORBIDDEN':
      type = ApiFailureType.forbidden;
    case 'UNAUTHORIZED':
      type = ApiFailureType.unauthorized;
    case 'OFFLINE':
      type = ApiFailureType.notConnected;
    default:
      type = ApiFailureType.unknown;
  }
  return ApiFailure(
    type: type,
    message: outcome.errorMessage ?? 'Something went wrong. Please try again.',
    code: code ?? 'WRITE_FAILED',
  );
}
