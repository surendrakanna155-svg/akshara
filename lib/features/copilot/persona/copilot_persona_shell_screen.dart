import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/ai_inference_models.dart';
import '../../../core/ai/ai_inference_pipeline.dart';
import '../../../core/ai/ai_inference_providers.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/akshara_dashboard_canvas.dart';
import '../../../shared/widgets/akshara_dashboard_watermark.dart';
import '../../../shared/widgets/akshara_glass_surface.dart';
import '../../../shared/widgets/akshara_scene_illustration.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../theme/mesh_background.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../copilot_context_provider.dart';
import '../copilot_navigation.dart';
import '../copilot_provider.dart';
import '../universal/universal_ai_assistant_service.dart';
import '../dock/copilot_dock_provider.dart';
import 'copilot_persona_experience.dart';

/// Role-specific AI shell — routing framework without prediction engines (INTEL-04).
class CopilotPersonaShellScreen extends ConsumerStatefulWidget {
  const CopilotPersonaShellScreen({super.key});

  @override
  ConsumerState<CopilotPersonaShellScreen> createState() =>
      _CopilotPersonaShellScreenState();
}

class _CopilotPersonaShellScreenState
    extends ConsumerState<CopilotPersonaShellScreen> {
  String? _lastReply;
  bool _isReplyLoading = false;
  bool _useStreamingReply = true;

  Future<void> _ask(String prompt) async {
    final screenContext = ref.read(copilotEffectiveContextProvider);
    final inferencePipeline = ref.read(aiInferencePipelineProvider);
    final universalAssistant = ref.read(universalAiAssistantServiceProvider);
    final profile = universalAssistant.resolveFromScreenContext(screenContext);

    setState(() {
      _isReplyLoading = true;
      _lastReply = null;
    });

    final request = AiInferenceRequest(
      prompt: prompt,
      taskType: aiTaskTypeName(AiInferenceTaskType.copilotChat),
      systemPrompt: universalAssistant.buildSystemPrompt(
        profile: profile,
        screenContext: screenContext,
      ),
      stream: _useStreamingReply,
      context: {
        ...?screenContext?.toJson(),
        'assistantType': profile.assistantType.name,
        'universalRole': profile.role.name,
      },
    );

    try {
      String reply;
      if (_useStreamingReply) {
        final buffer = StringBuffer();
        await for (final chunk in inferencePipeline.stream(request)) {
          buffer.write(chunk.delta);
        }
        reply = buffer.toString().trim();
      } else {
        final response = await inferencePipeline.complete(request);
        reply = response.content;
      }

      if (!mounted) return;
      setState(() {
        _lastReply = reply.isEmpty ? 'No reply generated.' : reply;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastReply = 'Unable to generate a response right now. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isReplyLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final persona = copilotDockPersona(ref);
    final experience = CopilotPersonaExperience.forPersona(persona);
    final screenContext = ref.watch(copilotEffectiveContextProvider);
    final canOpenFullCopilot = ref.watch(copilotCanUseProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(experience.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: AksharaDashboardCanvas(
        palette: AksharaMeshPalette.intelligence,
        watermark: AksharaWatermarkMotif.sparkles,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AksharaGlassSurface(
                borderRadius: AksharaRadius.glass,
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                showSheen: true,
                enableBlur: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AksharaSceneIllustration(
                      variant: AksharaSceneVariant.aiAssistant,
                      size: 72,
                    ),
                    const SizedBox(width: AksharaSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            experience.title,
                            style: context.aksharaText.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AksharaSpacing.s1),
                          Text(
                            experience.subtitle,
                            style: context.aksharaText.bodyMedium.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AksharaSpacing.s4),
              AksharaGlassSurface(
                key: QaTestKeys.copilotPersonaContextBanner,
                borderRadius: AksharaRadius.card,
                padding: const EdgeInsets.all(AksharaSpacing.s3),
                showSheen: false,
                enableBlur: false,
                tintColor: context.colors.primaryContainer,
                opacity: 0.35,
                child: Text(
                  screenContext?.displaySummary ?? persona.label,
                  style: context.aksharaText.bodySmall,
                ),
              ),
            const SizedBox(height: AksharaSpacing.s4),
            const AksharaSectionHeader(title: 'Focus areas'),
            Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                for (final area in experience.focusAreas)
                  AksharaGlassSurface(
                    borderRadius: AksharaRadius.chip,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AksharaSpacing.s3,
                      vertical: AksharaSpacing.s2,
                    ),
                    showSheen: false,
                    enableBlur: false,
                    shadowLevel: 0,
                    child: Text(area, style: context.aksharaText.labelMedium),
                  ),
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
            SwitchListTile.adaptive(
              key: QaTestKeys.universalAiAssistantStreamingToggle,
              contentPadding: EdgeInsets.zero,
              title: const Text('Streaming reply'),
              subtitle: const Text('Show loading, then full streamed response'),
              value: _useStreamingReply,
              onChanged: (value) {
                setState(() {
                  _useStreamingReply = value;
                });
              },
            ),
            const SizedBox(height: AksharaSpacing.s2),
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
            if (_isReplyLoading) ...[
              const SizedBox(height: AksharaSpacing.s4),
              const Material(
                key: QaTestKeys.universalAiAssistantLoadingIndicator,
                child: Padding(
                  padding: EdgeInsets.all(AksharaSpacing.s3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: AksharaSpacing.s2),
                      Text('Generating response...'),
                    ],
                  ),
                ),
              ),
            ],
            if (_lastReply != null) ...[
              const SizedBox(height: AksharaSpacing.s4),
              AksharaGlassSurface(
                key: QaTestKeys.copilotPersonaReplyPanel,
                borderRadius: AksharaRadius.glass,
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                showSheen: true,
                enableBlur: false,
                child: Text(_lastReply!),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
