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
  if (permissions == null || !permissions.has(Permission.manageAcademicTimetable)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage academic timetable.',
        code: 'RBAC_MANAGE_ACADEMIC_TIMETABLE',
      ),
    );
  }
}

class AssignSubstituteNotifier extends AsyncNotifier<SubstituteAssignmentResult?> {
  @override
  FutureOr<SubstituteAssignmentResult?> build() => null;

  Future<SubstituteAssignmentResult?> execute(AssignSubstituteRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageAcademicTimetable(ref);
      try {
        final query = ref.read(repositoryQueryProvider);
        final result = await ref.read(schoolCompletionRepositoryProvider).assignSubstitute(
              query: query,
              request: request,
            );
        if (request.notifySubstituteTeacher || request.notifyClassIncharge || request.notifyStudents) {
          final audience = <String>[
            if (request.notifySubstituteTeacher) 'substitute_teacher',
            if (request.notifyClassIncharge) 'class_incharge',
            if (request.notifyStudents) 'students',
          ].join(', ');
          await ref.read(communicationRepositoryProvider).sendBroadcast(
                query: query,
                request: BroadcastRequest(
                  audience: audience,
                  title: 'Substitute teacher assigned',
                  body:
                      'Slot ${request.slotId} has been updated with substitute teacher ${request.substituteTeacherId}.',
                ),
              );
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

final assignSubstituteProvider =
    AsyncNotifierProvider<AssignSubstituteNotifier, SubstituteAssignmentResult?>(
  AssignSubstituteNotifier.new,
);
