import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import 'homework/homework_models.dart';
import 'homework/student_homework_provider.dart';
import 'student_audit.dart';
import 'student_requests.dart';

Future<T?> _runMutation<T>(
  Ref ref, {
  required Future<T> Function() action,
  required String auditAction,
  required String entityId,
  String Function(T result)? entityIdForAudit,
  Map<String, String> metadata = const {},
  void Function()? invalidateReads,
}) async {
  try {
    final result = await action();
    await recordStudentAudit(
      ref,
      action: auditAction,
      entityId: entityIdForAudit?.call(result) ?? entityId,
      metadata: metadata,
    );
    invalidateReads?.call();
    return result;
  } catch (error) {
    final failure = apiFailureMapper.fromException(error);
    throw ApiFailureException(failure);
  }
}

class SubmitStudentHomeworkNotifier extends AsyncNotifier<StudentHomeworkItem?> {
  @override
  FutureOr<StudentHomeworkItem?> build() => null;

  Future<StudentHomeworkItem?> execute(StudentHomeworkSubmitRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        auditAction: 'submitHomework',
        entityId: request.homeworkId,
        entityIdForAudit: (item) => item.id,
        invalidateReads: () => ref.invalidate(studentHomeworkFutureProvider),
        action: () => ref.read(studentRepositoryProvider).submitHomework(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final submitStudentHomeworkProvider =
    AsyncNotifierProvider<SubmitStudentHomeworkNotifier, StudentHomeworkItem?>(
  SubmitStudentHomeworkNotifier.new,
);
