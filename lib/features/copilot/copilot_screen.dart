import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/akshara_empty_state.dart';
import '../../shared/widgets/akshara_error_state.dart';
import '../../shared/widgets/akshara_loading_state.dart';
import '../../shared/widgets/akshara_section_header.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../admin/admin_content_scaffold.dart';
import '../admin/admin_layout.dart';
import '../admin/admin_shell.dart';
import '../admin/models/admin_nav_models.dart';
import 'copilot_context_provider.dart';
import 'copilot_models.dart';
import 'copilot_provider.dart';

/// AI Copilot chat workspace (v7.4).
class CopilotScreen extends ConsumerStatefulWidget {
  const CopilotScreen({super.key});

  @override
  ConsumerState<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends ConsumerState<CopilotScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startConversation() async {
    await createCopilotSession(ref);
    if (mounted) setState(() {});
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text;
    if (content.trim().isEmpty) return;
    _messageController.clear();
    await ref.read(copilotSendMessageProvider.notifier).send(content);
    if (_scrollController.hasClients) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(copilotCanUseProvider)) {
      return const Scaffold(
        body: AksharaErrorState(
          message: 'AI Copilot is not enabled for your role.',
          icon: Icons.lock_outline,
        ),
      );
    }

    final assistantsAsync = ref.watch(copilotAssistantsFutureProvider);
    final sessionsAsync = ref.watch(copilotSessionsFutureProvider);
    final suggestionsAsync = ref.watch(copilotSuggestionsFutureProvider);
    final detailAsync = ref.watch(copilotSessionDetailFutureProvider);
    final selectedAssistant = ref.watch(copilotSelectedAssistantProvider);
    final selectedSessionId = ref.watch(copilotSelectedSessionIdProvider);
    final canSend = ref.watch(copilotCanSendProvider);
    final sendState = ref.watch(copilotSendMessageProvider);
    final screenContext = ref.watch(copilotEffectiveContextProvider);
    final isMobile = AdminLayout.isMobile(context);

