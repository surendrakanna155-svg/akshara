import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import 'ai_content_models.dart';
import 'ai_content_providers.dart';
import '../../../theme/spacing.dart';

class AiContentScreen extends ConsumerStatefulWidget {
  const AiContentScreen({super.key});

  @override
  ConsumerState<AiContentScreen> createState() => _AiContentScreenState();
}

class _AiContentScreenState extends ConsumerState<AiContentScreen> {
  final _promptController = TextEditingController();
  final _audienceController = TextEditingController(text: 'Parents of Grade 8');
  final _toneController = TextEditingController(text: 'Professional and warm');
  final _constraintsController = TextEditingController();
  AiContentType _selectedType = AiContentType.notice;

  @override
  void dispose() {
    _promptController.dispose();
    _audienceController.dispose();
    _toneController.dispose();
    _constraintsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(aiContentGenerationProvider);
    final generated = generationState.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Content Generation')),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          DropdownButtonFormField<AiContentType>(
            key: QaTestKeys.aiContentTypePicker,
            initialValue: _selectedType,
            decoration: const InputDecoration(labelText: 'Content type'),
            items: [
              for (final type in AiContentType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedType = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: QaTestKeys.aiContentPromptField,
            controller: _promptController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Prompt',
              hintText: 'What should this content communicate?',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: QaTestKeys.aiContentAudienceField,
            controller: _audienceController,
            decoration: const InputDecoration(labelText: 'Audience'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: QaTestKeys.aiContentToneField,
            controller: _toneController,
            decoration: const InputDecoration(labelText: 'Tone'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: QaTestKeys.aiContentConstraintsField,
            controller: _constraintsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Constraints (optional)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: QaTestKeys.aiContentGenerateButton,
            onPressed: generationState.isLoading ? null : _generate,
            icon: generationState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: const Text('Generate'),
          ),
          const SizedBox(height: 16),
          if (generationState.hasError)
            const AksharaErrorState(
              message: 'Unable to generate content right now.',
            ),
          if (generated != null) ...[
            Card(
              key: QaTestKeys.aiContentGeneratedCard,
              child: Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s3),
                child: SelectableText(generated.content),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: QaTestKeys.aiContentCopyButton,
                  onPressed: () => _copy(context, generated.content),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy'),
                ),
                OutlinedButton.icon(
                  key: QaTestKeys.aiContentShareButton,
                  onPressed: () => _share(context, generated.content),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    final result = await ref.read(aiContentGenerationProvider.notifier).execute(
          AiContentRequest(
            type: _selectedType,
            prompt: prompt,
            audience: _audienceController.text.trim(),
            tone: _toneController.text.trim(),
            constraints: _constraintsController.text.trim(),
          ),
        );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.aiContentGeneratedSnackbar,
        content: Text('AI content generated.'),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.aiContentCopiedSnackbar,
        content: Text('Content copied to clipboard.'),
      ),
    );
  }

  Future<void> _share(BuildContext context, String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.aiContentSharedSnackbar,
        content: Text('Content copied for sharing.'),
      ),
    );
  }
}
