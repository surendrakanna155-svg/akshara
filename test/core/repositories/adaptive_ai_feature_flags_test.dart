import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/repositories/api/adaptive_ai/hybrid_adaptive_ai_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_adaptive_ai_repository.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
