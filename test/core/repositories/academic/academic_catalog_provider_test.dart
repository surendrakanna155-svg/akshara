import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/repositories/academic/academic_catalog_provider.dart';
import 'package:akshara_erp/core/repositories/academic/hybrid_academic_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_academic_repository.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('AcademicCatalogProvider', () {
    test('mock mode exposes year/class/section/teacher options', () async {
      final container = ProviderContainer(
        overrides: providerTestOverrides([
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: false),
          ),
          academicRepositoryProvider.overrideWith(
            (ref) => MockAcademicRepository(),
          ),
        ]),
      );
      addTearDown(container.dispose);

      await container.read(academicCatalogFutureProvider.future);

      expect(container.read(yearOptionsProvider), contains('2026-27'));
      expect(container.read(classOptionsProvider), contains('10'));
      expect(container.read(sectionOptionsProvider), contains('A'));
      expect(
        container.read(teacherOptionsProvider),
        contains('Staging Teacher A'),
      );
    });

    test('section options filter by selected class label', () async {
      final container = ProviderContainer(
        overrides: providerTestOverrides([
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: false),
          ),
          academicRepositoryProvider.overrideWith(
            (ref) => MockAcademicRepository(),
          ),
        ]),
      );
      addTearDown(container.dispose);

      await container.read(academicCatalogFutureProvider.future);

      final sectionsForFive =
          container.read(sectionOptionsForClassProvider('5'));
      expect(sectionsForFive, contains('A'));
      expect(sectionsForFive, isNot(contains('Z')));
    });

    test('API mode uses academic repository provider wiring', () {
      final container = ProviderContainer(
        overrides: providerTestOverrides([
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: true),
          ),
          academicApiEnabledProvider.overrideWith((ref) => true),
        ]),
      );
      addTearDown(container.dispose);

      expect(
        container.read(academicRepositoryProvider),
        isA<HybridAcademicRepository>(),
      );
    });
  });
}
