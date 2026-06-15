import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/interfaces/communication_repository.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'school_completion_models.dart';
import 'school_completion_providers.dart';

void assertManageAcademicTimetable(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null ||
      !permissions.has(Permission.manageAcademicTimetable)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage academic timetable.',
        code: 'RBAC_MANAGE_ACADEMIC_TIMETABLE',
      ),
    );
  }
}

class AssignSubstituteNotifier
    extends AsyncNotifier<SubstituteAssignmentResult?> {
  @override
  FutureOr<SubstituteAssignmentResult?> build() => null;

  Future<SubstituteAssignmentResult?> execute(
      AssignSubstituteRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageAcademicTimetable(ref);
      try {
        final query = ref.read(repositoryQueryProvider);
        final result =
            await ref.read(schoolCompletionRepositoryProvider).assignSubstitute(
                  query: query,
                  request: request,
                );
        if (request.notifySubstituteTeacher ||
            request.notifyClassIncharge ||
            request.notifyStudents) {
          final audience = <String>[
            if (request.notifySubstituteTeacher) 'substitute_teacher',
            if (request.notifyClassIncharge) 'class_incharge',
            if (request.notifyStudents) 'students',
          ].join(', ');
          try {
            await ref.read(communicationRepositoryProvider).sendBroadcast(
                  query: query,
                  request: BroadcastRequest(
                    audience: audience,
                    title: 'Substitute teacher assigned',
                    body:
                        'Slot ${request.slotId} has been updated with substitute teacher ${request.substituteTeacherId}.',
                  ),
                );
          } catch (_) {
            // Notification delivery is best-effort in QA automation.
          }
        }
        ref.invalidate(substituteCoverageProvider);
        ref.invalidate(timetableOptimizationProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final assignSubstituteProvider = AsyncNotifierProvider<AssignSubstituteNotifier,
    SubstituteAssignmentResult?>(
  AssignSubstituteNotifier.new,
);

class ReassignTeacherNotifier
    extends AsyncNotifier<TeacherReassignmentResult?> {
  @override
  FutureOr<TeacherReassignmentResult?> build() => null;

  Future<TeacherReassignmentResult?> execute(
      ReassignTeacherRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageAcademicTimetable(ref);
      try {
        final query = ref.read(repositoryQueryProvider);
        final result =
            await ref.read(schoolCompletionRepositoryProvider).reassignTeacher(
                  query: query,
                  request: request,
                );
        if (request.notifySourceTeacher ||
            request.notifyTargetTeacher ||
            request.notifyStudents) {
          final audience = <String>[
            if (request.notifySourceTeacher) 'source_teacher',
            if (request.notifyTargetTeacher) 'target_teacher',
            if (request.notifyStudents) 'students',
          ].join(', ');
          await ref.read(communicationRepositoryProvider).sendBroadcast(
                query: query,
                request: BroadcastRequest(
                  audience: audience,
                  title: 'Teacher timetable reassigned',
                  body:
                      'Teacher ${request.sourceTeacherId} periods were reassigned to ${request.targetTeacherId}.',
                ),
              );
        }
        ref.invalidate(teacherReassignmentOptionsProvider);
        ref.invalidate(timetableOptimizationProvider);
        ref.invalidate(substituteCoverageProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final reassignTeacherProvider =
    AsyncNotifierProvider<ReassignTeacherNotifier, TeacherReassignmentResult?>(
  ReassignTeacherNotifier.new,
);

class ApplyTimetableOptimizationNotifier
    extends AsyncNotifier<ApplyTimetableOptimizationResult?> {
  @override
  FutureOr<ApplyTimetableOptimizationResult?> build() => null;

  Future<ApplyTimetableOptimizationResult?> execute(
      ApplyTimetableOptimizationRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageAcademicTimetable(ref);
      try {
        final query = ref.read(repositoryQueryProvider);
        final result = await ref
            .read(schoolCompletionRepositoryProvider)
            .applyTimetableOptimization(
              query: query,
              academicYearId: request.academicYearId,
              recommendationIds: request.recommendationIds,
              applyAll: request.applyAll,
            );
        ref.invalidate(timetableOptimizationProvider(request.academicYearId));
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final applyTimetableOptimizationProvider = AsyncNotifierProvider<
    ApplyTimetableOptimizationNotifier, ApplyTimetableOptimizationResult?>(
  ApplyTimetableOptimizationNotifier.new,
);
