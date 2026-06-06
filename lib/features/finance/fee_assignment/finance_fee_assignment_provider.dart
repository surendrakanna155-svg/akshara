import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

final financeFeeAssignmentLoadingProvider = StateProvider<bool>((ref) => false);
final financeFeeAssignmentErrorProvider = StateProvider<bool>((ref) => false);
final financeSelectedHandoffIdProvider = StateProvider<String?>((ref) => null);

final financeInstallmentPlansProvider = Provider<List<InstallmentPlan>>(
  (ref) => ref.read(financeRepositoryProvider).getInstallmentPlans(),
);

final financeAssignmentDraftProvider = StateProvider<FeeAssignmentDraft?>(
  (ref) => null,
);

GeneratedFeeAccountPreview buildFeeAccountPreview({
  required String handoffId,
  required String studentName,
  required String admissionNumber,
  required FinanceFeeStructure structure,
  required InstallmentPlan plan,
  required bool includeTransport,
  required bool includeHostel,
}) {
  final addOns = <String>[];
  if (includeTransport) addOns.add('Transport add-on');
  if (includeHostel) addOns.add('Hostel add-on');

  return GeneratedFeeAccountPreview(
    accountId: 'FA-$handoffId',
    studentName: studentName,
    admissionNumber: admissionNumber,
    feeStructureName: structure.name,
    totalDue: structure.totalAnnual,
    installmentSummary: plan.label,
    addOns: addOns,
  );
}

