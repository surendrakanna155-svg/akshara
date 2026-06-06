import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../finance_models.dart';

final financeFeeAssignmentLoadingProvider = StateProvider<bool>((ref) => false);
final financeFeeAssignmentErrorProvider = StateProvider<bool>((ref) => false);
final financeSelectedHandoffIdProvider = StateProvider<String?>((ref) => null);

final financeInstallmentPlansProvider = Provider<List<InstallmentPlan>>(
  (ref) => const [
    InstallmentPlan(
      id: 'plan_quarterly',
      label: '3-term quarterly',
      installmentCount: 3,
      type: InstallmentPlanType.quarterly,
    ),
    InstallmentPlan(
      id: 'plan_termly',
      label: '4-term termly',
      installmentCount: 4,
      type: InstallmentPlanType.termly,
    ),
    InstallmentPlan(
      id: 'plan_monthly',
      label: '10-month monthly',
      installmentCount: 10,
      type: InstallmentPlanType.monthly,
    ),
    InstallmentPlan(
      id: 'plan_annual',
      label: 'Annual single payment',
      installmentCount: 1,
      type: InstallmentPlanType.annual,
    ),
  ],
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

