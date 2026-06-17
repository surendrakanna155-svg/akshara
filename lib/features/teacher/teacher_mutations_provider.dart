import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/approvals/adapters/exam_results_approval_adapter.dart';
import '../../core/config/exam_approval_config.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/parent/exams/parent_exams_provider.dart';
import '../../features/student/exams/student_exams_provider.dart';
import 'attendance/teacher_attendance_provider.dart';
import 'exams/exam_models.dart';
import 'exams/teacher_exams_provider.dart';
import 'homework/teacher_homework_provider.dart';
import 'leave/leave_models.dart';
import 'leave/teacher_leave_provider.dart';
import 'messages/message_models.dart';
import 'messages/teacher_messages_provider.dart';
import 'teacher_audit.dart';
import 'teacher_requests.dart';

void _invalidateTeacherReads(
  Ref ref, {
  bool attendanceClasses = false,
  bool attendanceStudents = false,
  bool homework = false,
  bool examMarks = false,
  bool leaveHistory = false,
  bool messages = false,
}) {
  if (attendanceClasses) ref.invalidate(teacherAttendanceClassesFutureProvider);
  if (attendanceStudents) ref.invalidate(teacherAttendanceStudentsFutureProvider);
  if (homework) ref.invalidate(teacherHomeworkFutureProvider);
  if (examMarks) ref.invalidate(teacherExamMarksFutureProvider);
  if (leaveHistory) ref.invalidate(teacherLeaveHistoryFutureProvider);
  if (messages) ref.invalidate(teacherMessageThreadsFutureProvider);
}

Future<T?> _runMutation<T>(
  Ref ref, {
  required Future<T> Function() action,
  required String auditAction,
  required String entityId,
  String Function(T result)? entityIdForAudit,
  Map<String, String> metadata = const {},
  bool invalidateAttendanceClasses = false,
  bool invalidateAttendanceStudents = false,
  bool invalidateHomework = false,
  bool invalidateExamMarks = false,
  bool invalidateStudentExams = false,
  bool invalidateParentExams = false,
  bool invalidateLeaveHistory = false,
  bool invalidateMessages = false,
}) async {
  try {
    final result = await action();
    await recordTeacherAudit(
      ref,
      action: auditAction,
      entityId: entityIdForAudit?.call(result) ?? entityId,
      metadata: metadata,
    );
    _invalidateTeacherReads(
      ref,
      attendanceClasses: invalidateAttendanceClasses,
      attendanceStudents: invalidateAttendanceStudents,
      homework: invalidateHomework,
      examMarks: invalidateExamMarks,
      leaveHistory: invalidateLeaveHistory,
      messages: invalidateMessages,
    );
    return result;
  } catch (error) {
    final failure = apiFailureMapper.fromException(error);
    throw ApiFailureException(failure);
  }
}

