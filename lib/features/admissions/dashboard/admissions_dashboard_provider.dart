import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../admissions_models.dart';

final admissionsDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsDashboardErrorProvider = StateProvider<bool>((ref) => false);
final admissionsDashboardEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsDashboardFilterProvider = StateProvider<int>((ref) => 0);

final admissionsDashboardProvider = Provider<AdmissionsDashboardData?>((ref) {
  if (ref.watch(admissionsDashboardLoadingProvider)) return null;
  if (ref.watch(admissionsDashboardErrorProvider)) return null;
  if (ref.watch(admissionsDashboardEmptyProvider)) return null;
  return ref.read(admissionsRepositoryProvider).getDashboard();
});
