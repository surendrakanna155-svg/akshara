import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When true (default), fee structures and concessions require principal approval.
/// Rollback: `--dart-define=FINANCE_APPROVAL_REQUIRED=false`
final financeApprovalRequiredProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment(
    'FINANCE_APPROVAL_REQUIRED',
    defaultValue: true,
  ),
);
