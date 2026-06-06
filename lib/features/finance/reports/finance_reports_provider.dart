import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

final financeReportsLoadingProvider = StateProvider<bool>((ref) => false);
final financeReportsErrorProvider = StateProvider<bool>((ref) => false);
final financeReportsEmptyProvider = StateProvider<bool>((ref) => false);
final financeSelectedReportIdProvider = StateProvider<String>((ref) => 'rpt_collection');

final financeReportsProvider = Provider<FinanceReportsData?>((ref) {
  if (ref.watch(financeReportsLoadingProvider)) return null;
  if (ref.watch(financeReportsErrorProvider)) return null;
  if (ref.watch(financeReportsEmptyProvider)) return null;
  return ref.read(financeRepositoryProvider).getReportsData();
});
