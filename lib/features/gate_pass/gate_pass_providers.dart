import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/tenant/tenant_provider.dart';
import 'gate_pass_datasource.dart';
import 'gate_pass_models.dart';

final gatePassDataSourceProvider = Provider<GatePassDataSource>(
  (ref) => GatePassDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
  ),
);

/// The active status filter for the staff queue (null = all statuses).
final gatePassStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// The gate pass queue, refetched whenever the status filter changes.
final gatePassesProvider = FutureProvider.autoDispose<List<GatePass>>((ref) {
  final status = ref.watch(gatePassStatusFilterProvider);
  return ref.watch(gatePassDataSourceProvider).list(status: status);
});
