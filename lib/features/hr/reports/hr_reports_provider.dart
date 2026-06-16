import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/async/erp_async_state.dart';
import '../hr_models.dart';

final hrReportsLoadingProvider = StateProvider<bool>((ref) => false);
final hrReportsErrorProvider = StateProvider<bool>((ref) => false);
final hrReportsEmptyProvider = StateProvider<bool>((ref) => false);
final hrSelectedReportIdProvider = StateProvider<String>((ref) => 'hr_headcount');

final hrReportsFutureProvider = FutureProvider<HrReportsData>((ref) async {
  await Future<void>.delayed(const Duration(milliseconds: 80));
  return HrReportsData.mock();
});

final hrReportsViewStateProvider = Provider<ErpViewState<HrReportsData>>((ref) {
  return resolveErpAsync(
    ref.watch(hrReportsFutureProvider),
    forceLoading: ref.watch(hrReportsLoadingProvider),
    forceError: ref.watch(hrReportsErrorProvider),
    forceEmpty: ref.watch(hrReportsEmptyProvider),
    isDataEmpty: (data) => data.catalog.isEmpty,
  );
});
