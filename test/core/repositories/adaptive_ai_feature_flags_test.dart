import 'dart:convert';
import 'dart:io';

import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/repositories/api/adaptive_ai/hybrid_adaptive_ai_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_adaptive_ai_repository.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // P0-1 regression guard: the switch mechanism can be correct yet the feature
  // still ships DARK if the canonical live release config forgets to turn it on
  // (exactly what the certification audit found). Assert the shipped config
  // enables it so this can never silently regress again.
  group('live release config actually enables Adaptive AI', () {
    late Map<String, dynamic> liveConfig;

    setUpAll(() {
      final file = File('config/live_release.json');
      expect(file.existsSync(), isTrue,
          reason: 'config/live_release.json must exist (release build source)');
      liveConfig = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test('ENABLE_API_MODE is true (global master switch)', () {
      expect(liveConfig['ENABLE_API_MODE'], isTrue);
    });

    test('ADAPTIVE_AI_API_ENABLED is present and true (W2 feed/search/actions)', () {
      expect(liveConfig.containsKey('ADAPTIVE_AI_API_ENABLED'), isTrue,
          reason: 'W2 Adaptive AI falls back to MockAdaptiveAiRepository in '
              'production without this flag');
      expect(liveConfig['ADAPTIVE_AI_API_ENABLED'], isTrue);
    });
  });

  group('Adaptive AI repository feature flag', () {
    test('uses mock when only the module flag is enabled (no global API mode)', () {
      final container = ProviderContainer(
        overrides: [
          adaptiveAiApiEnabledProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(adaptiveAiRepositoryProvider),
        isA<MockAdaptiveAiRepository>(),
      );
    });

    test('uses Hybrid (API) when global + module flags are enabled', () {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: true),
          ),
          adaptiveAiApiEnabledProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(adaptiveAiRepositoryProvider),
        isA<HybridAdaptiveAiRepository>(),
      );
    });

    test('defaults to mock with no overrides', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(adaptiveAiRepositoryProvider),
        isA<MockAdaptiveAiRepository>(),
      );
    });
  });
}
