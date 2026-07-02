import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/repositories/interfaces/communication_repository.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'communication_providers.dart';

void _assertManageCommunication(Ref ref) {
  if (!ref.read(canManageCommunicationProvider)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to send broadcasts.',
        code: 'RBAC_MANAGE_COMMUNICATION',
      ),
    );
  }
}

void _assertManageCommunicationTemplates(Ref ref) {
  if (!ref.read(canManageCommunicationTemplatesProvider)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage templates.',
        code: 'RBAC_MANAGE_COMMUNICATION_TEMPLATES',
      ),
    );
  }
}

class SendBroadcastNotifier extends AsyncNotifier<BroadcastResult?> {
  @override
  FutureOr<BroadcastResult?> build() => null;

  Future<BroadcastResult?> execute(BroadcastRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      _assertManageCommunication(ref);
      final result =
          await ref.read(communicationRepositoryProvider).sendBroadcast(
                query: ref.read(repositoryQueryProvider),
                request: request,
              );
      ref.invalidate(communicationBroadcastHistoryFutureProvider);
      return result;
    });
    return state.valueOrNull;
  }
}

final sendBroadcastProvider =
    AsyncNotifierProvider<SendBroadcastNotifier, BroadcastResult?>(
  SendBroadcastNotifier.new,
);

class SaveTemplateNotifier extends AsyncNotifier<CommunicationTemplate?> {
  @override
  FutureOr<CommunicationTemplate?> build() => null;

  Future<CommunicationTemplate?> execute({
    String? templateId,
    required String code,
    required String channel,
    String? subjectTemplate,
    required String bodyTemplate,
    List<String> variables = const [],
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      _assertManageCommunicationTemplates(ref);
      if (templateId == null || templateId.isEmpty) {
        final created =
            await ref.read(communicationRepositoryProvider).createTemplate(
                  query: ref.read(repositoryQueryProvider),
                  request: CreateCommunicationTemplateRequest(
                    code: code,
                    channel: channel,
                    subjectTemplate: subjectTemplate,
                    bodyTemplate: bodyTemplate,
                    variables: variables,
                  ),
                );
        ref.invalidate(communicationTemplatesFutureProvider);
        return created;
      }
      final updated =
          await ref.read(communicationRepositoryProvider).updateTemplate(
                query: ref.read(repositoryQueryProvider),
                templateId: templateId,
                request: UpdateCommunicationTemplateRequest(
                  code: code,
                  channel: channel,
                  subjectTemplate: subjectTemplate,
                  bodyTemplate: bodyTemplate,
                  variables: variables,
                ),
              );
      ref.invalidate(communicationTemplatesFutureProvider);
      return updated;
    });
    return state.valueOrNull;
  }
}

final saveTemplateProvider =
    AsyncNotifierProvider<SaveTemplateNotifier, CommunicationTemplate?>(
  SaveTemplateNotifier.new,
);

/// COM-3: re-enqueue a broadcast to its unread recipients. Holds the number of
/// recipients re-targeted from the last successful call.
class ResendBroadcastNotifier extends AsyncNotifier<int?> {
  @override
  FutureOr<int?> build() => null;

  Future<int?> execute(String broadcastId) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      _assertManageCommunication(ref);
      final resent =
          await ref.read(communicationRepositoryProvider).resendBroadcastToUnread(
                query: ref.read(repositoryQueryProvider),
                broadcastId: broadcastId,
              );
      ref.invalidate(communicationBroadcastReportFutureProvider(broadcastId));
      ref.invalidate(communicationBroadcastHistoryFutureProvider);
      return resent;
    });
    return state.valueOrNull;
  }
}

final resendBroadcastProvider =
    AsyncNotifierProvider<ResendBroadcastNotifier, int?>(
  ResendBroadcastNotifier.new,
);

/// COM-2: save a named audience segment.
class SaveAudienceSegmentNotifier extends AsyncNotifier<AudienceSegment?> {
  @override
  FutureOr<AudienceSegment?> build() => null;

  Future<AudienceSegment?> execute({
    required String name,
    required String audienceType,
    String? className,
    String? sectionName,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      _assertManageCommunication(ref);
      final segment =
          await ref.read(communicationRepositoryProvider).createAudienceSegment(
                query: ref.read(repositoryQueryProvider),
                name: name,
                audienceType: audienceType,
                className: className,
                sectionName: sectionName,
              );
      ref.invalidate(communicationAudienceSegmentsFutureProvider);
      return segment;
    });
    return state.valueOrNull;
  }
}

final saveAudienceSegmentProvider =
    AsyncNotifierProvider<SaveAudienceSegmentNotifier, AudienceSegment?>(
  SaveAudienceSegmentNotifier.new,
);

/// COM-2: delete a saved audience segment.
class DeleteAudienceSegmentNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> execute(String id) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      _assertManageCommunication(ref);
      await ref.read(communicationRepositoryProvider).deleteAudienceSegment(
            query: ref.read(repositoryQueryProvider),
            id: id,
          );
      ref.invalidate(communicationAudienceSegmentsFutureProvider);
    });
  }
}

final deleteAudienceSegmentProvider =
    AsyncNotifierProvider<DeleteAudienceSegmentNotifier, void>(
  DeleteAudienceSegmentNotifier.new,
);
