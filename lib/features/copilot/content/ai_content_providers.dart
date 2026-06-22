import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_inference_providers.dart';
import 'ai_content_models.dart';
import 'ai_content_service.dart';

final aiContentServiceProvider = Provider<AiContentService>((ref) {
  return AiContentService(pipeline: ref.watch(aiInferencePipelineProvider));
});

class AiContentGenerationNotifier extends AsyncNotifier<AiGeneratedContent?> {
  @override
  FutureOr<AiGeneratedContent?> build() => null;

  Future<AiGeneratedContent?> execute(AiContentRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(aiContentServiceProvider).generate(request),
    );
    return state.valueOrNull;
  }
}

final aiContentGenerationProvider =
    AsyncNotifierProvider<AiContentGenerationNotifier, AiGeneratedContent?>(
  AiContentGenerationNotifier.new,
);
