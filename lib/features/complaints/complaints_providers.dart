import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/tenant/tenant_provider.dart';
import 'complaints_datasource.dart';
import 'complaints_models.dart';

/// PRC-A Batch 2 — the complaints datasource + list/detail reads.
final complaintsDataSourceProvider = Provider<ComplaintsDataSource>(
  (ref) => ComplaintsDataSource(
    dio: ref.watch(dioProvider),
    query: ref.watch(repositoryQueryProvider),
  ),
);

/// The filtered complaints queue. autoDispose + family so each filter
/// combination fetches fresh and is released when no screen watches it.
final complaintsListProvider =
    FutureProvider.autoDispose.family<List<Complaint>, ComplaintsFilter>((ref, filter) {
  return ref.watch(complaintsDataSourceProvider).list(
        status: filter.status,
        category: filter.category,
        assignedTo: filter.assignedTo,
        severity: filter.severity,
      );
});

/// A single complaint + its full event timeline.
final complaintDetailProvider =
    FutureProvider.autoDispose.family<Complaint, String>((ref, id) {
  return ref.watch(complaintsDataSourceProvider).detail(id);
});
