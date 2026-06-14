import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../copilot_context_provider.dart';
import '../copilot_navigation.dart';
import '../copilot_provider.dart';
import '../copilot_stub_responses.dart';
import '../dock/copilot_dock_provider.dart';
import 'copilot_persona_experience.dart';

/// Role-specific AI shell — routing framework without prediction engines (INTEL-04).
class CopilotPersonaShellScreen extends ConsumerStatefulWidget {
  const CopilotPersonaShellScreen({super.key});

  @override
  ConsumerState<CopilotPersonaShellScreen> createState() =>
      _CopilotPersonaShellScreenState();
}

class _CopilotPersonaShellScreenState extends ConsumerState<CopilotPersonaShellScreen> {
  String? _lastReply;

  Future<void> _ask(String prompt) async {
    final screenContext = ref.read(copilotEffectiveContextProvider);
    setState(() {
      _lastReply = buildContextAwareStubReply(
        userMessage: prompt,
        screenContext: screenContext,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final persona = copilotDockPersona(ref);
    final experience = CopilotPersonaExperience.forPersona(persona);
    final screenContext = ref.watch(copilotEffectiveContextProvider);
    final canOpenFullCopilot = ref.watch(copilotCanUseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(experience.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              key: QaTestKeys.copilotPersonaContextBanner,
              color: context.colors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AksharaSpacing.s2),
              child: Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s3),
                child: Text(
                  screenContext?.displaySummary ?? persona.label,
                  style: context.aksharaText.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: AksharaSpacing.s4),
            Text(experience.subtitle, style: context.aksharaText.bodyMedium),
            const SizedBox(height: AksharaSpacing.s4),
            const AksharaSectionHeader(title: 'Focus areas'),
            Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                for (final area in experience.focusAreas)
                  Chip(label: Text(area)),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s4),
            if (canOpenFullCopilot)
              FilledButton.icon(
                key: QaTestKeys.copilotPersonaOpenFullButton,
                onPressed: () => openCopilotWithCurrentContext(context, ref),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open full ERP Copilot'),
              ),
            const SizedBox(height: AksharaSpacing.s4),
            const AksharaSectionHeader(title: 'Suggested prompts'),
            Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                for (final prompt in experience.starterPrompts)
                  ActionChip(
                    key: QaTestKeys.copilotPersonaPromptChip(prompt),
                    label: Text(prompt),
                    onPressed: () => _ask(prompt),
                  ),
              ],
            ),
            if (_lastReply != null) ...[
              const SizedBox(height: AksharaSpacing.s4),
              Material(
                key: QaTestKeys.copilotPersonaReplyPanel,
                color: context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AksharaSpacing.s3),
                child: Padding(
                  padding: const EdgeInsets.all(AksharaSpacing.s3),
                  child: Text(_lastReply!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
