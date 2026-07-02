import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../sis_async_state.dart';
import '../sis_models.dart';

/// SIS-5 — inclusive ISO date range filter for the transfers / exit log.
@immutable
class SisTransfersRange {
  const SisTransfersRange({this.fromDate, this.toDate});

  final String? fromDate;
  final String? toDate;
}

final sisTransfersRangeProvider =
    StateProvider<SisTransfersRange>((ref) => const SisTransfersRange());

/// Status filter chip index: 0 = All, 1 = Transferred, 2 = Alumni.
final sisTransfersStatusIndexProvider = StateProvider<int>((ref) => 0);

final sisTransfersPageProvider = StateProvider<int>((ref) => 1);

/// Filter-bar labels for the transfers screen.
const List<String> kSisTransfersStatusFilters = [
  'All',
  'Transferred',
  'Alumni',
];

SisStudentStatus? sisTransfersStatusForIndex(int index) => switch (index) {
      1 => SisStudentStatus.transferred,
      2 => SisStudentStatus.alumni,
      _ => null,
    };

final sisTransfersFutureProvider =
    FutureProvider<PaginatedResult<SisTransferRecord>>((ref) async {
  final range = ref.watch(sisTransfersRangeProvider);
  final status = sisTransfersStatusForIndex(
    ref.watch(sisTransfersStatusIndexProvider),
  );
  final page = ref.watch(sisTransfersPageProvider);
  return ref.read(sisRepositoryProvider).listStudentTransfers(
        query: ref.watch(repositoryQueryProvider).withPage(page),
        fromDate: range.fromDate,
        toDate: range.toDate,
        status: status,
      );
});

final sisTransfersViewStateProvider =
    Provider<SisViewState<PaginatedResult<SisTransferRecord>>>((ref) {
  return resolveSisAsync(
    ref.watch(sisTransfersFutureProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});
