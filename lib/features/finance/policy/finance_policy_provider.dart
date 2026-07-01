import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../collections/finance_collections_provider.dart';
import '../defaulters/finance_defaulters_provider.dart';
import '../finance_audit.dart';
import '../finance_models.dart';
import '../invoices/finance_invoices_provider.dart';
import '../student_accounts/finance_student_accounts_provider.dart';

// ── FIN-D1 / FIN-D3 / FIN-D5 / FIN-2: finance policy providers ────────────────
// Wires the day-close lock, cancelled register, late-fee accrual/waive, and the
// printable student ledger onto the already-existing repository contract. Reads
// are FutureProviders; writes mirror the mutation-notifier pattern used across
// finance (assertManageFinance + invalidate the relevant reads).

/// FIN-D3 — cancelled collections register (read).
final financeCancelledCollectionsFutureProvider =
    FutureProvider<List<CancelledCollection>>((ref) async {
  return ref.read(financeRepositoryProvider).getCancelledCollections(
        query: ref.watch(repositoryQueryProvider),
      );
});

/// FIN-D1 — day-close entries (read). Latest closed day surfaces first.
final financeDayCloseEntriesFutureProvider =
    FutureProvider<List<DayCloseEntry>>((ref) async {
  return ref.read(financeRepositoryProvider).getDayCloseEntries(
        query: ref.watch(repositoryQueryProvider),
      );
});

/// FIN-2 — printable student ledger / fee statement (read, by fee-account id).
final studentLedgerFutureProvider =
    FutureProvider.family<StudentLedger, String>((ref, studentAccountId) async {
  return ref.read(financeRepositoryProvider).getStudentLedger(
        query: ref.watch(repositoryQueryProvider),
        studentAccountId: studentAccountId,
      );
});

/// Invalidates every policy-adjacent read after a mutation succeeds.
void _invalidatePolicyReads(Ref ref) {
  ref.invalidate(financeDayCloseEntriesFutureProvider);
  ref.invalidate(financeCancelledCollectionsFutureProvider);
  ref.invalidate(financeCollectionsFutureProvider);
  ref.invalidate(financeDailySummaryFutureProvider);
  ref.invalidate(financeInvoicesFutureProvider);
  ref.invalidate(financeStudentAccountsFutureProvider);
  ref.invalidate(financeDefaultersFutureProvider);
}

/// FIN-D5 — accrue late fees on eligible outstanding invoices.
class AccrueLateFeesNotifier extends AsyncNotifier<LateFeeAccrualResult?> {
  @override
  FutureOr<LateFeeAccrualResult?> build() => null;

  Future<LateFeeAccrualResult?> execute() async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageFinance(ref);
      try {
        final result = await ref.read(financeRepositoryProvider).accrueLateFees(
              query: ref.read(repositoryQueryProvider),
            );
        try {
          await recordFinanceAudit(
            ref,
            action: 'accrueLateFees',
            entityId: 'lateFeeAccrual',
            metadata: {
              'accruedCount': '${result.accruedCount}',
              'totalLateFee': result.totalLateFee,
            },
          );
        } catch (_) {
          // Audit persistence must not block the mutation in QA automation.
        }
        _invalidatePolicyReads(ref);
        return result;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final accrueLateFeesProvider =
    AsyncNotifierProvider<AccrueLateFeesNotifier, LateFeeAccrualResult?>(
  AccrueLateFeesNotifier.new,
);

/// FIN-D5 — waive an invoice's accrued late fee (mandatory reason).
class WaiveLateFeeNotifier extends AsyncNotifier<FinanceInvoice?> {
  @override
  FutureOr<FinanceInvoice?> build() => null;

  Future<FinanceInvoice?> execute({
    required String invoiceId,
    required String reason,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageFinance(ref);
      try {
        final invoice = await ref.read(financeRepositoryProvider).waiveLateFee(
              query: ref.read(repositoryQueryProvider),
              invoiceId: invoiceId,
              reason: reason,
            );
        try {
          await recordFinanceAudit(
            ref,
            action: 'waiveLateFee',
            entityId: invoiceId,
            metadata: {'reason': reason},
          );
        } catch (_) {
          // Audit persistence must not block the mutation in QA automation.
        }
        _invalidatePolicyReads(ref);
        return invoice;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final waiveLateFeeProvider =
    AsyncNotifierProvider<WaiveLateFeeNotifier, FinanceInvoice?>(
  WaiveLateFeeNotifier.new,
);

/// FIN-D1 — close a day (locks collections against back-dated edits).
class CloseDayNotifier extends AsyncNotifier<DayCloseEntry?> {
  @override
  FutureOr<DayCloseEntry?> build() => null;

  Future<DayCloseEntry?> execute({String? date}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageFinance(ref);
      try {
        final entry = await ref.read(financeRepositoryProvider).closeDay(
              query: ref.read(repositoryQueryProvider),
              date: date,
            );
        try {
          await recordFinanceAudit(
            ref,
            action: 'closeDay',
            entityId: entry.closeDate,
          );
        } catch (_) {
          // Audit persistence must not block the mutation in QA automation.
        }
        _invalidatePolicyReads(ref);
        return entry;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final closeDayProvider =
    AsyncNotifierProvider<CloseDayNotifier, DayCloseEntry?>(
  CloseDayNotifier.new,
);

/// FIN-D1 — reopen a previously-closed day.
class ReopenDayNotifier extends AsyncNotifier<DayCloseEntry?> {
  @override
  FutureOr<DayCloseEntry?> build() => null;

  Future<DayCloseEntry?> execute({required String date}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageFinance(ref);
      try {
        final entry = await ref.read(financeRepositoryProvider).reopenDay(
              query: ref.read(repositoryQueryProvider),
              date: date,
            );
        try {
          await recordFinanceAudit(
            ref,
            action: 'reopenDay',
            entityId: entry.closeDate,
          );
        } catch (_) {
          // Audit persistence must not block the mutation in QA automation.
        }
        _invalidatePolicyReads(ref);
        return entry;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final reopenDayProvider =
    AsyncNotifierProvider<ReopenDayNotifier, DayCloseEntry?>(
  ReopenDayNotifier.new,
);
