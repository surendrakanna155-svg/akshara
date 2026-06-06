import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../finance/finance_models.dart';
import '../../finance/student_accounts/finance_student_accounts_provider.dart';
import '../sis_models.dart';

/// Resolves fee account summary for a SIS student by admission number.
final sisFeeAccountForAdmissionProvider =
    Provider.family<SisFeeAccountSummary?, String>((ref, admissionNumber) {
  final accounts = ref.watch(financeStudentAccountsProvider);
  for (final account in accounts) {
    if (account.admissionNumber == admissionNumber) {
      return SisFeeAccountSummary(
        feeStructureName: account.feeStructureName,
        totalDue: account.totalDue,
        totalPaid: account.totalPaid,
        balance: account.balance,
        status: _mapFeeStatus(account.status),
      );
    }
  }
  return null;
});

String _mapFeeStatus(FeeAccountStatus status) => switch (status) {
      FeeAccountStatus.active => 'Active',
      FeeAccountStatus.overdue => 'Overdue',
      FeeAccountStatus.closed => 'Closed',
      FeeAccountStatus.pending => 'Pending',
    };
