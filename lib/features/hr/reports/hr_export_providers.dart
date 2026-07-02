import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../hr_report_models.dart';

/// Providers backing the HR reporting / export reads (HR-1/2/4/5/6/7). Each
/// fetches from [hrRepositoryProvider] with the current tenant scope; the
/// screens read these on demand (in the export button callbacks) so a report is
/// only fetched when the user asks to export it.

/// The payroll run selected for HR-1 salary register / HR-2 payslips. The
/// payroll screen sets this to the run it is exporting.
final hrExportRunIdProvider = StateProvider<String?>((ref) => null);

/// The month (YYYY-MM) selected for the HR-6 muster; defaults to the current
/// month. The attendance screen may override it.
final hrMusterMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
});

final hrSalaryRegisterProvider =
    FutureProvider.family<HrSalaryRegister, String>((ref, runId) async {
  return ref
      .read(hrRepositoryProvider)
      .getSalaryRegister(query: ref.watch(repositoryQueryProvider), runId: runId);
});

final hrPayslipsProvider =
    FutureProvider.family<HrPayslipBundle, String>((ref, runId) async {
  return ref
      .read(hrRepositoryProvider)
      .getPayslips(query: ref.watch(repositoryQueryProvider), runId: runId);
});

final hrAttendanceMusterProvider =
    FutureProvider.family<HrAttendanceMuster, String>((ref, month) async {
  return ref
      .read(hrRepositoryProvider)
      .getAttendanceMuster(query: ref.watch(repositoryQueryProvider), month: month);
});

final hrLeaveBalancesProvider =
    FutureProvider<HrLeaveBalanceReport>((ref) async {
  return ref
      .read(hrRepositoryProvider)
      .getLeaveBalances(query: ref.watch(repositoryQueryProvider));
});

final hrHeadcountProvider = FutureProvider<HrHeadcountReport>((ref) async {
  return ref
      .read(hrRepositoryProvider)
      .getHeadcount(query: ref.watch(repositoryQueryProvider));
});

final hrEmployeeDirectoryProvider =
    FutureProvider<HrEmployeeDirectory>((ref) async {
  return ref
      .read(hrRepositoryProvider)
      .getEmployeeDirectory(query: ref.watch(repositoryQueryProvider));
});

/// HR-D1 — staff documents expiring within 30 days (export report).
final hrExpiringDocumentsExportProvider =
    FutureProvider<HrExpiringDocumentsReport>((ref) async {
  return ref
      .read(hrRepositoryProvider)
      .getExpiringDocuments(query: ref.watch(repositoryQueryProvider));
});

/// HR-D2 — employees whose probation ends within 15 days (export report).
final hrProbationEndingExportProvider =
    FutureProvider<HrProbationEndingReport>((ref) async {
  return ref
      .read(hrRepositoryProvider)
      .getProbationEnding(query: ref.watch(repositoryQueryProvider));
});
