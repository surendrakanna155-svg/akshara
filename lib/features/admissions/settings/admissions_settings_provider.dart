import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../admissions_models.dart';

final admissionsSettingsLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsSettingsErrorProvider = StateProvider<bool>((ref) => false);

final admissionsSettingsProvider = Provider<AdmissionsSettingsData?>((ref) {
  if (ref.watch(admissionsSettingsLoadingProvider)) return null;
  if (ref.watch(admissionsSettingsErrorProvider)) return null;
  return ref.read(admissionsRepositoryProvider).getSettings();
});
