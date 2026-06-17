import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When true (default), leave requests route through Principal Approval Center.
/// Rollback: `--dart-define=LEAVE_AUTO_APPROVE=true`
final leaveApprovalRequiredProvider = Provider<bool>(
  (ref) => !const bool.fromEnvironment(
    'LEAVE_AUTO_APPROVE',
    defaultValue: false,
  ),
);
