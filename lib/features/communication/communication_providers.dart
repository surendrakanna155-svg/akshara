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

/// COM-2: the caller's school's saved audience segments.
final communicationAudienceSegmentsFutureProvider =
    FutureProvider<List<AudienceSegment>>((ref) async {
  return ref.read(communicationRepositoryProvider).listAudienceSegments(
        query: ref.watch(repositoryQueryProvider),
      );
});

/// COM-1: per-broadcast delivery & read report, keyed by broadcast id.
final communicationBroadcastReportFutureProvider =
    FutureProvider.family<BroadcastDeliveryReport, String>((ref, broadcastId) {
  return ref.read(communicationRepositoryProvider).getBroadcastReport(
        query: ref.watch(repositoryQueryProvider),
        broadcastId: broadcastId,
      );
});
