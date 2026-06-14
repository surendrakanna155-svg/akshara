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
