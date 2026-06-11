import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/repositories/api/finance/hybrid_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_phase5_repositories.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('per-module API feature flags', () {
    test('finance uses mock when only module flag is enabled', () {
      final container = ProviderContainer(
        overrides: [
          financeApiEnabledProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(financeRepositoryProvider),
        isA<MockFinanceRepository>(),
      );
    });

    test('finance uses API when global and module flags enabled', () {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: true),
          ),
          financeApiEnabledProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(financeRepositoryProvider),
        isA<HybridFinanceRepository>(),
      );
    });

    test('admissions flag does not affect finance repository', () {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: true),
          ),
          admissionsApiEnabledProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(financeRepositoryProvider),
        isA<MockFinanceRepository>(),
      );
    });

    test('phase5 uses mock when global API mode disabled', () {
      final container = ProviderContainer(
        overrides: [
          phase5ApiEnabledProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(parentExperienceRepositoryProvider),
        isA<MockParentExperienceRepository>(),
      );
    });
  });
}
