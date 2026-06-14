import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../theme/breakpoints.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../copilot_context_provider.dart';
import '../copilot_navigation.dart';
import '../copilot_role_intelligence.dart';
import '../persona/copilot_persona_experience.dart';
import 'copilot_dock_provider.dart';

/// Global floating AI dock — one tap to open role-aware assistant (INTEL-04).
class CopilotFloatingDock extends ConsumerWidget {
  const CopilotFloatingDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = GoRouterState.of(context).uri.path;
    if (copilotDockHiddenForRoute(route)) return const SizedBox.shrink();
    if (!ref.watch(copilotDockVisibleProvider)) return const SizedBox.shrink();

    final expanded = ref.watch(copilotDockExpandedProvider);
    final persona = copilotDockPersona(ref);
    final contextSnapshot = ref.watch(copilotEffectiveContextProvider);
    final usesFullCopilot = ref.watch(copilotDockUsesFullCopilotProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = AksharaBreakpoints.fromWidth(width) == LayoutBreakpoint.mobile;
    final bottomInset = isMobile ? 88.0 : AksharaSpacing.s6;

    return Positioned(
      right: AksharaSpacing.s4,
      bottom: bottomInset,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(AksharaSpacing.s4),
        color: context.colors.surfaceContainerHighest,
        clipBehavior: Clip.antiAlias,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AksharaSpacing.s4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: expanded ? (isMobile ? 280 : 360) : 56,
            constraints: BoxConstraints(maxWidth: isMobile ? 280 : 360),
            child: expanded
                ? _ExpandedPanel(
                    persona: persona,
                    contextSummary: contextSnapshot?.displaySummary ??
                        '${persona.label} · ${copilotModuleForRoute(route)}',
                    usesFullCopilot: usesFullCopilot,
                    onCollapse: () =>
                        ref.read(copilotDockExpandedProvider.notifier).state = false,
                    onOpen: () => openAiAssistantFromDock(context, ref),
                  )
                : _CollapsedFab(
                    persona: persona,
                    expanded: expanded,
                    onTap: () {
                      ref.read(copilotDockExpandedProvider.notifier).state = true;
                    },
                    onLongPress: () => openAiAssistantFromDock(context, ref),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedFab extends StatelessWidget {
  const _CollapsedFab({
    required this.persona,
    required this.expanded,
    required this.onTap,
    required this.onLongPress,
  });

  final CopilotPersonaRole persona;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: copilotDockSemanticLabel(persona, expanded: expanded),
      child: Material(
        key: QaTestKeys.copilotFloatingDockFab,
        color: context.colors.primaryContainer,
        borderRadius: BorderRadius.circular(AksharaSpacing.s4),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AksharaSpacing.s4),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              copilotDockIconForPersona(persona),
              color: context.colors.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedPanel extends StatelessWidget {
  const _ExpandedPanel({
    required this.persona,
    required this.contextSummary,
    required this.usesFullCopilot,
    required this.onCollapse,
    required this.onOpen,
  });

  final CopilotPersonaRole persona;
  final String contextSummary;
  final bool usesFullCopilot;
  final VoidCallback onCollapse;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final experience = CopilotPersonaExperience.forPersona(persona);

    return Padding(
      key: QaTestKeys.copilotFloatingDockPanel,
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(copilotDockIconForPersona(persona), color: context.colors.primary),
              const SizedBox(width: AksharaSpacing.s2),
              Expanded(
                child: Text(
                  experience.title,
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: QaTestKeys.copilotFloatingDockCollapseButton,
                icon: const Icon(Icons.close),
                tooltip: 'Collapse',
                onPressed: onCollapse,
              ),
            ],
          ),
          Text(experience.subtitle, style: text.bodySmall),
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            contextSummary,
            key: QaTestKeys.copilotFloatingDockContextSummary,
            style: text.labelSmall.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          FilledButton.icon(
            key: QaTestKeys.copilotFloatingDockOpenButton,
            onPressed: onOpen,
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: Text(usesFullCopilot ? 'Open Copilot' : 'Open Assistant'),
          ),
        ],
      ),
    );
  }
}
