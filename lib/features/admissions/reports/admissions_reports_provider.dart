import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../admissions_models.dart';

final admissionsReportsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsReportsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsReportsEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsReportsTabProvider = StateProvider<AdmissionsReportTab>(
  (ref) => AdmissionsReportTab.funnel,
);

final admissionsReportsProvider = Provider<AdmissionsReportsData?>((ref) {
  if (ref.watch(admissionsReportsLoadingProvider)) return null;
  if (ref.watch(admissionsReportsErrorProvider)) return null;
  if (ref.watch(admissionsReportsEmptyProvider)) return null;
  return ref.read(admissionsRepositoryProvider).getReports();
});
