import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'healthcare_models.dart';
import 'healthcare_providers.dart';

void assertManageHealthcare(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null || !permissions.has(Permission.manageHealthcare)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage healthcare.',
        code: 'RBAC_MANAGE_HEALTHCARE',
      ),
    );
  }
}

void _invalidateHealthcareReads(Ref ref) {
  ref.invalidate(healthcareDashboardProvider);
  ref.invalidate(healthcareIntelligenceProvider);
}

class BookAppointmentNotifier extends AsyncNotifier<Appointment?> {
  @override
  FutureOr<Appointment?> build() => null;

  Future<Appointment?> execute({
    required String patientId,
    required String practitionerId,
    required DateTime scheduledAt,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHealthcare(ref);
      try {
        final result = await ref.read(healthcareRepositoryProvider).bookAppointment(
              query: ref.read(repositoryQueryProvider),
              patientId: patientId,
              practitionerId: practitionerId,
              scheduledAt: scheduledAt,
            );
        _invalidateHealthcareReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final bookAppointmentProvider =
    AsyncNotifierProvider<BookAppointmentNotifier, Appointment?>(BookAppointmentNotifier.new);

class RegisterPatientNotifier extends AsyncNotifier<Patient?> {
  @override
  FutureOr<Patient?> build() => null;

  Future<Patient?> execute({
    required String name,
    required String detail,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHealthcare(ref);
      try {
        final result = await ref.read(healthcareRepositoryProvider).registerPatient(
              query: ref.read(repositoryQueryProvider),
              name: name,
              detail: detail,
            );
        _invalidateHealthcareReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final registerPatientProvider =
    AsyncNotifierProvider<RegisterPatientNotifier, Patient?>(RegisterPatientNotifier.new);
