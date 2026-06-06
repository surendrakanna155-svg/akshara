import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../sis_models.dart';

final sisDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final sisDashboardErrorProvider = StateProvider<bool>((ref) => false);
final sisDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final sisDashboardFilterProvider = StateProvider<int>((ref) => 0);

final sisDashboardProvider = Provider<SisDashboardData?>((ref) {
  if (ref.watch(sisDashboardLoadingProvider)) return null;
  if (ref.watch(sisDashboardErrorProvider)) return null;
  if (ref.watch(sisDashboardEmptyProvider)) return null;
  return ref.read(sisRepositoryProvider).getDashboard();
});
