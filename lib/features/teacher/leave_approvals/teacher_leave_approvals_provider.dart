import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/approvals/approval_models.dart';
import '../../../core/approvals/approval_request_type.dart';
import '../../../core/approvals/approval_status.dart';
import '../../management/approval/approval_center_provider.dart';
import '../communication/teacher_teaching_context_provider.dart';

/// True when [request] is a student-leave for the class teacher's own class.
bool classTeacherOwnsLeave(ApprovalRequest request, String? classTeacherClass) {
  if (request.type != ApprovalRequestType.studentLeave) return false;
  if (classTeacherClass == null || classTeacherClass.isEmpty) return false;
  return '${request.payload['classLabel'] ?? ''}' == classTeacherClass;
}

/// Pending student-leave requests for the class teacher's own class only.
final classTeacherPendingLeavesProvider =
    Provider<List<ApprovalRequest>>((ref) {
  final ctx = ref.watch(resolvedTeacherTeachingContextProvider);
  if (!ctx.isClassTeacher) return const [];
  return ref
      .watch(approvalCenterListProvider)
      .where((r) =>
          r.status == ApprovalStatus.pending &&
          classTeacherOwnsLeave(r, ctx.classTeacherClassLabel))
      .toList(growable: false);
});

Future<void> approveStudentLeaveAsClassTeacher(
  WidgetRef ref,
  ApprovalRequest request,
) async {
  final ctx = ref.read(resolvedTeacherTeachingContextProvider);
  if (!classTeacherOwnsLeave(request, ctx.classTeacherClassLabel)) {
    throw StateError('Only the class teacher of that class may approve.');
  }
  await ref.read(resolveApprovalRequestProvider.notifier).approve(request: request);
}

Future<void> rejectStudentLeaveAsClassTeacher(
  WidgetRef ref,
  ApprovalRequest request,
  String comment,
) async {
  final ctx = ref.read(resolvedTeacherTeachingContextProvider);
  if (!classTeacherOwnsLeave(request, ctx.classTeacherClassLabel)) {
    throw StateError('Only the class teacher of that class may reject.');
  }
  await ref
      .read(resolveApprovalRequestProvider.notifier)
      .reject(request: request, comment: comment);
}
