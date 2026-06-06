import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../finance_models.dart';

final financeCollectionDetailLoadingProvider = StateProvider<bool>((ref) => false);
final financeCollectionDetailErrorProvider = StateProvider<bool>((ref) => false);

final financeCollectionDetailProvider =
    Provider.family<CollectionDetail?, String>((ref, collectionId) {
  if (ref.watch(financeCollectionDetailLoadingProvider)) return null;
  if (ref.watch(financeCollectionDetailErrorProvider)) return null;
  return ref.read(financeRepositoryProvider).getCollectionDetail(collectionId);
});
