import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../registry/sis_registry_provider.dart';
import '../sis_audit.dart';
import 'academic_operations_models.dart';
import 'academic_operations_providers.dart';

void _invalidateAcademicOperationReads(Ref ref) {
  ref.invalidate(suggestedMappingsFutureProvider);
  ref.invalidate(promotionPreviewFutureProvider);
  ref.invalidate(reshufflePreviewFutureProvider);
  ref.invalidate(sectionBalancePreviewFutureProvider);
  ref.invalidate(quarterlyReshufflePreviewFutureProvider);
  ref.invalidate(performanceBalancePreviewFutureProvider);
  ref.invalidate(sisStudentsFutureProvider);
}

class PreviewYearTransitionNotifier extends AsyncNotifier<AcademicTransitionJob?> {
  @override
  FutureOr<AcademicTransitionJob?> build() => null;

  Future<AcademicTransitionJob?> execute({
    required String sourceYearId,
    required String targetYearId,
    required List<ClassMappingRule> mappings,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageSis(ref);
      return ref.read(academicOperationsRepositoryProvider).previewYearTransition(
            query: ref.read(repositoryQueryProvider),
            sourceYearId: sourceYearId,
            targetYearId: targetYearId,
            mappings: mappings,
          );
    });
    final value = state.valueOrNull;
    if (value != null) {
      ref.read(promotionJobIdProvider.notifier).state = value.id;
      _invalidateAcademicOperationReads(ref);
    }
    return value;
  }
}

final previewYearTransitionProvider = AsyncNotifierProvider<
    PreviewYearTransitionNotifier, AcademicTransitionJob?>(
  PreviewYearTransitionNotifier.new,
);

class ExecuteYearTransitionNotifier
    extends AsyncNotifier<AcademicTransitionExecutionReport?> {
  @override
  FutureOr<AcademicTransitionExecutionReport?> build() => null;

  Future<AcademicTransitionExecutionReport?> execute({required String jobId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageSis(ref);
      return ref.read(academicOperationsRepositoryProvider).executeYearTransition(
            query: ref.read(repositoryQueryProvider),
            jobId: jobId,
          );
    });
    _invalidateAcademicOperationReads(ref);
    return state.valueOrNull;
  }
}

final executeYearTransitionProvider = AsyncNotifierProvider<
    ExecuteYearTransitionNotifier, AcademicTransitionExecutionReport?>(
  ExecuteYearTransitionNotifier.new,
);

class ExecuteOperationPlanNotifier
    extends AsyncNotifier<AcademicOperationExecutionReport?> {
  @override
  FutureOr<AcademicOperationExecutionReport?> build() => null;

  Future<AcademicOperationExecutionReport?> executeReshuffle(
      {required String planId}) async {
    return _run(() => ref
        .read(academicOperationsRepositoryProvider)
        .executeStudentReshuffle(
          query: ref.read(repositoryQueryProvider),
          planId: planId,
        ));
  }

  Future<AcademicOperationExecutionReport?> executeSectionBalance({
    required String planId,
  }) async {
    return _run(() => ref
        .read(academicOperationsRepositoryProvider)
        .executeSectionBalance(
          query: ref.read(repositoryQueryProvider),
          planId: planId,
        ));
  }

  Future<AcademicOperationExecutionReport?> executeQuarterly({
    required String planId,
  }) async {
    return _run(() => ref
        .read(academicOperationsRepositoryProvider)
        .executeQuarterlyReshuffle(
          query: ref.read(repositoryQueryProvider),
          planId: planId,
        ));
  }

  Future<AcademicOperationExecutionReport?> executePerformance({
    required String planId,
  }) async {
    return _run(() => ref
        .read(academicOperationsRepositoryProvider)
        .executePerformanceBalance(
          query: ref.read(repositoryQueryProvider),
          planId: planId,
        ));
  }

  Future<AcademicOperationExecutionReport?> _run(
    Future<AcademicOperationExecutionReport> Function() action,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageSis(ref);
      try {
        return await action();
      } catch (error) {
        final failure = apiFailureMapper.fromException(error);
        throw ApiFailureException(failure);
      }
    });
    _invalidateAcademicOperationReads(ref);
    return state.valueOrNull;
  }
}

final executeOperationPlanProvider = AsyncNotifierProvider<
    ExecuteOperationPlanNotifier, AcademicOperationExecutionReport?>(
  ExecuteOperationPlanNotifier.new,
);
