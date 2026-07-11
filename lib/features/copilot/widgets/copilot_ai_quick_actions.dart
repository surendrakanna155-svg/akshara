import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../adaptive_ai/adaptive_ai_models.dart';
import '../../adaptive_ai/adaptive_ai_providers.dart';
import '../copilot_navigation.dart';
import '../copilot_provider.dart';
import '../copilot_quick_action_routing.dart';
import '../dock/copilot_dock_provider.dart';

// W2 (P3-AI-2): the quick-action menu is now driven by the backend Quick Action
// Registry (doc 10 §7) instead of a hardcoded client enum, and selecting an
// action opens the GOVERNED copilot with a pre-filled prompt (domain gate +
// gateway + per-role quota) — the client-side stub reply is gone. Deterministic
// tiering happens server-side; the client just asks and the human confirms send.

/// Client-only sentinel to open the full copilot from the menu.
const _openFullCopilot = AdaptiveQuickAction(
  id: 'open_full_copilot',
  label: 'Open full copilot',
  tier: 't1',
  resolver: QuickActionResolver(kind: 'client', target: 'open_full'),
);

Future<void> showCopilotQuickActionsMenu(
  BuildContext context,
  WidgetRef ref,
  Offset anchor,
) async {
  final persona = adaptiveBackendPersona(copilotDockPersona(ref));
  // Backend catalog (RBAC-filtered server-side). Fail-soft: an error/empty list
  // still leaves the "Open full copilot" entry, so the menu is never broken.
  List<AdaptiveQuickAction> actions;
  try {
    actions = await ref.read(adaptiveQuickActionsProvider(persona).future);
  } catch (_) {
    actions = const [];
  }
  if (!context.mounted) return;

  final items = [...actions, _openFullCopilot];
  final action = await showModalBottomSheet<AdaptiveQuickAction>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AksharaSpacing.s4,
                vertical: AksharaSpacing.s2,
              ),
              child: Text('AI quick actions', style: context.aksharaText.titleMedium),
            ),
            for (final item in items)
              ListTile(
                key: QaTestKeys.copilotQuickActionTile(item.id),
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

IconData _iconForAction(AdaptiveQuickAction action) {
  if (action.id == _openFullCopilot.id) return Icons.open_in_new;
  if (action.resolver.isCopilot) return Icons.auto_awesome;
  if (action.id.contains('risk')) return Icons.warning_amber_outlined;
  if (action.id.contains('fee') || action.id.contains('finance')) {
    return Icons.payments_outlined;
  }
  if (action.id.contains('attendance')) return Icons.fact_check_outlined;
  if (action.id.contains('priorit') || action.id.contains('recommend')) {
    return Icons.lightbulb_outline;
  }
  return Icons.analytics_outlined;
}

Future<void> executeCopilotQuickAction(
  BuildContext context,
  WidgetRef ref,
  AdaptiveQuickAction action,
) async {
  // Open the full copilot / persona assistant (either the sentinel, or the
  // destination for every action once a prompt is staged below).
  void openAssistant() {
    if (ref.read(copilotCanUseProvider)) {
      openCopilotWithCurrentContext(context, ref);
    } else {
      openAiPersonaAssistant(context, ref);
    }
  }

  if (action.id == _openFullCopilot.id) {
    openAssistant();
    return;
  }

  // P2-1 (audit): a `kind: 'endpoint'` action is already deterministic (tier
  // t1, 0 tokens) — navigate straight to the client screen instead of staging
  // a copilot prompt for it. An unmapped target falls back to the copilot path
  // below, so a quick action never dead-ends.
  if (action.resolver.kind == 'endpoint') {
    final route = quickActionEndpointRoute(action);
    if (route != null) {
      context.go(route);
      return;
    }
  }

  // Stage a pre-filled prompt (the copilot resolver's prompt for generative
  // actions; the label as a question for deterministic ones — the governed
  // backend then serves it deterministic-first). The human still taps send, so
  // AI never auto-executes, and the send passes the domain gate + gateway + quota.
  final prompt = action.resolver.isCopilot && (action.resolver.prompt?.isNotEmpty ?? false)
      ? action.resolver.prompt!
      : action.label;
  ref.read(copilotMessageDraftProvider.notifier).state = prompt;
  openAssistant();
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
