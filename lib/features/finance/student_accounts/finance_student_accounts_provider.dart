import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

final financeStudentAccountsLoadingProvider = StateProvider<bool>((ref) => false);
final financeStudentAccountsErrorProvider = StateProvider<bool>((ref) => false);
final financeStudentAccountsEmptyProvider = StateProvider<bool>((ref) => false);
final financeStudentSearchQueryProvider = StateProvider<String>((ref) => '');
final financeSelectedAccountIdProvider = StateProvider<String?>((ref) => null);

final financeStudentAccountsProvider = Provider<List<StudentFeeAccount>>((ref) {
  if (ref.watch(financeStudentAccountsLoadingProvider)) return const [];
  if (ref.watch(financeStudentAccountsErrorProvider)) return const [];
  if (ref.watch(financeStudentAccountsEmptyProvider)) return const [];
  return ref.read(financeRepositoryProvider).getStudentAccounts();
});

final financeFilteredStudentAccountsProvider =
    Provider<List<StudentFeeAccount>>((ref) {
  final accounts = ref.watch(financeStudentAccountsProvider);
  final query = ref.watch(financeStudentSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return accounts;
  return accounts
      .where(
        (a) =>
            a.studentName.toLowerCase().contains(query) ||
            a.admissionNumber.toLowerCase().contains(query),
      )
      .toList(growable: false);
});

final financeSelectedStudentAccountProvider = Provider<StudentFeeAccount?>(
  (ref) {
    final accounts = ref.watch(financeFilteredStudentAccountsProvider);
    final selectedId = ref.watch(financeSelectedAccountIdProvider);
    if (selectedId != null) {
      for (final account in accounts) {
        if (account.id == selectedId) return account;
      }
    }
    return accounts.isEmpty ? null : accounts.first;
  },
);
