import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../defaulters/finance_defaulters_provider.dart';
import '../finance_async_state.dart';
import '../finance_audit.dart';
import '../finance_models.dart';
import '../finance_requests.dart';

// ── FIN-R1..R5: fee-recovery CRM providers ────────────────────────────────────

/// Status filter for the promise-to-pay worklist. `null` = all.
final financePromiseStatusFilterProvider =
    StateProvider<PromiseToPayStatus?>((ref) => PromiseToPayStatus.pending);

/// Manual-override flags (mirrors the defaulters providers) for widget tests.
final financePromisesLoadingProvider = StateProvider<bool>((ref) => false);
final financePromisesErrorProvider = StateProvider<bool>((ref) => false);

final financePromisesFutureProvider =
    FutureProvider<List<PromiseToPay>>((ref) async {
  final status = ref.watch(financePromiseStatusFilterProvider);
  return ref.read(financeRepositoryProvider).listPromisesToPay(
        query: ref.watch(repositoryQueryProvider),
        status: status,
      );
});

final financePromisesViewStateProvider =
    Provider<FinanceViewState<List<PromiseToPay>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financePromisesFutureProvider),
    forceLoading: ref.watch(financePromisesLoadingProvider),
    forceError: ref.watch(financePromisesErrorProvider),
    isDataEmpty: (data) => data.isEmpty,
  );
});

final financeRecoveryDashboardLoadingProvider =
    StateProvider<bool>((ref) => false);
final financeRecoveryDashboardErrorProvider =
    StateProvider<bool>((ref) => false);

final financeRecoveryDashboardFutureProvider =
    FutureProvider<RecoveryDashboardData>((ref) async {
  return ref.read(financeRepositoryProvider).getRecoveryDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final financeRecoveryDashboardViewStateProvider =
    Provider<FinanceViewState<RecoveryDashboardData>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeRecoveryDashboardFutureProvider),
    forceLoading: ref.watch(financeRecoveryDashboardLoadingProvider),
    forceError: ref.watch(financeRecoveryDashboardErrorProvider),
  );
});

/// Contacts for a single student (used in the defaulter detail sheet). The
/// defaulters list already carries `contactHistory`; this re-fetches the live
/// list after a new contact is logged.
final financeStudentContactsFutureProvider =
    FutureProvider.family<List<RecoveryContact>, String>((ref, studentId) async {
  return ref.read(financeRepositoryProvider).listRecoveryContacts(
        query: ref.watch(repositoryQueryProvider),
        studentId: studentId,
      );
});

/// FIN-R2 — the telecaller call queue (server-ranked "who to call next").
final financeCallQueueLoadingProvider = StateProvider<bool>((ref) => false);
final financeCallQueueErrorProvider = StateProvider<bool>((ref) => false);

final financeCallQueueFutureProvider =
    FutureProvider<List<CallQueueEntry>>((ref) async {
  return ref.read(financeRepositoryProvider).getCallQueue(
        query: ref.watch(repositoryQueryProvider),
      );
});

final financeCallQueueViewStateProvider =
    Provider<FinanceViewState<List<CallQueueEntry>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeCallQueueFutureProvider),
    forceLoading: ref.watch(financeCallQueueLoadingProvider),
    forceError: ref.watch(financeCallQueueErrorProvider),
    isDataEmpty: (data) => data.isEmpty,
  );
});

/// Invalidates every recovery-adjacent read after a mutation succeeds — incl.
/// the call queue, so logging a contact / a promise re-ranks it immediately.
void _invalidateRecoveryReads(Ref ref) {
  ref.invalidate(financeDefaultersFutureProvider);
  ref.invalidate(financePromisesFutureProvider);
  ref.invalidate(financeRecoveryDashboardFutureProvider);
  ref.invalidate(financeCallQueueFutureProvider);
}

class LogRecoveryContactNotifier extends AsyncNotifier<RecoveryContact?> {
  @override
  FutureOr<RecoveryContact?> build() => null;

  Future<RecoveryContact?> execute(LogRecoveryContactRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageFinance(ref);
      try {
        final contact =
            await ref.read(financeRepositoryProvider).logRecoveryContact(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        _invalidateRecoveryReads(ref);
        ref.invalidate(financeStudentContactsFutureProvider(request.studentId));
        return contact;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final logRecoveryContactProvider =
    AsyncNotifierProvider<LogRecoveryContactNotifier, RecoveryContact?>(
  LogRecoveryContactNotifier.new,
);

class CreatePromiseToPayNotifier extends AsyncNotifier<PromiseToPay?> {
  @override
  FutureOr<PromiseToPay?> build() => null;

  Future<PromiseToPay?> execute(CreatePromiseToPayRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageFinance(ref);
      try {
        final promise =
            await ref.read(financeRepositoryProvider).createPromiseToPay(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                );
        _invalidateRecoveryReads(ref);
        return promise;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createPromiseToPayProvider =
    AsyncNotifierProvider<CreatePromiseToPayNotifier, PromiseToPay?>(
  CreatePromiseToPayNotifier.new,
);

class ResolvePromiseToPayNotifier extends AsyncNotifier<PromiseToPay?> {
  @override
  FutureOr<PromiseToPay?> build() => null;

  Future<PromiseToPay?> execute({
    required String promiseId,
    required PromiseToPayStatus status,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageFinance(ref);
      try {
        final promise =
            await ref.read(financeRepositoryProvider).resolvePromiseToPay(
                  query: ref.read(repositoryQueryProvider),
                  promiseId: promiseId,
                  request: ResolvePromiseToPayRequest(status: status),
                );
        _invalidateRecoveryReads(ref);
        return promise;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final resolvePromiseToPayProvider =
    AsyncNotifierProvider<ResolvePromiseToPayNotifier, PromiseToPay?>(
  ResolvePromiseToPayNotifier.new,
);
