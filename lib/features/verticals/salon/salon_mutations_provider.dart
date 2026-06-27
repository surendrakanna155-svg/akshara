import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'salon_models.dart';
import 'salon_providers.dart';

void assertManageSalon(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null || !permissions.has(Permission.manageSalonBusiness)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage salon.',
        code: 'RBAC_MANAGE_SALON',
      ),
    );
  }
}

void _invalidateSalonReads(Ref ref) {
  ref.invalidate(salonDashboardProvider);
  ref.invalidate(salonIntelligenceProvider);
}

class BookSalonAppointmentNotifier extends AsyncNotifier<SalonAppointment?> {
  @override
  FutureOr<SalonAppointment?> build() => null;

  Future<SalonAppointment?> execute({
    required String customerId,
    required String serviceId,
    required DateTime scheduledAt,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageSalon(ref);
      try {
        final result = await ref.read(salonRepositoryProvider).bookSalonAppointment(
              query: ref.read(repositoryQueryProvider),
              customerId: customerId,
              serviceId: serviceId,
              scheduledAt: scheduledAt,
            );
        _invalidateSalonReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final bookSalonAppointmentProvider =
    AsyncNotifierProvider<BookSalonAppointmentNotifier, SalonAppointment?>(BookSalonAppointmentNotifier.new);

class RegisterSalonCustomerNotifier extends AsyncNotifier<SalonCustomer?> {
  @override
  FutureOr<SalonCustomer?> build() => null;

  Future<SalonCustomer?> execute({
    required String name,
    required String detail,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageSalon(ref);
      try {
        final result = await ref.read(salonRepositoryProvider).registerSalonCustomer(
              query: ref.read(repositoryQueryProvider),
              name: name,
              detail: detail,
            );
        _invalidateSalonReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final registerSalonCustomerProvider =
    AsyncNotifierProvider<RegisterSalonCustomerNotifier, SalonCustomer?>(RegisterSalonCustomerNotifier.new);
