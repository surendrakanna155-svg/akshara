import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

final financeDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final financeDashboardErrorProvider = StateProvider<bool>((ref) => false);
final financeDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final financeDashboardFilterProvider = StateProvider<int>((ref) => 0);

final financeDashboardProvider = Provider<FinanceDashboardData?>((ref) {
  if (ref.watch(financeDashboardLoadingProvider)) return null;
  if (ref.watch(financeDashboardErrorProvider)) return null;
  if (ref.watch(financeDashboardEmptyProvider)) return null;
  return ref.read(financeRepositoryProvider).getDashboard();
});