class SaveTeacherAttendanceDraftNotifier
    extends AsyncNotifier<TeacherAttendanceDraftResult?> {
  @override
  FutureOr<TeacherAttendanceDraftResult?> build() => null;

  Future<TeacherAttendanceDraftResult?> execute(
    TeacherAttendanceDraftRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        auditAction: 'saveAttendanceDraft',
        entityId: request.classId,
        invalidateAttendanceStudents: true,
        action: () => ref.read(teacherRepositoryProvider).saveAttendanceDraft(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final saveTeacherAttendanceDraftProvider =
    AsyncNotifierProvider<SaveTeacherAttendanceDraftNotifier,
        TeacherAttendanceDraftResult?>(
  SaveTeacherAttendanceDraftNotifier.new,
);

class SubmitTeacherClassAttendanceNotifier
    extends AsyncNotifier<TeacherAttendanceSubmitResult?> {
  @override
  FutureOr<TeacherAttendanceSubmitResult?> build() => null;

  Future<TeacherAttendanceSubmitResult?> execute(
    TeacherAttendanceSubmitRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        auditAction: 'submitClassAttendance',
        entityId: request.classId,
        invalidateAttendanceClasses: true,
        invalidateAttendanceStudents: true,
        action: () => ref.read(teacherRepositoryProvider).submitClassAttendance(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final submitTeacherClassAttendanceProvider =
    AsyncNotifierProvider<SubmitTeacherClassAttendanceNotifier,
        TeacherAttendanceSubmitResult?>(
  SubmitTeacherClassAttendanceNotifier.new,
);

class ReviewTeacherHomeworkNotifier
    extends AsyncNotifier<TeacherHomeworkReviewResult?> {
  @override
  FutureOr<TeacherHomeworkReviewResult?> build() => null;

  Future<TeacherHomeworkReviewResult?> execute(
    TeacherHomeworkReviewRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        auditAction: 'reviewHomeworkSubmission',
        entityId: request.submissionId,
        invalidateHomework: true,
        action: () =>
            ref.read(teacherRepositoryProvider).reviewHomeworkSubmission(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                ),
      );
    });
    return state.valueOrNull;
  }
}

final reviewTeacherHomeworkProvider =
    AsyncNotifierProvider<ReviewTeacherHomeworkNotifier,
        TeacherHomeworkReviewResult?>(
  ReviewTeacherHomeworkNotifier.new,
);

class UpdateTeacherExamMarkNotifier extends AsyncNotifier<ExamMarkEntry?> {
  @override
  FutureOr<ExamMarkEntry?> build() => null;

  Future<ExamMarkEntry?> execute(TeacherExamMarkUpdateRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        auditAction: 'updateExamMark',
        entityId: request.markEntryId,
        invalidateExamMarks: true,
        action: () => ref.read(teacherRepositoryProvider).updateExamMark(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateTeacherExamMarkProvider =
    AsyncNotifierProvider<UpdateTeacherExamMarkNotifier, ExamMarkEntry?>(
  UpdateTeacherExamMarkNotifier.new,
);

class PublishTeacherExamResultsNotifier
    extends AsyncNotifier<TeacherExamPublishResult?> {
  @override
  FutureOr<TeacherExamPublishResult?> build() => null;

  Future<TeacherExamPublishResult?> execute(
    TeacherExamPublishRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (ref.read(examApprovalRequiredProvider)) {
        throw ApiFailureException(
          const ApiFailure(
            type: ApiFailureType.forbidden,
            message:
                'Direct publish is disabled. Submit results for principal approval.',
            code: 'EXAM_APPROVAL_REQUIRED',
          ),
        );
      }
      final rbac = ref.read(rbacServiceProvider);
      if (!rbac.hasPermission(Permission.publishExamResults)) {
        throw ApiFailureException(
          ApiFailure(
            type: ApiFailureType.forbidden,
            message: 'You do not have permission to publish exam results.',
            code: 'RBAC_PUBLISHEXAMRESULTS',
          ),
        );
      }
      final result = await _runMutation(
        ref,
        auditAction: 'publishExamResults',
        entityId: request.examId,
        invalidateExamMarks: true,
        action: () => ref.read(teacherRepositoryProvider).publishExamResults(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
      ref.invalidate(studentExamsFutureProvider);
      ref.invalidate(parentExamsFutureProvider);
      return result;
    });
    return state.valueOrNull;
  }
}

final publishTeacherExamResultsProvider =
    AsyncNotifierProvider<PublishTeacherExamResultsNotifier,
        TeacherExamPublishResult?>(
  PublishTeacherExamResultsNotifier.new,
);

class SubmitTeacherExamResultsForApprovalNotifier
    extends AsyncNotifier<TeacherExamSubmitApprovalResult?> {
  @override
  FutureOr<TeacherExamSubmitApprovalResult?> build() => null;

  Future<TeacherExamSubmitApprovalResult?> execute(
    TeacherExamSubmitApprovalRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final rbac = ref.read(rbacServiceProvider);
      if (!rbac.hasPermission(Permission.submitExamResults)) {
        throw ApiFailureException(
          ApiFailure(
            type: ApiFailureType.forbidden,
            message: 'You do not have permission to submit exam results.',
            code: 'RBAC_SUBMITEXAMRESULTS',
          ),
        );
      }

      final auth = ref.read(authProvider);
      final claims = auth.claims;
      final requesterId = claims?.userId ?? 'teacher_demo';
      final requesterName = auth.displayName ?? 'Teacher';

      final adapter = ExamResultsApprovalAdapter();
      final approval = await adapter.submitForApproval(
        service: ref.read(approvalCenterServiceProvider),
        query: ref.read(repositoryQueryProvider),
        examId: request.examId,
        requesterId: requesterId,
        requesterName: requesterName,
      );

      await recordTeacherAudit(
        ref,
        action: 'submitExamResultsForApproval',
        entityId: request.examId,
        metadata: {'approvalId': approval.id},
      );
      ref.invalidate(teacherExamMarksFutureProvider);
      ref.invalidate(teacherUpcomingExamsFutureProvider);

      return TeacherExamSubmitApprovalResult(
        examId: request.examId,
        approvalId: approval.id,
        title: approval.title,
        statusLabel: approval.status.name,
      );
    });
    return state.valueOrNull;
  }
}

final submitTeacherExamResultsForApprovalProvider =
    AsyncNotifierProvider<SubmitTeacherExamResultsForApprovalNotifier,
        TeacherExamSubmitApprovalResult?>(
  SubmitTeacherExamResultsForApprovalNotifier.new,
);

class SubmitTeacherLeaveNotifier extends AsyncNotifier<TeacherLeaveRequest?> {
  @override
  FutureOr<TeacherLeaveRequest?> build() => null;

  Future<TeacherLeaveRequest?> execute(TeacherLeaveSubmitRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        auditAction: 'submitLeaveRequest',
        entityId: 'leave',
        entityIdForAudit: (leave) => leave.id,
        invalidateLeaveHistory: true,
        action: () => ref.read(teacherRepositoryProvider).submitLeaveRequest(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final submitTeacherLeaveProvider =
    AsyncNotifierProvider<SubmitTeacherLeaveNotifier, TeacherLeaveRequest?>(
  SubmitTeacherLeaveNotifier.new,
);

class SendTeacherMessageNotifier extends AsyncNotifier<MessageThread?> {
  @override
  FutureOr<MessageThread?> build() => null;

  Future<MessageThread?> execute(TeacherMessageSendRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        auditAction: 'sendMessage',
        entityId: request.threadId ?? 'message',
        entityIdForAudit: (thread) => thread.id,
        invalidateMessages: true,
        action: () => ref.read(teacherRepositoryProvider).sendMessage(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final sendTeacherMessageProvider =
    AsyncNotifierProvider<SendTeacherMessageNotifier, MessageThread?>(
  SendTeacherMessageNotifier.new,
);
