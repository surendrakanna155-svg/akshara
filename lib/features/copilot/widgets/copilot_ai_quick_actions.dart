import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../copilot_navigation.dart';
import '../copilot_quick_action.dart';
import '../copilot_stub_responses.dart';
import 'package:go_router/go_router.dart';

import '../copilot_context_provider.dart';
import '../copilot_provider.dart';
import '../dock/copilot_dock_provider.dart';

Future<void> showCopilotQuickActionsMenu(
  BuildContext context,
  WidgetRef ref,
  Offset anchor,
) async {
  final action = await showModalBottomSheet<CopilotQuickAction>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'AI quick actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final item in CopilotQuickAction.values)
              ListTile(
                key: QaTestKeys.copilotQuickActionTile(item.name),
                leading: Icon(_iconForAction(item)),
                title: Text(item.label),
                onTap: () => Navigator.of(context).pop(item),
              ),
          ],
        ),
      );
    },
  );

  if (action == null || !context.mounted) return;
  await executeCopilotQuickAction(context, ref, action);
}

IconData _iconForAction(CopilotQuickAction action) => switch (action) {
      CopilotQuickAction.explainScreen => Icons.help_outline,
      CopilotQuickAction.summarizeKpis => Icons.analytics_outlined,
      CopilotQuickAction.showAlerts => Icons.notifications_active_outlined,
      CopilotQuickAction.showRisks => Icons.warning_amber_outlined,
      CopilotQuickAction.suggestedActions => Icons.lightbulb_outline,
      CopilotQuickAction.openFullCopilot => Icons.open_in_new,
    };

Future<void> executeCopilotQuickAction(
  BuildContext context,
  WidgetRef ref,
  CopilotQuickAction action,
) async {
  if (action == CopilotQuickAction.openFullCopilot) {
    if (ref.read(copilotCanUseProvider)) {
      openCopilotWithCurrentContext(context, ref);
    } else {
      openAiPersonaAssistant(context, ref);
    }
    return;
  }

  final persona = copilotDockPersona(ref);
  final originRoute = GoRouterState.of(context).uri.path;
  final screenContext = ref.read(copilotEffectiveContextProvider) ??
      buildCopilotScreenContext(ref, originRoute: originRoute);
  final prompt = action.promptForPersona(persona);
  final reply = buildContextAwareStubReply(
    userMessage: prompt,
    screenContext: screenContext,
  );

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: QaTestKeys.copilotQuickActionReplyDialog,
      title: Text(action.label),
      content: SingleChildScrollView(child: Text(reply)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(copilotMessageDraftProvider.notifier).state = prompt;
            if (ref.read(copilotCanUseProvider)) {
              openCopilotWithCurrentContext(context, ref);
            } else {
              openAiPersonaAssistant(context, ref);
            }
          },
          child: const Text('Continue in assistant'),
        ),
      ],
    ),
  );
}

void handleCopilotAiEntryTap(BuildContext context, WidgetRef ref) {
  openAiAssistantFromDock(context, ref);
}

void handleCopilotAiEntryLongPress(
  BuildContext context,
  WidgetRef ref,
  Offset globalPosition,
) {
  showCopilotQuickActionsMenu(context, ref, globalPosition);
}
