import '../../core/ai/ai_inference_models.dart';
import '../../core/ai/ai_inference_pipeline.dart';
import 'ai_content_models.dart';

class AiContentService {
  const AiContentService({required AiInferencePipeline pipeline})
      : _pipeline = pipeline;

  final AiInferencePipeline _pipeline;

  Future<AiGeneratedContent> generate(AiContentRequest request) async {
    try {
      final response = await _pipeline.complete(
        AiInferenceRequest(
          prompt: _buildPrompt(request),
          taskType: aiTaskTypeName(AiInferenceTaskType.contentGeneration),
          systemPrompt:
              'You are Akshara ERP assistant. Generate school-safe formal content.',
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
    } catch (_) {
      return AiGeneratedContent(
        type: request.type,
        content:
            'Notice: ${request.prompt.trim()}\n\nAudience: ${request.audience}. Tone: ${request.tone}.',
        generatedAt: DateTime.now(),
      );
    }
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
