import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeFeeAssignmentLoadingProvider = StateProvider<bool>((ref) => false);
final financeFeeAssignmentErrorProvider = StateProvider<bool>((ref) => false);
final financeSelectedHandoffIdProvider = StateProvider<String?>((ref) => null);

final financeInstallmentPlansFutureProvider =
    FutureProvider<List<InstallmentPlan>>((ref) async {
  return ref
      .read(financeRepositoryProvider)
      .getInstallmentPlans(query: ref.watch(repositoryQueryProvider));
});

final financeInstallmentPlansProvider = Provider<List<InstallmentPlan>>(
  (ref) =>
      watchRepositoryFuture(
        ref,
        ref.watch(financeInstallmentPlansFutureProvider),
        manualLoading: false,
        manualError: false,
        manualEmpty: false,
      ) ??
      const [],
);

final financeInstallmentPlansViewStateProvider =
    Provider<FinanceViewState<List<InstallmentPlan>>>((ref) {
  return resolveFinanceAsync(
    ref.watch(financeInstallmentPlansFutureProvider),
    forceLoading: ref.watch(financeFeeAssignmentLoadingProvider),
    forceError: ref.watch(financeFeeAssignmentErrorProvider),
    isDataEmpty: (plans) => plans.isEmpty,
  );
});

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
