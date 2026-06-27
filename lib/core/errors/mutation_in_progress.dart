import 'api_failure.dart';

/// RT-24 — the re-entry guard for mutation notifiers whose `execute()` returns a
/// NON-nullable value (so they cannot early-return a cached value). A second
/// invocation while the first is still in flight throws this instead of firing a
/// duplicate write; the UI maps it through the standard failure mapper to a clean
/// "already in progress" message.
ApiFailureException mutationInProgressFailure() => ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.unknown,
        message: 'This action is already in progress. Please wait.',
        code: 'MUTATION_IN_PROGRESS',
      ),
    );
