import 'ai_inference_models.dart';

/// Abstraction over live and mock AI backends (FV-PLAT-10).
abstract class AiProvider {
  String get id;

  Future<AiInferenceResponse> complete(AiInferenceRequest request);

  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request);
}
