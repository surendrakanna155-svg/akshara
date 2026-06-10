import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/academic/academic_catalog_mutation.dart';
import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import 'dashboard/sis_dashboard_provider.dart';
import 'integration/sis_admissions_integration_provider.dart';
import 'profile/sis_profile_provider.dart';
import 'registry/sis_registry_provider.dart';
import 'sis_audit.dart';
import 'sis_models.dart';
import 'sis_requests.dart';

void _invalidateSisReads(
  Ref ref, {
  bool students = false,
  bool dashboard = false,
  bool conversion = false,
  String? studentId,
}) {
  if (students) ref.invalidate(sisStudentsFutureProvider);
  if (dashboard) ref.invalidate(sisDashboardFutureProvider);
  if (conversion) ref.invalidate(sisAdmissionsConversionFutureProvider);
  if (studentId != null) {
    ref.invalidate(sisStudentProfileFutureProvider(studentId));
  }
}

Future<T?> _runMutation<T>(
  Ref ref, {
  required Future<T> Function() action,
  bool invalidateStudents = false,
  bool invalidateDashboard = false,
  bool invalidateConversion = false,
  String? invalidateStudentId,
  void Function()? assertPermission,
}) async {
  assertPermission?.call();
  try {
    final result = await action();
    _invalidateSisReads(
      ref,
      students: invalidateStudents,
      dashboard: invalidateDashboard,
      conversion: invalidateConversion,
      studentId: invalidateStudentId,
    );
    return result;
  } catch (error) {
    final failure = apiFailureMapper.fromException(error);
    throw ApiFailureException(failure);
  }
}

class CreateStudentNotifier extends AsyncNotifier<SisStudent?> {
  @override
  FutureOr<SisStudent?> build() => null;

  Future<SisStudent?> execute(CreateStudentRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudents: true,
        invalidateDashboard: true,
        action: () => ref.read(sisRepositoryProvider).createStudent(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final createStudentProvider =
    AsyncNotifierProvider<CreateStudentNotifier, SisStudent?>(
  CreateStudentNotifier.new,
);

class UpdateStudentNotifier extends AsyncNotifier<SisStudent?> {
  @override
  FutureOr<SisStudent?> build() => null;

  Future<SisStudent?> execute({
    required String studentId,
    required UpdateStudentRequest request,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudents: true,
        invalidateStudentId: studentId,
        action: () => ref.read(sisRepositoryProvider).updateStudent(
              query: ref.read(repositoryQueryProvider),
              studentId: studentId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateStudentProvider =
    AsyncNotifierProvider<UpdateStudentNotifier, SisStudent?>(
  UpdateStudentNotifier.new,
);

class UpdateStudentStatusNotifier extends AsyncNotifier<SisStudent?> {
  @override
  FutureOr<SisStudent?> build() => null;

  Future<SisStudent?> execute({
    required String studentId,
    required UpdateStudentStatusRequest request,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudents: true,
        invalidateStudentId: studentId,
        action: () => ref.read(sisRepositoryProvider).updateStudentStatus(
              query: ref.read(repositoryQueryProvider),
              studentId: studentId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateStudentStatusProvider =
    AsyncNotifierProvider<UpdateStudentStatusNotifier, SisStudent?>(
  UpdateStudentStatusNotifier.new,
);

class AssignAcademicAssignmentNotifier extends AsyncNotifier<SisStudent?> {
  @override
  FutureOr<SisStudent?> build() => null;

  Future<SisStudent?> execute(AcademicAssignmentRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final catalog = ref.read(academicCatalogProvider);
      final enriched = catalog == null
          ? request
          : enrichAcademicAssignmentRequest(request, catalog);
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudents: true,
        invalidateStudentId: request.studentId,
        action: () => ref.read(sisRepositoryProvider).assignAcademicAssignment(
              query: ref.read(repositoryQueryProvider),
              request: enriched,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final assignAcademicAssignmentProvider =
    AsyncNotifierProvider<AssignAcademicAssignmentNotifier, SisStudent?>(
  AssignAcademicAssignmentNotifier.new,
);

class ConvertAdmissionsEnrollmentNotifier
    extends AsyncNotifier<SisConversionPreview?> {
  @override
  FutureOr<SisConversionPreview?> build() => null;

  Future<SisConversionPreview?> execute(
    AdmissionsConversionRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final catalog = ref.read(academicCatalogProvider);
      final enriched = catalog == null
          ? request
          : enrichAdmissionsConversionRequest(request, catalog);
      return _runMutation(
        ref,
        assertPermission: () => assertManageSis(ref),
        invalidateStudents: true,
        invalidateDashboard: true,
        invalidateConversion: true,
        action: () =>
            ref.read(sisRepositoryProvider).convertAdmissionsEnrollment(
                  query: ref.read(repositoryQueryProvider),
                  request: enriched,
                ),
      );
    });
    return state.valueOrNull;
  }
}

final convertAdmissionsEnrollmentProvider =
    AsyncNotifierProvider<ConvertAdmissionsEnrollmentNotifier,
        SisConversionPreview?>(
  ConvertAdmissionsEnrollmentNotifier.new,
);
