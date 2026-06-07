import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../finance_async_state.dart';
import '../finance_models.dart';

final financeCollectionDetailLoadingProvider =
    StateProvider<bool>((ref) => false);
final financeCollectionDetailErrorProvider = StateProvider<bool>((ref) => false);

final financeCollectionDetailFutureProvider =
    FutureProvider.family<CollectionDetail?, String>((ref, collectionId) async {
  return ref.read(financeRepositoryProvider).getCollectionDetail(
        query: ref.watch(repositoryQueryProvider),
        collectionId: collectionId,
      );
});

final financeCollectionDetailProvider =
    Provider.family<CollectionDetail?, String>((ref, collectionId) {
  if (ref.watch(financeCollectionDetailLoadingProvider)) return null;
  if (ref.watch(financeCollectionDetailErrorProvider)) return null;
  return watchRepositoryFuture<CollectionDetail?>(
    ref,
    ref.watch(financeCollectionDetailFutureProvider(collectionId)),
    manualLoading: false,
    manualError: false,
    manualEmpty: false,
  );
});

final financeCollectionDetailViewStateProvider =
    Provider.family<FinanceViewState<CollectionDetail?>, String>(
  (ref, collectionId) {
    return resolveFinanceAsync(
      ref.watch(financeCollectionDetailFutureProvider(collectionId)),
      forceLoading: ref.watch(financeCollectionDetailLoadingProvider),
      forceError: ref.watch(financeCollectionDetailErrorProvider),
      isDataEmpty: (detail) => detail == null,
    );
  },
);
