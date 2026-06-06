import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

final financeSettingsLoadingProvider = StateProvider<bool>((ref) => false);
final financeSettingsErrorProvider = StateProvider<bool>((ref) => false);

final financeSettingsProvider = Provider<FinanceSettingsData?>((ref) {
  if (ref.watch(financeSettingsLoadingProvider)) return null;
  if (ref.watch(financeSettingsErrorProvider)) return null;
  return ref.read(financeRepositoryProvider).getSettings();
});
