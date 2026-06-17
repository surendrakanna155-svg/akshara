import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When true (default), teachers must submit exam results for principal approval
/// before student/parent apps receive published marks.
///
/// Rollback: `--dart-define=EXAM_APPROVAL_REQUIRED=false`
final examApprovalRequiredProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment(
    'EXAM_APPROVAL_REQUIRED',
    defaultValue: true,
  ),
);
