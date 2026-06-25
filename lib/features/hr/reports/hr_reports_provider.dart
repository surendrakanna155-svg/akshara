import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../shared/async/erp_async_state.dart';
import '../hr_models.dart';

final hrReportsLoadingProvider = StateProvider<bool>((ref) => false);
final hrReportsErrorProvider = StateProvider<bool>((ref) => false);
final hrReportsEmptyProvider = StateProvider<bool>((ref) => false);
final hrSelectedReportIdProvider = StateProvider<String>((ref) => 'hr_headcount');

/// STF-7: HR reports now derive their headline metric from the LIVE HR
/// dashboard (active staff + attendance %), using the same repository/tenant
/// scope as every other HR provider. The static report-tile catalog is reused
/// from [HrReportsData.mock]; only the headline is rewired to real data.
final hrReportsFutureProvider = FutureProvider<HrReportsData>((ref) async {
  final dashboard = await ref
      .read(hrRepositoryProvider)
      .getDashboard(query: ref.watch(repositoryQueryProvider));

  String? kpiValue(String id) {
    for (final kpi in dashboard.kpis) {
      if (kpi.id == id) return kpi.value;
    }
    return null;
  }

  final activeStaff = kpiValue('total_employees');
  final attendance = kpiValue('avg_attendance');

  final headline = (activeStaff != null && attendance != null)
      ? '$activeStaff active staff · $attendance attendance MTD'
      : HrReportsData.mock().headlineMetric;

  return HrReportsData(
    headlineMetric: headline,
    catalog: HrReportsData.mock().catalog,
  );
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
