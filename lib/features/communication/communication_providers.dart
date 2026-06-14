import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../core/repositories/interfaces/communication_repository.dart';

final communicationTemplatesFutureProvider =
    FutureProvider<List<CommunicationTemplate>>((ref) async {
  return ref.read(communicationRepositoryProvider).getTemplates(
        query: ref.watch(repositoryQueryProvider),
      );
});

final communicationBroadcastHistoryFutureProvider =
    FutureProvider<List<BroadcastHistoryItem>>((ref) async {
  return ref.read(communicationRepositoryProvider).listBroadcastHistory(
        query: ref.watch(repositoryQueryProvider),
      );
});
