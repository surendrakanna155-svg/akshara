import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../admissions_models.dart';

final admissionsLeadsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsLeadsErrorProvider = StateProvider<bool>((ref) => false);
final admissionsLeadsEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsLeadsFilterProvider = StateProvider<int>((ref) => 0);

final admissionsLeadsProvider = Provider<List<AdmissionsLead>>((ref) {
  if (ref.watch(admissionsLeadsLoadingProvider)) return const [];
  if (ref.watch(admissionsLeadsErrorProvider)) return const [];
  if (ref.watch(admissionsLeadsEmptyProvider)) return const [];
  return ref.read(admissionsRepositoryProvider).getLeads();
});
