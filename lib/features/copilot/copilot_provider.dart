import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/entitlements/entitlement_provider.dart';
import '../../core/school_config/school_configuration_provider.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'copilot_capability_filter.dart';
import 'copilot_context_provider.dart';
import 'copilot_models.dart';

final copilotSelectedAssistantProvider =
    StateProvider<CopilotAssistantType>((ref) => CopilotAssistantType.finance);

final copilotSelectedSessionIdProvider = StateProvider<String?>((ref) => null);

final copilotMessageDraftProvider = StateProvider<String>((ref) => '');

final copilotQueryProvider = Provider<RepositoryQuery>((ref) {
  return ref.watch(repositoryQueryProvider);
});

final copilotAssistantsFutureProvider = FutureProvider<List<CopilotAssistant>>((ref) async {
  return ref.read(copilotRepositoryProvider).getAssistants(
        query: ref.watch(copilotQueryProvider),
      );
});

final copilotSessionsFutureProvider = FutureProvider<List<CopilotSession>>((ref) async {
  return ref.read(copilotRepositoryProvider).getSessions(
        query: ref.watch(copilotQueryProvider),
      );
});

final copilotSuggestionsFutureProvider = FutureProvider<CopilotSuggestions>((ref) async {
  final assistant = ref.watch(copilotSelectedAssistantProvider);
  return ref.read(copilotRepositoryProvider).getSuggestions(
        query: ref.watch(copilotQueryProvider),
        assistantType: assistant,
      );
});

final copilotSessionDetailFutureProvider = FutureProvider<CopilotSessionDetail?>((ref) async {
  final sessionId = ref.watch(copilotSelectedSessionIdProvider);
  if (sessionId == null) return null;
  return ref.read(copilotRepositoryProvider).getSession(
        query: ref.watch(copilotQueryProvider),
        sessionId: sessionId,
      );
});

final copilotCanUseProvider = Provider<bool>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  return rbac.hasPermission(Permission.viewAiCopilot);
});

final copilotCanSendProvider = Provider<bool>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  return rbac.hasPermission(Permission.runAiCopilot);
});

final copilotSendMessageProvider =
    AsyncNotifierProvider<CopilotSendMessageNotifier, CopilotSendMessageResult?>(
  CopilotSendMessageNotifier.new,
);

class CopilotSendMessageNotifier extends AsyncNotifier<CopilotSendMessageResult?> {
  @override
  Future<CopilotSendMessageResult?> build() async => null;

  Future<CopilotSendMessageResult?> send(String content) async {
    final sessionId = ref.read(copilotSelectedSessionIdProvider);
    if (sessionId == null || content.trim().isEmpty) return null;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final screenContext = ref.read(copilotEffectiveContextProvider);
      final capabilities = ref.read(schoolCapabilitiesProvider);
      final blocked = CopilotCapabilityFilter.disabledTopicMessage(
        userMessage: content.trim(),
        capabilities: capabilities,
        module: screenContext?.module,
        planCeiling: ref.read(planCapabilityCeilingProvider),
      );
      if (blocked != null) {
        final now = DateTime.now();
        final userMessage = CopilotMessage(
          id: 'msg_user_$now',
          sessionId: sessionId,
          role: 'user',
          content: content.trim(),
          createdAt: now,
        );
        final assistantMessage = CopilotMessage(
          id: 'msg_assistant_$now',
          sessionId: sessionId,
          role: 'assistant',
          content: blocked,
          createdAt: now.add(const Duration(milliseconds: 200)),
          metadata: const {'stub': true, 'capabilityBlocked': true},
        );
        ref.invalidate(copilotSessionDetailFutureProvider);
        ref.invalidate(copilotSessionsFutureProvider);
        return CopilotSendMessageResult(
          userMessage: userMessage,
          assistantMessage: assistantMessage,
          model: 'akshara-stub',
          stub: true,
        );
      }
      final result = await ref.read(copilotRepositoryProvider).sendMessage(
            query: ref.read(copilotQueryProvider),
            sessionId: sessionId,
            content: content.trim(),
            screenContext: screenContext,
          );
      ref.invalidate(copilotSessionDetailFutureProvider);
      ref.invalidate(copilotSessionsFutureProvider);
      return result;
    });
    return state.value;
  }
}

Future<CopilotSession?> createCopilotSession(WidgetRef ref) async {
  final assistant = ref.read(copilotSelectedAssistantProvider);
  final session = await ref.read(copilotRepositoryProvider).createSession(
        query: ref.read(copilotQueryProvider),
        assistantType: assistant,
      );
  ref.invalidate(copilotSessionsFutureProvider);
  ref.read(copilotSelectedSessionIdProvider.notifier).state = session.id;
  ref.invalidate(copilotSessionDetailFutureProvider);
  return session;
}

void invalidateCopilotReads(WidgetRef ref) {
  ref.invalidate(copilotAssistantsFutureProvider);
  ref.invalidate(copilotSessionsFutureProvider);
  ref.invalidate(copilotSuggestionsFutureProvider);
  ref.invalidate(copilotSessionDetailFutureProvider);
}
