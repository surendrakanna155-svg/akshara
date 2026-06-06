import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return _mockAccounts();
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

List<StudentFeeAccount> _mockAccounts() {
  return const [
    StudentFeeAccount(
      id: 'acct_1',
      studentName: 'Arjun Patel',
      admissionNumber: 'ADM-2026-0138',
      classLabel: '10',
      feeStructureName: 'Standard CBSE',
      totalDue: '₹1,85,000',
      totalPaid: '₹62,000',
      balance: '₹1,23,000',
      status: FeeAccountStatus.active,
      lastPaymentDate: 'Today',
      installmentPlan: '3-term quarterly',
    ),
    StudentFeeAccount(
      id: 'acct_2',
      studentName: 'Ananya Reddy',
      admissionNumber: 'ADM-2026-0142',
      classLabel: '5',
      feeStructureName: 'Premium + Transport',
      totalDue: '₹2,15,000',
      totalPaid: '₹0',
      balance: '₹2,15,000',
      status: FeeAccountStatus.pending,
      lastPaymentDate: '—',
      installmentPlan: '3-term quarterly',
    ),
    StudentFeeAccount(
      id: 'acct_3',
      studentName: 'Emma Thomas',
      admissionNumber: 'ADM-2026-0135',
      classLabel: '7',
      feeStructureName: 'Boarding Package',
      totalDue: '₹3,40,000',
      totalPaid: '₹85,000',
      balance: '₹2,55,000',
      status: FeeAccountStatus.active,
      lastPaymentDate: '2 days ago',
      installmentPlan: '4-term termly',
    ),
    StudentFeeAccount(
      id: 'acct_4',
      studentName: 'Priya Sharma',
      admissionNumber: 'ADM-2025-0092',
      classLabel: '8',
      feeStructureName: 'Standard CBSE',
      totalDue: '₹1,85,000',
      totalPaid: '₹1,20,000',
      balance: '₹65,000',
      status: FeeAccountStatus.overdue,
      lastPaymentDate: '45 days ago',
      installmentPlan: '3-term quarterly',
    ),
  ];
}
