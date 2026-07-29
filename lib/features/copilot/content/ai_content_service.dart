import '../../../core/ai/ai_inference_models.dart';
import '../../../core/ai/ai_inference_pipeline.dart';
import 'ai_content_models.dart';

class AiContentService {
  const AiContentService({required AiInferencePipeline pipeline})
      : _pipeline = pipeline;

  final AiInferencePipeline _pipeline;

  /// Generates content, or **throws**.
  ///
  /// E2E-021: this used to catch every exception and return an
  /// `AiGeneratedContent` whose body was the user's own prompt reformatted and
  /// stamped `generatedAt: now()`. The UI could not tell that from a real
  /// generation, so a failed call could be broadcast to a school as composed
  /// content. A failure is now a failure — the composer renders it honestly and
  /// the send action stays blocked.
  Future<AiGeneratedContent> generate(AiContentRequest request) async {
    final response = await _pipeline.complete(
      AiInferenceRequest(
        prompt: _buildPrompt(request),
        taskType: aiTaskTypeName(AiInferenceTaskType.contentGeneration),
        systemPrompt:
            'You are the NIKSHA OS assistant. Generate school-safe formal content.',
        context: {
          'module': 'ai_content',
          'type': request.type.name,
          'audience': request.audience,
          'tone': request.tone,
        },
      ),
    );
    return AiGeneratedContent(
      type: request.type,
      content: response.content.trim(),
      generatedAt: DateTime.now(),
    );
  }

  String _buildPrompt(AiContentRequest request) {
    final constraints = request.constraints.trim().isEmpty
        ? 'Keep it concise and actionable.'
        : request.constraints.trim();
    return 'Create a ${request.type.label} for ${request.audience}. '
        'Tone: ${request.tone}. '
        'Prompt: ${request.prompt}. '
        'Constraints: $constraints.';
  }
}
