import 'ai_inference_models.dart';

/// In-memory LRU response cache for AI inference (FV-PLAT-10).
class AiResponseCache {
  AiResponseCache({this.maxEntries = 128});

  final int maxEntries;
  final _entries = <String, AiInferenceResponse>{};

  AiInferenceResponse? get(String key) => _entries[key];

  void put(String key, AiInferenceResponse response) {
    if (_entries.containsKey(key)) {
      _entries.remove(key);
    }
    _entries[key] = response;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}

String buildAiCacheKey(AiInferenceRequest request) {
  if (request.cacheKey != null && request.cacheKey!.isNotEmpty) {
    return '${request.taskType}:${request.cacheKey}';
  }
  return '${request.taskType}:${request.prompt.hashCode}:${request.systemPrompt?.hashCode ?? 0}';
}
