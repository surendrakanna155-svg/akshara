import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'hostel_models.dart';
import 'hostel_providers.dart';
import 'hostel_requests.dart';

void assertManageHostel(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.manageHostel)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage hostel.',
        code: 'RBAC_MANAGE_HOSTEL',
      ),
    );
  }
}

class AdmitHostelStudentNotifier extends AsyncNotifier<HostelStudent?> {
  @override
  FutureOr<HostelStudent?> build() => null;

  Future<HostelStudent?> execute(AdmitHostelStudentRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHostel(ref);
      try {
        final result = await ref.read(hostelRepositoryProvider).admitHostelStudent(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(hostelStudentsFutureProvider)
          ..invalidate(hostelDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final admitHostelStudentProvider =
    AsyncNotifierProvider<AdmitHostelStudentNotifier, HostelStudent?>(
  AdmitHostelStudentNotifier.new,
);

class AssignHostelRoomNotifier extends AsyncNotifier<HostelStudent?> {
  @override
  FutureOr<HostelStudent?> build() => null;

  Future<HostelStudent?> execute(AssignHostelRoomRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHostel(ref);
      try {
        final result = await ref.read(hostelRepositoryProvider).assignHostelRoom(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(hostelStudentsFutureProvider)
          ..invalidate(hostelRoomsFutureProvider)
          ..invalidate(hostelDashboardFutureProvider)
          ..invalidate(hostelReportsFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final assignHostelRoomProvider =
    AsyncNotifierProvider<AssignHostelRoomNotifier, HostelStudent?>(
  AssignHostelRoomNotifier.new,
);

class CheckoutHostelStudentNotifier extends AsyncNotifier<HostelStudent?> {
  @override
  FutureOr<HostelStudent?> build() => null;

  Future<HostelStudent?> execute(CheckoutHostelStudentRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHostel(ref);
      try {
        final result =
            await ref.read(hostelRepositoryProvider).checkoutHostelStudent(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        ref
          ..invalidate(hostelStudentsFutureProvider)
          ..invalidate(hostelRoomsFutureProvider)
          ..invalidate(hostelDashboardFutureProvider)
          ..invalidate(hostelReportsFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final checkoutHostelStudentProvider =
    AsyncNotifierProvider<CheckoutHostelStudentNotifier, HostelStudent?>(
  CheckoutHostelStudentNotifier.new,
);

class CreateHostelRoomNotifier extends AsyncNotifier<HostelRoom?> {
  @override
  FutureOr<HostelRoom?> build() => null;

  Future<HostelRoom?> execute(CreateHostelRoomRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHostel(ref);
      try {
        final result = await ref.read(hostelRepositoryProvider).createHostelRoom(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(hostelRoomsFutureProvider)
          ..invalidate(hostelDashboardFutureProvider)
          ..invalidate(hostelReportsFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createHostelRoomProvider =
    AsyncNotifierProvider<CreateHostelRoomNotifier, HostelRoom?>(
  CreateHostelRoomNotifier.new,
);

class LogVisitorNotifier extends AsyncNotifier<HostelVisitor?> {
  @override
  FutureOr<HostelVisitor?> build() => null;

  Future<HostelVisitor?> execute(LogVisitorRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageHostel(ref);
      try {
        final result = await ref.read(hostelRepositoryProvider).logVisitor(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(hostelVisitorsFutureProvider)
          ..invalidate(hostelDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final logVisitorProvider =
    AsyncNotifierProvider<LogVisitorNotifier, HostelVisitor?>(
  LogVisitorNotifier.new,
);
