import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment_provider.dart';
import '../security/rbac_service.dart';
import 'ai_inference_pipeline.dart';
import 'ai_inference_telemetry.dart';
import 'ai_provider.dart';
import 'ai_response_cache.dart';
import 'providers/edge_ai_provider.dart';
import 'providers/fallback_ai_provider.dart';
import 'providers/stub_ai_provider.dart';

final aiResponseCacheProvider = Provider<AiResponseCache>((ref) {
  return AiResponseCache();
});

final aiInferenceTelemetryProvider = Provider<AiInferenceTelemetry>((ref) {
  return AiInferenceTelemetry();
});

final stubAiProviderProvider = Provider<AiProvider>((ref) => StubAiProvider());

final edgeAiProviderProvider = Provider<AiProvider>((ref) => EdgeAiProvider());

final liveAiInferenceEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(enableApiModeProvider)) return false;
  return const bool.fromEnvironment(
    'LIVE_AI_INFERENCE_ENABLED',
    defaultValue: true,
  );
});

final aiProviderProvider = Provider<AiProvider>((ref) {
  final stub = ref.watch(stubAiProviderProvider);
  if (!ref.watch(liveAiInferenceEnabledProvider)) {
    return stub;
  }
  return FallbackAiProvider(
    primary: ref.watch(edgeAiProviderProvider),
    fallback: stub,
  );
});

final aiInferencePipelineProvider = Provider<AiInferencePipeline>((ref) {
  return AiInferencePipeline(
    provider: ref.watch(aiProviderProvider),
    cache: ref.watch(aiResponseCacheProvider),
    telemetry: ref.watch(aiInferenceTelemetryProvider),
    rbac: ref.watch(rbacServiceProvider),
  );
});
