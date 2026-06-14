import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/continuity/continuity_models.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import '../sis/sis_audit.dart';
import 'continuity_providers.dart';

class PreviewContinuityMigrationNotifier
    extends AsyncNotifier<ContinuityMigrationPlan?> {
  @override
  FutureOr<ContinuityMigrationPlan?> build() => null;

  Future<ContinuityMigrationPlan?> execute() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageSis(ref);
      return ref.read(continuityRepositoryProvider).previewContinuityMigration(
            query: ref.read(repositoryQueryProvider),
            studentId: ref.read(continuityStudentIdProvider),
            fromClass: ref.read(continuityFromClassProvider),
            fromSection: ref.read(continuityFromSectionProvider),
            toClass: ref.read(continuityToClassProvider),
            toSection: ref.read(continuityToSectionProvider),
            academicYear: ref.read(continuityAcademicYearProvider),
          );
    });
    final value = state.valueOrNull;
    if (value != null) {
      ref.read(continuityPlanIdProvider.notifier).state = value.id;
    }
    return value;
  }
}

final previewContinuityMigrationProvider = AsyncNotifierProvider<
    PreviewContinuityMigrationNotifier, ContinuityMigrationPlan?>(
  PreviewContinuityMigrationNotifier.new,
);

class ExecuteContinuityMigrationNotifier
    extends AsyncNotifier<ContinuityMigrationResult?> {
  @override
  FutureOr<ContinuityMigrationResult?> build() => null;

  Future<ContinuityMigrationResult?> execute({required String planId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageSis(ref);
      try {
        final ownership = await ref
            .read(continuityRepositoryProvider)
            .transferMessageOwnership(
              query: ref.read(repositoryQueryProvider),
              fromTeacherId: 'teacher_source',
              toTeacherId: 'teacher_target',
              studentIds: [ref.read(continuityStudentIdProvider)],
            );
        if (ownership.transferredThreadIds.isNotEmpty) {
          assertManageCommunication(ref);
        }
        return ref.read(continuityRepositoryProvider).executeContinuityMigration(
              query: ref.read(repositoryQueryProvider),
              planId: planId,
            );
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final executeContinuityMigrationProvider = AsyncNotifierProvider<
    ExecuteContinuityMigrationNotifier, ContinuityMigrationResult?>(
  ExecuteContinuityMigrationNotifier.new,
);
