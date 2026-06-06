import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

final financeDiscountsLoadingProvider = StateProvider<bool>((ref) => false);
final financeDiscountsErrorProvider = StateProvider<bool>((ref) => false);
final financeDiscountsEmptyProvider = StateProvider<bool>((ref) => false);
final financeDiscountsTabProvider = StateProvider<int>((ref) => 0);

final financeDiscountsProvider = Provider<DiscountsDashboardData?>((ref) {
  if (ref.watch(financeDiscountsLoadingProvider)) return null;
  if (ref.watch(financeDiscountsErrorProvider)) return null;
  if (ref.watch(financeDiscountsEmptyProvider)) return null;
  return ref.read(financeRepositoryProvider).getDiscountsDashboard();
});
