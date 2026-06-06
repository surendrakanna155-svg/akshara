import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

final financeDefaultersLoadingProvider = StateProvider<bool>((ref) => false);
final financeDefaultersErrorProvider = StateProvider<bool>((ref) => false);
final financeDefaultersEmptyProvider = StateProvider<bool>((ref) => false);
final financeDefaultersFilterProvider = StateProvider<int>((ref) => 0);
final financeSelectedDefaulterIdProvider = StateProvider<String?>((ref) => null);

final financeDefaultersProvider = Provider<DefaultersDashboardData?>((ref) {
  if (ref.watch(financeDefaultersLoadingProvider)) return null;
  if (ref.watch(financeDefaultersErrorProvider)) return null;
  if (ref.watch(financeDefaultersEmptyProvider)) return null;
  return ref.read(financeRepositoryProvider).getDefaultersDashboard();
});

final financeFilteredDefaultersProvider = Provider<List<DefaulterRecord>>((ref) {
  final data = ref.watch(financeDefaultersProvider);
  if (data == null) return const [];
  final filterIndex = ref.watch(financeDefaultersFilterProvider);
  return switch (filterIndex) {
    1 => data.defaulters
        .where((d) => d.bucket == DefaulterAgingBucket.days1to30)
        .toList(),
    2 => data.defaulters
        .where((d) => d.bucket == DefaulterAgingBucket.days31to60)
        .toList(),
    3 => data.defaulters
        .where((d) => d.bucket == DefaulterAgingBucket.over90)
        .toList(),
    _ => data.defaulters,
  };
});

final financeSelectedDefaulterProvider = Provider<DefaulterRecord?>((ref) {
  final defaulters = ref.watch(financeFilteredDefaultersProvider);
  final selectedId = ref.watch(financeSelectedDefaulterIdProvider);
  if (selectedId != null) {
    for (final record in defaulters) {
      if (record.id == selectedId) return record;
    }
  }
  return defaulters.isEmpty ? null : defaulters.first;
});
