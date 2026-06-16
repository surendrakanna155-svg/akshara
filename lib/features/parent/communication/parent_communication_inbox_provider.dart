import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/communication/parent_communication_models.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../parent_active_child_provider.dart';

String _profileChildId(String? authChildId) {
  if (authChildId == null) return 'child_ravi';
  return kAuthChildToProfileId[authChildId] ??
      authChildId.replaceAll('-', '_');
}

final parentCommunicationInboxLoadingProvider = StateProvider<bool>((ref) => false);
final parentCommunicationInboxErrorProvider = StateProvider<bool>((ref) => false);
final parentCommunicationInboxEmptyProvider = StateProvider<bool>((ref) => false);

final parentCommunicationInboxFutureProvider =
    FutureProvider<List<ParentCommunicationInboxItem>>((ref) async {
  final child = ref.watch(parentActiveChildProvider);
  return ref.read(parentRepositoryProvider).getCommunicationInbox(
        query: ref.watch(repositoryQueryProvider),
        activeChildId: _profileChildId(child?.id),
      );
});

final parentCommunicationInboxProvider =
    Provider<List<ParentCommunicationInboxItem>>((ref) {
  if (ref.watch(parentCommunicationInboxEmptyProvider)) return const [];
  final items = watchRepositoryFuture(
    ref,
    ref.watch(parentCommunicationInboxFutureProvider),
    manualLoading: ref.watch(parentCommunicationInboxLoadingProvider),
    manualError: ref.watch(parentCommunicationInboxErrorProvider),
    manualEmpty: ref.watch(parentCommunicationInboxEmptyProvider),
  );
  return items ??
      ref.watch(parentCommunicationInboxFutureProvider).value ??
      const [];
});

final parentCommunicationMessageProvider =
    Provider.family<ParentCommunicationInboxItem?, String>((ref, messageId) {
  for (final item in ref.watch(parentCommunicationInboxProvider)) {
    if (item.id == messageId) return item;
  }
  return null;
});

Future<void> markParentCommunicationRead(WidgetRef ref, String messageId) async {
  await ref.read(parentRepositoryProvider).markCommunicationRead(
        query: ref.read(repositoryQueryProvider),
        communicationId: messageId,
      );
  ref.invalidate(parentCommunicationInboxFutureProvider);
}

Future<void> acknowledgeParentCommunication(
  WidgetRef ref,
  String messageId,
) async {
  await ref.read(parentRepositoryProvider).acknowledgeCommunication(
        query: ref.read(repositoryQueryProvider),
        communicationId: messageId,
      );
  ref.invalidate(parentCommunicationInboxFutureProvider);
}
