import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../shared/async/erp_async_state.dart';
import '../hr_models.dart';

final hrReportsLoadingProvider = StateProvider<bool>((ref) => false);
final hrReportsErrorProvider = StateProvider<bool>((ref) => false);
final hrReportsEmptyProvider = StateProvider<bool>((ref) => false);
final hrSelectedReportIdProvider = StateProvider<String>((ref) => 'hr_headcount');

/// STF-7 + CERT-006: HR reports derive their headline metric from the LIVE HR
/// dashboard (active staff + attendance %), using the same repository/tenant
/// scope as every other HR provider. When either KPI is absent the headline is
/// **null** — the screen renders "Not available yet" rather than another
/// school's `142 active staff · 96.2% attendance MTD`.
///
/// The report *catalog* ([kHrReportCatalog]) is static product configuration —
/// the list of report types the module can produce — and carries no figures.
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
      : null;

  return HrReportsData(
    headlineMetric: headline,
    catalog: kHrReportCatalog,
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
