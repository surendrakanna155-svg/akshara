import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'library_models.dart';
import 'library_providers.dart';
import 'library_requests.dart';

void assertManageLibrary(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.manageLibrary)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage the library.',
        code: 'RBAC_MANAGE_LIBRARY',
      ),
    );
  }
}

class IssueLibraryBookNotifier extends AsyncNotifier<LibraryIssueRecord?> {
  @override
  FutureOr<LibraryIssueRecord?> build() => null;

  Future<LibraryIssueRecord?> execute(IssueLibraryBookRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageLibrary(ref);
      try {
        final result = await ref.read(libraryRepositoryProvider).issueLibraryBook(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(libraryIssuesFutureProvider)
          ..invalidate(libraryCatalogFutureProvider)
          ..invalidate(libraryMembersFutureProvider)
          ..invalidate(libraryDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final issueLibraryBookProvider =
    AsyncNotifierProvider<IssueLibraryBookNotifier, LibraryIssueRecord?>(
  IssueLibraryBookNotifier.new,
);

class ReturnLibraryBookNotifier extends AsyncNotifier<LibraryReturnRecord?> {
  @override
  FutureOr<LibraryReturnRecord?> build() => null;

  Future<LibraryReturnRecord?> execute(ReturnLibraryBookRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageLibrary(ref);
      try {
        final result = await ref.read(libraryRepositoryProvider).returnLibraryBook(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(libraryIssuesFutureProvider)
          ..invalidate(libraryReturnsFutureProvider)
          ..invalidate(libraryCatalogFutureProvider)
          ..invalidate(libraryMembersFutureProvider)
          ..invalidate(libraryDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final returnLibraryBookProvider =
    AsyncNotifierProvider<ReturnLibraryBookNotifier, LibraryReturnRecord?>(
  ReturnLibraryBookNotifier.new,
);

class AddLibraryBookNotifier extends AsyncNotifier<LibraryBook?> {
  @override
  FutureOr<LibraryBook?> build() => null;

  Future<LibraryBook?> execute(AddLibraryBookRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageLibrary(ref);
      try {
        final result = await ref.read(libraryRepositoryProvider).addLibraryBook(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(libraryCatalogFutureProvider)
          ..invalidate(libraryDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final addLibraryBookProvider =
    AsyncNotifierProvider<AddLibraryBookNotifier, LibraryBook?>(
  AddLibraryBookNotifier.new,
);

class AddLibraryResourceNotifier extends AsyncNotifier<LibraryDigitalResource?> {
  @override
  FutureOr<LibraryDigitalResource?> build() => null;

  Future<LibraryDigitalResource?> execute(
      AddLibraryResourceRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageLibrary(ref);
      try {
        final result =
            await ref.read(libraryRepositoryProvider).addDigitalResource(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        ref
          ..invalidate(libraryResourcesFutureProvider)
          ..invalidate(libraryDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final addLibraryResourceProvider =
    AsyncNotifierProvider<AddLibraryResourceNotifier, LibraryDigitalResource?>(
  AddLibraryResourceNotifier.new,
);

class EnrollLibraryMemberNotifier extends AsyncNotifier<LibraryMember?> {
  @override
  FutureOr<LibraryMember?> build() => null;

  Future<LibraryMember?> execute(EnrollLibraryMemberRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageLibrary(ref);
      try {
        final result = await ref.read(libraryRepositoryProvider).enrollMember(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(libraryMembersFutureProvider)
          ..invalidate(libraryDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final enrollLibraryMemberProvider =
    AsyncNotifierProvider<EnrollLibraryMemberNotifier, LibraryMember?>(
  EnrollLibraryMemberNotifier.new,
);

class WaiveLibraryFineNotifier extends AsyncNotifier<LibraryFine?> {
  @override
  FutureOr<LibraryFine?> build() => null;

  Future<LibraryFine?> execute(WaiveLibraryFineRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageLibrary(ref);
      try {
        final result = await ref.read(libraryRepositoryProvider).waiveFine(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        ref
          ..invalidate(libraryFinesFutureProvider)
          ..invalidate(libraryDashboardFutureProvider);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final waiveLibraryFineProvider =
    AsyncNotifierProvider<WaiveLibraryFineNotifier, LibraryFine?>(
  WaiveLibraryFineNotifier.new,
);