    return AdminContentScaffold(
      breadcrumbs: const [
        AdminBreadcrumb(label: 'Admin Hub', route: '/admin'),
        AdminBreadcrumb(label: 'AI Copilot'),
      ],
      onMenuTap: adminShellMenuTap(context),
      body: assistantsAsync.when(
        loading: () => const AksharaLoadingState(semanticLabel: 'Loading AI Copilot'),
        error: (_, __) => AksharaErrorState(
          message: 'Unable to load AI Copilot.',
          onRetry: () => invalidateCopilotReads(ref),
        ),
        data: (assistants) {
          if (assistants.isEmpty) {
            return const AksharaEmptyState(
              message: 'No assistants available for your role.',
              icon: Icons.smart_toy_outlined,
            );
          }

          return SizedBox(
            height: isMobile ? 640 : 720,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: isMobile ? 220 : 280,
                  child: _Sidebar(
                    assistants: assistants,
                    selectedAssistant: selectedAssistant,
                    sessionsAsync: sessionsAsync,
                    selectedSessionId: selectedSessionId,
                    onAssistantSelected: (type) {
                      ref.read(copilotSelectedAssistantProvider.notifier).state = type;
                      ref.invalidate(copilotSuggestionsFutureProvider);
                    },
                    onSessionSelected: (id) {
                      ref.read(copilotSelectedSessionIdProvider.notifier).state = id;
                      ref.invalidate(copilotSessionDetailFutureProvider);
                    },
                    onNewConversation: _startConversation,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (screenContext != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AksharaSpacing.s4,
                            AksharaSpacing.s4,
                            AksharaSpacing.s4,
                            AksharaSpacing.s0,
                          ),
                          child: Material(
                            key: QaTestKeys.copilotContextBanner,
                            color: context.colors.primaryContainer.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(AksharaSpacing.s2),
                            child: Padding(
                              padding: const EdgeInsets.all(AksharaSpacing.s3),
                              child: Text(
                                'Context: ${screenContext.displaySummary}',
                                style: context.aksharaText.bodySmall,
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(AksharaSpacing.s4),
                        child: suggestionsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (suggestions) => Wrap(
                            spacing: AksharaSpacing.s2,
                            runSpacing: AksharaSpacing.s2,
                            children: [
                              for (final prompt in suggestions.prompts)
                                ActionChip(
                                  label: Text(prompt),
                                  onPressed: canSend && selectedSessionId != null
                                      ? () {
                                          _messageController.text = prompt;
                                          _sendMessage();
                                        }
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: detailAsync.when(
                          loading: () => const AksharaLoadingState(
                            semanticLabel: 'Loading conversation',
                          ),
                          error: (_, __) => const AksharaEmptyState(
                            message: 'Select or start a conversation.',
                            icon: Icons.chat_bubble_outline,
                          ),
                          data: (detail) {
                            if (detail == null) {
                              return AksharaEmptyState(
                                message: 'Start a new conversation with ${selectedAssistant.label}.',
                                icon: Icons.chat_outlined,
                                actionLabel: 'New conversation',
                                onAction: _startConversation,
                              );
                            }
                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(AksharaSpacing.s4),
                              itemCount: detail.messages.length,
                              itemBuilder: (context, index) {
                                final message = detail.messages[index];
                                return _MessageBubble(message: message);
                              },
                            );
                          },
                        ),
                      ),
                      if (sendState.isLoading)
                        const LinearProgressIndicator(minHeight: 2),
                      Padding(
                        padding: const EdgeInsets.all(AksharaSpacing.s4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: QaTestKeys.copilotMessageField,
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 4,
                                enabled: canSend && selectedSessionId != null,
                                decoration: const InputDecoration(
                                  hintText: 'Ask a read-only operational question…',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: AksharaSpacing.s3),
                            FilledButton.icon(
                              key: QaTestKeys.copilotSendButton,
                              onPressed: canSend &&
                                      selectedSessionId != null &&
                                      !sendState.isLoading
                                  ? _sendMessage
                                  : null,
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Send'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.assistants,
    required this.selectedAssistant,
    required this.sessionsAsync,
    required this.selectedSessionId,
    required this.onAssistantSelected,
    required this.onSessionSelected,
    required this.onNewConversation,
  });

  final List<CopilotAssistant> assistants;
  final CopilotAssistantType selectedAssistant;
  final AsyncValue<List<CopilotSession>> sessionsAsync;
  final String? selectedSessionId;
  final ValueChanged<CopilotAssistantType> onAssistantSelected;
  final ValueChanged<String> onSessionSelected;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AksharaSectionHeader(title: 'Assistants'),
          const SizedBox(height: AksharaSpacing.s2),
          DropdownButtonFormField<CopilotAssistantType>(
            isExpanded: true,
            initialValue: selectedAssistant,
            items: [
              for (final assistant in assistants)
                DropdownMenuItem(
                  value: assistant.type,
                  child: Text(assistant.label),
                ),
            ],
            onChanged: (value) {
              if (value != null) onAssistantSelected(value);
            },
          ),
          const SizedBox(height: AksharaSpacing.s4),
          FilledButton.icon(
            key: QaTestKeys.copilotNewConversationButton,
            onPressed: onNewConversation,
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('New conversation'),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'History'),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const AksharaLoadingState(semanticLabel: 'Loading history'),
              error: (_, __) => const AksharaEmptyState(
                message: 'Unable to load history.',
                icon: Icons.history,
              ),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return const AksharaEmptyState(
                    message: 'No conversations yet.',
                    icon: Icons.history,
                  );
                }
                return ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return ListTile(
                      selected: session.id == selectedSessionId,
                      title: Text(session.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(session.assistantType.label),
                      onTap: () => onSessionSelected(session.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final CopilotMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isUser
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
        padding: const EdgeInsets.all(AksharaSpacing.s3),
        constraints: const BoxConstraints(maxWidth: 640),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        ),
        child: Text(message.content),
      ),
    );
  }
}
